import React, { useEffect, useMemo } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { StatusBar } from 'expo-status-bar';
import { useBlocState } from './src/bloc/Bloc';
import { authBloc, NotificationsBloc } from './src/bloc/blocs';
import * as S from './src/screens';

const Stack = createNativeStackNavigator();
const Tab = createBottomTabNavigator();
import { NotificationsContext } from './src/context';

function ClientTabs() {
  return (
    <Tab.Navigator>
      <Tab.Screen name="Explorar" component={S.ExploreScreen} />
      <Tab.Screen name="MisReservaciones" options={{ title: 'Mis citas' }} component={S.MyReservationsScreen} />
      <Tab.Screen name="Avisos" component={S.NotificationsScreen} />
      <Tab.Screen name="Perfil" component={S.ProfileScreen} />
    </Tab.Navigator>
  );
}

function AdminTabs() {
  return (
    <Tab.Navigator>
      <Tab.Screen name="Establecimiento" component={S.MyEstablishmentScreen} />
      <Tab.Screen name="Servicios" component={S.AdminServicesScreen} />
      <Tab.Screen name="Citas" component={S.AdminReservationsScreen} />
      <Tab.Screen name="Avisos" component={S.NotificationsScreen} />
      <Tab.Screen name="Perfil" component={S.ProfileScreen} />
    </Tab.Navigator>
  );
}

export default function App() {
  const auth = useBlocState(authBloc);
  const notifications = useMemo(() => new NotificationsBloc(), [auth.user?.id]);

  useEffect(() => { authBloc.add({ type: 'AppStarted' }); }, []);
  useEffect(() => {
    if (auth.status === 'authenticated') notifications.start();
    return () => notifications.stop();
  }, [auth.status, notifications]);

  if (auth.status === 'unknown') {
    return <View style={{ flex: 1, justifyContent: 'center' }}><ActivityIndicator size="large" /></View>;
  }

  return (
    <NotificationsContext.Provider value={notifications}>
      <NavigationContainer>
        <StatusBar style="auto" />
        <S.NotificationBanner bloc={notifications} />
        <Stack.Navigator>
          {auth.status !== 'authenticated' ? (
            <>
              <Stack.Screen name="Login" component={S.LoginScreen} options={{ title: 'Iniciar sesión' }} />
              <Stack.Screen name="Registro" component={S.RegisterScreen} />
            </>
          ) : auth.user.role === 'admin' ? (
            <>
              <Stack.Screen name="AdminHome" component={AdminTabs} options={{ headerShown: false }} />
              <Stack.Screen name="ServiceForm" component={S.ServiceFormScreen} options={{ title: 'Servicio' }} />
            </>
          ) : (
            <>
              <Stack.Screen name="ClientHome" component={ClientTabs} options={{ headerShown: false }} />
              <Stack.Screen name="Establecimiento" component={S.EstablishmentDetailScreen} />
              <Stack.Screen name="Reservar" component={S.BookingScreen} />
            </>
          )}
        </Stack.Navigator>
      </NavigationContainer>
    </NotificationsContext.Provider>
  );
}
