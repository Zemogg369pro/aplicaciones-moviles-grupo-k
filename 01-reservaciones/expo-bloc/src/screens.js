import React, { useContext, useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator, Alert, FlatList, Pressable, RefreshControl, ScrollView, StyleSheet, Switch, Text, TextInput, View,
} from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { useBlocState } from './bloc/Bloc';
import {
  authBloc, BookingBloc, EstablishmentsBloc, MyEstablishmentBloc, ReservationsBloc, ServicesBloc,
} from './bloc/blocs';
import { NotificationsContext } from './context';

// ---------- componentes reutilizables ----------
const Btn = ({ title, onPress, color = '#4f46e5', disabled }) => (
  <Pressable onPress={onPress} disabled={disabled}
    style={[st.btn, { backgroundColor: disabled ? '#a5a5a5' : color }]}>
    <Text style={st.btnText}>{title}</Text>
  </Pressable>
);
const Field = (p) => <TextInput style={st.input} placeholderTextColor="#888" {...p} />;
const ErrorText = ({ error }) => (error ? <Text style={st.error}>{error}</Text> : null);
const Loading = () => <ActivityIndicator style={{ margin: 16 }} size="large" />;
const Empty = ({ text }) => <Text style={st.empty}>{text}</Text>;
const fmtDate = (iso) => new Date(iso).toLocaleString('es-MX', { dateStyle: 'medium', timeStyle: 'short' });
const fmtTime = (iso) => new Date(iso).toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit' });
const STATUS_COLOR = { pendiente: '#d97706', confirmada: '#2563eb', cancelada: '#dc2626', finalizada: '#16a34a' };
const Badge = ({ status }) => (
  <Text style={[st.badge, { backgroundColor: STATUS_COLOR[status] }]}>{status.toUpperCase()}</Text>
);
const useBloc = (factory, deps = []) => useMemo(factory, deps);

// Banner de notificación cuando llega un cambio en una cita
export function NotificationBanner({ bloc }) {
  const { latest } = useBlocState(bloc);
  const [visible, setVisible] = useState(null);
  useEffect(() => {
    if (!latest) return;
    setVisible(latest);
    const t = setTimeout(() => setVisible(null), 4000);
    return () => clearTimeout(t);
  }, [latest?.id]);
  if (!visible) return null;
  return (
    <View style={st.banner}>
      <Text style={st.bannerTitle}>🔔 {visible.title}</Text>
      <Text style={{ color: '#fff' }}>{visible.body}</Text>
    </View>
  );
}

// ================= AUTENTICACIÓN =================
export function LoginScreen({ navigation }) {
  const auth = useBlocState(authBloc);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const submit = () => {
    if (!email || !password) return Alert.alert('Validación', 'Ingresa correo y contraseña');
    authBloc.add({ type: 'Login', payload: { email, password } });
  };
  return (
    <ScrollView contentContainerStyle={st.container}>
      <Text style={st.title}>Reservaciones</Text>
      <Field placeholder="Correo" autoCapitalize="none" keyboardType="email-address" value={email} onChangeText={setEmail} />
      <Field placeholder="Contraseña" secureTextEntry value={password} onChangeText={setPassword} />
      <ErrorText error={auth.error} />
      {auth.status === 'loading' ? <Loading /> : <Btn title="Entrar" onPress={submit} />}
      <Pressable onPress={() => navigation.navigate('Registro')}><Text style={st.link}>¿No tienes cuenta? Regístrate</Text></Pressable>
    </ScrollView>
  );
}

