// Implementación del patrón BLoC (Business Logic Component) para React Native.
// La UI sólo envía EVENTOS con add() y escucha ESTADOS; toda la lógica vive en el bloc.
import { useEffect, useState } from 'react';

export class Bloc {
  constructor(initialState) {
    this._state = initialState;
    this._listeners = new Set();
    this._handlers = new Map();
  }

  get state() { return this._state; }

  // Registra el manejador de un tipo de evento: on('Login', async (event, emit) => {...})
  on(type, handler) { this._handlers.set(type, handler); }

  // Envía un evento al bloc
  async add(event) {
    const handler = this._handlers.get(event.type);
    if (!handler) throw new Error(`Evento no manejado: ${event.type}`);
    await handler(event, (newState) => this.emit(newState));
  }

  emit(newState) {
    this._state = typeof newState === 'function' ? newState(this._state) : newState;
    this._listeners.forEach((l) => l(this._state));
  }

  subscribe(listener) {
    this._listeners.add(listener);
    return () => this._listeners.delete(listener);
  }
}

// Hook equivalente a BlocBuilder: re-renderiza cuando el bloc emite un nuevo estado
export function useBlocState(bloc) {
  const [state, setState] = useState(bloc.state);
  useEffect(() => bloc.subscribe(setState), [bloc]);
  return state;
}
