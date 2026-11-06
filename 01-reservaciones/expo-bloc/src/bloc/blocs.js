import AsyncStorage from '@react-native-async-storage/async-storage';
import { Bloc } from './Bloc';
import { api, errorMessage } from '../api';

// Estado genérico: { status: 'initial' | 'loading' | 'success' | 'failure', data, error, message }

// ================= AUTH =================
export class AuthBloc extends Bloc {
  constructor() {
    super({ status: 'unknown', user: null, error: null });
    this.on('AppStarted', async (_, emit) => {
      const raw = await AsyncStorage.getItem('user');
      emit(raw ? { status: 'authenticated', user: JSON.parse(raw), error: null }
                : { status: 'unauthenticated', user: null, error: null });
    });
    const doAuth = (url) => async (e, emit) => {
      emit({ ...this.state, status: 'loading', error: null });
      try {
        const { data } = await api.post(url, e.payload);
        await AsyncStorage.multiSet([['token', data.token], ['user', JSON.stringify(data.user)]]);
        emit({ status: 'authenticated', user: data.user, error: null });
      } catch (err) {
        emit({ status: 'unauthenticated', user: null, error: errorMessage(err) });
      }
    };
    this.on('Login', doAuth('/auth/login'));
    this.on('Register', doAuth('/auth/register'));
    this.on('Logout', async (_, emit) => {
      await AsyncStorage.multiRemove(['token', 'user']);
      emit({ status: 'unauthenticated', user: null, error: null });
    });
  }
}

// ================= ESTABLECIMIENTOS (cliente) =================
export class EstablishmentsBloc extends Bloc {
  constructor() {
    super({ status: 'initial', items: [], error: null });
    this.on('Search', async (e, emit) => {
      emit({ ...this.state, status: 'loading' });
      try {
        const { data } = await api.get('/establishments', { params: { q: e.query || '' } });
        emit({ status: 'success', items: data, error: null });
      } catch (err) { emit({ ...this.state, status: 'failure', error: errorMessage(err) }); }
    });
  }
}

// ================= SERVICIOS (cliente y admin CRUD) =================
export class ServicesBloc extends Bloc {
  constructor() {
    super({ status: 'initial', items: [], error: null, message: null });
    this.on('Load', async (e, emit) => {
      emit({ ...this.state, status: 'loading', message: null });
      try {
        const { data } = await api.get(`/establishments/${e.establishmentId}/services`);
        emit({ status: 'success', items: data, error: null, message: null });
      } catch (err) { emit({ ...this.state, status: 'failure', error: errorMessage(err) }); }
    });
    this.on('Save', async (e, emit) => {
      emit({ ...this.state, status: 'loading', message: null });
      try {
        if (e.service.id) {
          const { data } = await api.put(`/services/${e.service.id}`, e.service);
          emit((s) => ({ ...s, status: 'success', items: s.items.map((x) => (x.id === data.id ? data : x)), message: 'Servicio actualizado', error: null }));
        } else {
          const { data } = await api.post('/services', e.service);
          emit((s) => ({ ...s, status: 'success', items: [...s.items, data], message: 'Servicio agregado', error: null }));
        }
      } catch (err) { emit({ ...this.state, status: 'failure', error: errorMessage(err) }); }
    });
    this.on('Delete', async (e, emit) => {
      try {
        await api.delete(`/services/${e.id}`);
        emit((s) => ({ ...s, items: s.items.filter((x) => x.id !== e.id), message: 'Servicio eliminado', error: null }));
      } catch (err) { emit({ ...this.state, status: 'failure', error: errorMessage(err) }); }
    });
  }
}