export function RegisterScreen() {
  const auth = useBlocState(authBloc);
  const [form, setForm] = useState({ name: '', email: '', password: '', role: 'cliente' });
  const set = (k) => (v) => setForm((f) => ({ ...f, [k]: v }));
  const submit = () => {
    if (!form.name || !form.email || form.password.length < 6)
      return Alert.alert('Validación', 'Completa todos los campos (contraseña mínimo 6 caracteres)');
    authBloc.add({ type: 'Register', payload: form });
  };
  return (
    <ScrollView contentContainerStyle={st.container}>
      <Field placeholder="Nombre" value={form.name} onChangeText={set('name')} />
      <Field placeholder="Correo" autoCapitalize="none" keyboardType="email-address" value={form.email} onChangeText={set('email')} />
      <Field placeholder="Contraseña" secureTextEntry value={form.password} onChangeText={set('password')} />
      <View style={st.row}>
        <Text>Soy administrador de un establecimiento</Text>
        <Switch value={form.role === 'admin'} onValueChange={(v) => set('role')(v ? 'admin' : 'cliente')} />
      </View>
      <ErrorText error={auth.error} />
      {auth.status === 'loading' ? <Loading /> : <Btn title="Crear cuenta" onPress={submit} />}
    </ScrollView>
  );
}

export function ProfileScreen() {
  const { user } = useBlocState(authBloc);
  return (
    <View style={st.container}>
      <Text style={st.title}>{user.name}</Text>
      <Text>{user.email}</Text>
      <Text style={{ marginBottom: 16 }}>Rol: {user.role}</Text>
      <Btn title="Cerrar sesión" color="#dc2626" onPress={() => authBloc.add({ type: 'Logout' })} />
    </View>
  );
}

// ================= CLIENTE =================
export function ExploreScreen({ navigation }) {
  const bloc = useBloc(() => new EstablishmentsBloc());
  const state = useBlocState(bloc);
  const [q, setQ] = useState('');
  useEffect(() => { bloc.add({ type: 'Search', query: '' }); }, []);
  return (
    <View style={{ flex: 1, padding: 12 }}>
      <Field placeholder="Buscar establecimiento o servicio..." value={q} onChangeText={setQ}
        onSubmitEditing={() => bloc.add({ type: 'Search', query: q })} returnKeyType="search" />
      <ErrorText error={state.error} />
      <FlatList
        data={state.items}
        keyExtractor={(i) => i.id}
        refreshControl={<RefreshControl refreshing={state.status === 'loading'} onRefresh={() => bloc.add({ type: 'Search', query: q })} />}
        ListEmptyComponent={state.status === 'success' ? <Empty text="No se encontraron establecimientos" /> : null}
        renderItem={({ item }) => (
          <Pressable style={st.card} onPress={() => navigation.navigate('Establecimiento', { establishment: item })}>
            <Text style={st.cardTitle}>{item.name}</Text>
            <Text>{item.description}</Text>
            <Text style={st.muted}>{item.address} · {item.openTime}–{item.closeTime}</Text>
          </Pressable>
        )}
      />
    </View>
  );
}

export function EstablishmentDetailScreen({ route, navigation }) {
  const { establishment } = route.params;
  const bloc = useBloc(() => new ServicesBloc());
  const state = useBlocState(bloc);
  useEffect(() => { navigation.setOptions({ title: establishment.name }); bloc.add({ type: 'Load', establishmentId: establishment.id }); }, []);
  return (
    <View style={{ flex: 1, padding: 12 }}>
      <Text>{establishment.description}</Text>
      <Text style={st.muted}>Horario: {establishment.openTime} – {establishment.closeTime}</Text>
      {state.status === 'loading' && <Loading />}
      <ErrorText error={state.error} />
      <FlatList
        data={state.items}
        keyExtractor={(i) => i.id}
        ListEmptyComponent={state.status === 'success' ? <Empty text="Este establecimiento aún no tiene servicios" /> : null}
        renderItem={({ item }) => (
          <View style={st.card}>
            <Text style={st.cardTitle}>{item.name}</Text>
            <Text>{item.description}</Text>
            <Text style={st.muted}>${item.price.toFixed(2)} · {item.durationMin} min</Text>
            <Btn title="Reservar" onPress={() => navigation.navigate('Reservar', { service: item })} />
          </View>
        )}
      />
    </View>
  );
}

