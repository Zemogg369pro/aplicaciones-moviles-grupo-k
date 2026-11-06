import axios from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';
import Constants from 'expo-constants';

// Cambia la IP en app.json -> extra.apiUrl por la IP de la PC donde corre el backend
export const api = axios.create({
  baseURL: Constants.expoConfig?.extra?.apiUrl ?? 'http://10.0.2.2:3000',
  timeout: 10000,
});

api.interceptors.request.use(async (config) => {
  const token = await AsyncStorage.getItem('token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

export const errorMessage = (e) =>
  e?.response?.data?.message ?? (e?.request ? 'No hay conexión con el servidor' : e?.message ?? 'Error desconocido');