// ================= RESERVAR (disponibilidad) =================
export class BookingBloc extends Bloc {
  constructor() {
    super({ status: 'initial', slots: [], date: null, error: null, booked: null });
    this.on('LoadSlots', async (e, emit) => {
      emit({ ...this.state, status: 'loading', date: e.date, error: null, booked: null });
      try {
        const { data } = await api.get(`/services/${e.serviceId}/availability`, { params: { date: e.date } });
        emit({ status: 'success', slots: data, date: e.date, error: null, booked: null });
      } catch (err) { emit({ ...this.state, status: 'failure', error: errorMessage(err) }); }
    });
    this.on('Book', async (e, emit) => {
      emit({ ...this.state, status: 'loading', error: null });
      try {
        const { data } = await api.post('/reservations', { serviceId: e.serviceId, start: e.start });
        emit({ ...this.state, status: 'booked', booked: data, slots: this.state.slots.filter((s) => s !== e.start) });
      } catch (err) { emit({ ...this.state, status: 'failure', error: errorMessage(err) }); }
    });
  }
}

// ================= RESERVACIONES (historial cliente / gestión admin) =================
export class ReservationsBloc extends Bloc {
  constructor(role) {
    super({ status: 'initial', items: [], error: null, message: null });
    const url = role === 'admin' ? '/reservations/establishment' : '/reservations/mine';
    this.on('Load', async (_, emit) => {
      emit({ ...this.state, status: 'loading', message: null });
      try {
        const { data } = await api.get(url);
        emit({ status: 'success', items: data, error: null, message: null });
      } catch (err) { emit({ ...this.state, status: 'failure', error: errorMessage(err) }); }
    });
    this.on('ChangeStatus', async (e, emit) => {
      try {
        const { data } = await api.patch(`/reservations/${e.id}/status`, { status: e.status });
        emit((s) => ({ ...s, items: s.items.map((r) => (r.id === data.id ? data : r)), message: `Reservación ${e.status}`, error: null }));
      } catch (err) { emit({ ...this.state, error: errorMessage(err) }); }
    });
  }
}

// ================= ESTABLECIMIENTO PROPIO (admin) =================
export class MyEstablishmentBloc extends Bloc {
  constructor() {
    super({ status: 'initial', establishment: null, error: null, message: null });
    this.on('Load', async (_, emit) => {
      emit({ ...this.state, status: 'loading' });
      try {
        const { data } = await api.get('/establishments/mine');
        emit({ status: 'success', establishment: data, error: null, message: null });
      } catch (err) { emit({ ...this.state, status: 'failure', error: errorMessage(err) }); }
    });
    this.on('Save', async (e, emit) => {
      emit({ ...this.state, status: 'loading', message: null });
      try {
        const { data } = this.state.establishment
          ? await api.put('/establishments/mine', e.data)
          : await api.post('/establishments', e.data);
        emit({ status: 'success', establishment: data, error: null, message: 'Establecimiento guardado' });
      } catch (err) { emit({ ...this.state, status: 'failure', error: errorMessage(err) }); }
    });
  }
}

// ================= NOTIFICACIONES (polling) =================
export class NotificationsBloc extends Bloc {
  constructor() {
    super({ items: [], unread: 0, latest: null });
    this.on('Poll', async (_, emit) => {
      try {
        const { data } = await api.get('/notifications');
        const unread = data.filter((n) => !n.read);
        const prevIds = new Set(this.state.items.map((n) => n.id));
        const fresh = this.state.items.length ? unread.find((n) => !prevIds.has(n.id)) : null;
        emit({ items: data, unread: unread.length, latest: fresh || null });
      } catch { /* sin conexión: se reintenta en el siguiente ciclo */ }
    });
    this.on('MarkRead', async (_, emit) => {
      await api.post('/notifications/read').catch(() => {});
      emit((s) => ({ ...s, unread: 0, latest: null, items: s.items.map((n) => ({ ...n, read: true })) }));
    });
  }
  start() { this.add({ type: 'Poll' }); this.timer = setInterval(() => this.add({ type: 'Poll' }), 15000); }
  stop() { clearInterval(this.timer); }
}

export const authBloc = new AuthBloc();