const nextDays = (n) => Array.from({ length: n }, (_, i) => {
  const d = new Date(); d.setDate(d.getDate() + i);
  const iso = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  return { iso, label: d.toLocaleDateString('es-MX', { weekday: 'short', day: 'numeric', month: 'short' }) };
});

export function BookingScreen({ route, navigation }) {
  const { service } = route.params;
  const bloc = useBloc(() => new BookingBloc());
  const state = useBlocState(bloc);
  const days = useMemo(() => nextDays(14), []);
  const [selected, setSelected] = useState(null);
  useEffect(() => { bloc.add({ type: 'LoadSlots', serviceId: service.id, date: days[0].iso }); }, []);
  useEffect(() => {
    if (state.status === 'booked') {
      Alert.alert('¡Listo!', `Tu cita para ${service.name} el ${fmtDate(state.booked.start)} quedó registrada.`,
        [{ text: 'Ver mis citas', onPress: () => navigation.navigate('ClientHome', { screen: 'MisReservaciones' }) }]);
      setSelected(null);
    }
  }, [state.status]);
  const confirm = () => Alert.alert('Confirmar reservación', `${service.name}\n${fmtDate(selected)}\n$${service.price.toFixed(2)}`, [
    { text: 'Cancelar', style: 'cancel' },
    { text: 'Reservar', onPress: () => bloc.add({ type: 'Book', serviceId: service.id, start: selected }) },
  ]);
  return (
    <View style={{ flex: 1, padding: 12 }}>
      <Text style={st.cardTitle}>{service.name} · {service.durationMin} min · ${service.price.toFixed(2)}</Text>
      <FlatList horizontal data={days} keyExtractor={(d) => d.iso} style={{ flexGrow: 0, marginVertical: 8 }}
        renderItem={({ item }) => (
          <Pressable onPress={() => { setSelected(null); bloc.add({ type: 'LoadSlots', serviceId: service.id, date: item.iso }); }}
            style={[st.chip, state.date === item.iso && st.chipActive]}>
            <Text style={state.date === item.iso ? { color: '#fff' } : null}>{item.label}</Text>
          </Pressable>
        )} />
      <ErrorText error={state.error} />
      {state.status === 'loading' ? <Loading /> : (
        <FlatList data={state.slots} numColumns={4} keyExtractor={(s) => s}
          ListEmptyComponent={<Empty text="No hay horarios disponibles este día" />}
          renderItem={({ item }) => (
            <Pressable onPress={() => setSelected(item)} style={[st.slot, selected === item && st.chipActive]}>
              <Text style={selected === item ? { color: '#fff' } : null}>{fmtTime(item)}</Text>
            </Pressable>
          )} />
      )}
      <Btn title="Reservar horario" disabled={!selected || state.status === 'loading'} onPress={confirm} />
    </View>
  );
}

export function MyReservationsScreen() {
  const bloc = useBloc(() => new ReservationsBloc('cliente'));
  const state = useBlocState(bloc);
  useFocusEffect(React.useCallback(() => { bloc.add({ type: 'Load' }); }, []));
  const cancel = (r) => Alert.alert('Cancelar cita', '¿Seguro que deseas cancelar?', [
    { text: 'No' }, { text: 'Sí, cancelar', style: 'destructive', onPress: () => bloc.add({ type: 'ChangeStatus', id: r.id, status: 'cancelada' }) },
  ]);
  return (
    <FlatList contentContainerStyle={{ padding: 12 }} data={state.items} keyExtractor={(i) => i.id}
      refreshControl={<RefreshControl refreshing={state.status === 'loading'} onRefresh={() => bloc.add({ type: 'Load' })} />}
      ListHeaderComponent={<><ErrorText error={state.error} />{state.message && <Text style={st.ok}>{state.message}</Text>}</>}
      ListEmptyComponent={state.status === 'success' ? <Empty text="Aún no tienes reservaciones" /> : null}
      renderItem={({ item }) => (
        <View style={st.card}>
          <Text style={st.cardTitle}>{item.service?.name} — {item.establishment?.name}</Text>
          <Text>{fmtDate(item.start)} a {fmtTime(item.end)}</Text>
          <Badge status={item.status} />
          {['pendiente', 'confirmada'].includes(item.status) && new Date(item.start) > new Date() &&
            <Btn title="Cancelar" color="#dc2626" onPress={() => cancel(item)} />}
        </View>
      )} />
  );
}

export function NotificationsScreen() {
  const bloc = useContext(NotificationsContext);
  const state = useBlocState(bloc);
  useFocusEffect(React.useCallback(() => { bloc.add({ type: 'MarkRead' }); }, []));
  return (
    <FlatList contentContainerStyle={{ padding: 12 }} data={state.items} keyExtractor={(i) => i.id}
      ListEmptyComponent={<Empty text="Sin notificaciones" />}
      renderItem={({ item }) => (
        <View style={[st.card, !item.read && { borderColor: '#4f46e5' }]}>
          <Text style={st.cardTitle}>{item.title}</Text>
          <Text>{item.body}</Text>
          <Text style={st.muted}>{fmtDate(item.createdAt)}</Text>
        </View>
      )} />
  );
}

// ================= ADMINISTRADOR =================
const DAY_NAMES = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

export function MyEstablishmentScreen() {
  const bloc = useBloc(() => new MyEstablishmentBloc());
  const state = useBlocState(bloc);
  const [f, setF] = useState({ name: '', description: '', address: '', openTime: '09:00', closeTime: '18:00', days: [1, 2, 3, 4, 5, 6] });
  useEffect(() => { bloc.add({ type: 'Load' }); }, []);
  useEffect(() => { if (state.establishment) setF(state.establishment); }, [state.establishment]);
  const set = (k) => (v) => setF((x) => ({ ...x, [k]: v }));
  const toggleDay = (d) => set('days')(f.days.includes(d) ? f.days.filter((x) => x !== d) : [...f.days, d].sort());
  const save = () => {
    const re = /^([01]\d|2[0-3]):[0-5]\d$/;
    if (!f.name) return Alert.alert('Validación', 'El nombre es obligatorio');
    if (!re.test(f.openTime) || !re.test(f.closeTime)) return Alert.alert('Validación', 'Usa formato HH:MM');
    bloc.add({ type: 'Save', data: f });
  };
  return (
    <ScrollView contentContainerStyle={st.container}>
      <Text style={st.title}>{state.establishment ? 'Mi establecimiento' : 'Registra tu establecimiento'}</Text>
      <Field placeholder="Nombre" value={f.name} onChangeText={set('name')} />
      <Field placeholder="Descripción" value={f.description} onChangeText={set('description')} multiline />
      <Field placeholder="Dirección" value={f.address} onChangeText={set('address')} />
      <View style={st.row}>
        <Field placeholder="Abre (HH:MM)" value={f.openTime} onChangeText={set('openTime')} style={[st.input, { flex: 1 }]} />
        <Field placeholder="Cierra (HH:MM)" value={f.closeTime} onChangeText={set('closeTime')} style={[st.input, { flex: 1 }]} />
      </View>
      <View style={[st.row, { flexWrap: 'wrap' }]}>
        {DAY_NAMES.map((n, i) => (
          <Pressable key={n} onPress={() => toggleDay(i)} style={[st.chip, f.days.includes(i) && st.chipActive]}>
            <Text style={f.days.includes(i) ? { color: '#fff' } : null}>{n}</Text>
          </Pressable>
        ))}
      </View>
      <ErrorText error={state.error} />
      {state.message && <Text style={st.ok}>{state.message}</Text>}
      {state.status === 'loading' ? <Loading /> : <Btn title="Guardar" onPress={save} />}
    </ScrollView>
  );
}

export const adminServicesBloc = new ServicesBloc();

export function AdminServicesScreen({ navigation }) {
  const state = useBlocState(adminServicesBloc);
  const estBloc = useBloc(() => new MyEstablishmentBloc());
  const est = useBlocState(estBloc);
  useFocusEffect(React.useCallback(() => { estBloc.add({ type: 'Load' }); }, []));
  useEffect(() => { if (est.establishment) adminServicesBloc.add({ type: 'Load', establishmentId: est.establishment.id }); }, [est.establishment?.id]);
  if (est.status === 'success' && !est.establishment) return <Empty text="Primero registra tu establecimiento" />;
  const remove = (s) => Alert.alert('Eliminar', `¿Eliminar "${s.name}"?`, [
    { text: 'No' }, { text: 'Eliminar', style: 'destructive', onPress: () => adminServicesBloc.add({ type: 'Delete', id: s.id }) },
  ]);
  return (
    <View style={{ flex: 1, padding: 12 }}>
      <Btn title="+ Agregar servicio" onPress={() => navigation.navigate('ServiceForm', {})} />
      <ErrorText error={state.error} />
      {state.message && <Text style={st.ok}>{state.message}</Text>}
      <FlatList data={state.items} keyExtractor={(i) => i.id}
        ListEmptyComponent={state.status === 'success' ? <Empty text="Sin servicios" /> : null}
        renderItem={({ item }) => (
          <View style={st.card}>
            <Text style={st.cardTitle}>{item.name}</Text>
            <Text>{item.description}</Text>
            <Text style={st.muted}>${item.price.toFixed(2)} · {item.durationMin} min</Text>
            <View style={st.row}>
              <Btn title="Editar" onPress={() => navigation.navigate('ServiceForm', { service: item })} />
              <Btn title="Eliminar" color="#dc2626" onPress={() => remove(item)} />
            </View>
          </View>
        )} />
    </View>
  );
}

export function ServiceFormScreen({ route, navigation }) {
  const svc = route.params?.service;
  const state = useBlocState(adminServicesBloc);
  const [f, setF] = useState({ name: svc?.name ?? '', description: svc?.description ?? '', price: String(svc?.price ?? ''), durationMin: String(svc?.durationMin ?? '30') });
  const [submitted, setSubmitted] = useState(false);
  const set = (k) => (v) => setF((x) => ({ ...x, [k]: v }));
  useEffect(() => { if (submitted && state.status === 'success') navigation.goBack(); }, [state.status, submitted]);
  const save = () => {
    const price = Number(f.price), durationMin = parseInt(f.durationMin, 10);
    if (!f.name || isNaN(price) || price < 0 || !(durationMin > 0)) return Alert.alert('Validación', 'Revisa nombre, precio y duración');
    setSubmitted(true);
    adminServicesBloc.add({ type: 'Save', service: { id: svc?.id, name: f.name, description: f.description, price, durationMin } });
  };
  return (
    <ScrollView contentContainerStyle={st.container}>
      <Field placeholder="Nombre" value={f.name} onChangeText={set('name')} />
      <Field placeholder="Descripción" value={f.description} onChangeText={set('description')} multiline />
      <Field placeholder="Precio" keyboardType="decimal-pad" value={f.price} onChangeText={set('price')} />
      <Field placeholder="Duración (minutos)" keyboardType="number-pad" value={f.durationMin} onChangeText={set('durationMin')} />
      <ErrorText error={state.error} />
      {state.status === 'loading' ? <Loading /> : <Btn title="Guardar" onPress={save} />}
    </ScrollView>
  );
}

export function AdminReservationsScreen() {
  const bloc = useBloc(() => new ReservationsBloc('admin'));
  const state = useBlocState(bloc);
  const [filter, setFilter] = useState('todas');
  useFocusEffect(React.useCallback(() => { bloc.add({ type: 'Load' }); }, []));
  const items = filter === 'todas' ? state.items : state.items.filter((r) => r.status === filter);
  const change = (r, status) => bloc.add({ type: 'ChangeStatus', id: r.id, status });
  return (
    <View style={{ flex: 1, padding: 12 }}>
      <View style={[st.row, { flexWrap: 'wrap' }]}>
        {['todas', 'pendiente', 'confirmada', 'finalizada', 'cancelada'].map((s) => (
          <Pressable key={s} onPress={() => setFilter(s)} style={[st.chip, filter === s && st.chipActive]}>
            <Text style={filter === s ? { color: '#fff' } : null}>{s}</Text>
          </Pressable>
        ))}
      </View>
      <ErrorText error={state.error} />
      {state.message && <Text style={st.ok}>{state.message}</Text>}
      <FlatList data={items} keyExtractor={(i) => i.id}
        refreshControl={<RefreshControl refreshing={state.status === 'loading'} onRefresh={() => bloc.add({ type: 'Load' })} />}
        ListEmptyComponent={state.status === 'success' ? <Empty text="Sin reservaciones" /> : null}
        renderItem={({ item }) => (
          <View style={st.card}>
            <Text style={st.cardTitle}>{item.service?.name} — {item.client.name}</Text>
            <Text>{fmtDate(item.start)} a {fmtTime(item.end)}</Text>
            <Badge status={item.status} />
            <View style={st.row}>
              {item.status === 'pendiente' && <Btn title="Confirmar" onPress={() => change(item, 'confirmada')} />}
              {item.status === 'confirmada' && <Btn title="Finalizar" color="#16a34a" onPress={() => change(item, 'finalizada')} />}
              {['pendiente', 'confirmada'].includes(item.status) && <Btn title="Cancelar" color="#dc2626" onPress={() => change(item, 'cancelada')} />}
            </View>
          </View>
        )} />
    </View>
  );
}

const st = StyleSheet.create({
  container: { padding: 16, gap: 4 },
  title: { fontSize: 24, fontWeight: 'bold', marginBottom: 12 },
  input: { borderWidth: 1, borderColor: '#ccc', borderRadius: 8, padding: 10, marginVertical: 6, backgroundColor: '#fff' },
  btn: { padding: 12, borderRadius: 8, alignItems: 'center', marginVertical: 6, flexGrow: 1 },
  btnText: { color: '#fff', fontWeight: 'bold' },
  link: { color: '#4f46e5', textAlign: 'center', marginTop: 12 },
  error: { color: '#dc2626', marginVertical: 6 },
  ok: { color: '#16a34a', marginVertical: 6 },
  empty: { textAlign: 'center', color: '#888', marginTop: 32 },
  card: { backgroundColor: '#fff', borderRadius: 10, padding: 12, marginVertical: 6, borderWidth: 1, borderColor: '#eee' },
  cardTitle: { fontSize: 16, fontWeight: 'bold' },
  muted: { color: '#666', marginTop: 4 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 8, justifyContent: 'space-between' },
  chip: { paddingHorizontal: 12, paddingVertical: 8, borderRadius: 16, borderWidth: 1, borderColor: '#4f46e5', margin: 3 },
  chipActive: { backgroundColor: '#4f46e5' },
  slot: { flex: 1, margin: 4, padding: 10, borderRadius: 8, borderWidth: 1, borderColor: '#4f46e5', alignItems: 'center' },
  badge: { alignSelf: 'flex-start', color: '#fff', paddingHorizontal: 8, paddingVertical: 2, borderRadius: 6, marginTop: 6, fontSize: 12, overflow: 'hidden' },
  banner: { position: 'absolute', top: 40, left: 12, right: 12, zIndex: 99, backgroundColor: '#111827', padding: 12, borderRadius: 10, elevation: 8 },
  bannerTitle: { color: '#fff', fontWeight: 'bold' },
});
