// API REST - Gestión de servicios y reservaciones
// Node.js + Express + JWT. Persistencia en db.json
const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORT = process.env.PORT || 3000;
const SECRET = process.env.JWT_SECRET || 'reservaciones-secret';
const DB_FILE = path.join(__dirname, 'db.json');

let db = { users: [], establishments: [], services: [], reservations: [], notifications: [] };
if (fs.existsSync(DB_FILE)) db = JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
const save = () => fs.writeFileSync(DB_FILE, JSON.stringify(db, null, 2));
const id = () => crypto.randomUUID();

const app = express();
app.use(cors());
app.use(express.json());

// ---------- helpers ----------
function auth(role) {
  return (req, res, next) => {
    const h = req.headers.authorization || '';
    try {
      req.user = jwt.verify(h.replace('Bearer ', ''), SECRET);
      if (role && req.user.role !== role) return res.status(403).json({ message: 'Sin permisos' });
      next();
    } catch {
      res.status(401).json({ message: 'Sesión inválida o expirada' });
    }
  };
}
const toMin = (hhmm) => { const [h, m] = hhmm.split(':').map(Number); return h * 60 + m; };
const overlaps = (aS, aE, bS, bE) => aS < bE && bS < aE;
const publicUser = (u) => ({ id: u.id, name: u.name, email: u.email, role: u.role });
function notify(userId, title, body) {
  db.notifications.push({ id: id(), userId, title, body, read: false, createdAt: new Date().toISOString() });
}
function ownEstablishment(req, res) {
  const est = db.establishments.find((e) => e.ownerId === req.user.id);
  if (!est) { res.status(404).json({ message: 'Primero registra tu establecimiento' }); return null; }
  return est;
}

// Calcula los horarios disponibles considerando la duración del servicio
function availableSlots(service, dateStr) {
  const est = db.establishments.find((e) => e.id === service.establishmentId);
  const date = new Date(dateStr + 'T00:00:00');
  if (!est.days.includes(date.getDay())) return [];
  const open = toMin(est.openTime), close = toMin(est.closeTime);
  const busy = db.reservations
    .filter((r) => r.establishmentId === est.id && ['pendiente', 'confirmada'].includes(r.status))
    .map((r) => [new Date(r.start).getTime(), new Date(r.end).getTime()]);
  const now = Date.now();
  const slots = [];
  for (let m = open; m + service.durationMin <= close; m += 15) {
    const start = new Date(date); start.setMinutes(m);
    const end = new Date(start.getTime() + service.durationMin * 60000);
    if (start.getTime() <= now) continue; // no fechas/horas pasadas
    if (busy.some(([s, e]) => overlaps(start.getTime(), end.getTime(), s, e))) continue; // ocupado
    slots.push(start.toISOString());
  }
  return slots;
}

// ---------- auth ----------
app.post('/auth/register', async (req, res) => {
  const { name, email, password, role } = req.body;
  if (!name || !email || !password) return res.status(400).json({ message: 'Datos incompletos' });
  if (password.length < 6) return res.status(400).json({ message: 'La contraseña debe tener al menos 6 caracteres' });
  if (db.users.some((u) => u.email === email.toLowerCase())) return res.status(409).json({ message: 'El correo ya está registrado' });
  const user = { id: id(), name, email: email.toLowerCase(), role: role === 'admin' ? 'admin' : 'cliente', password: await bcrypt.hash(password, 10) };
  db.users.push(user); save();
  res.status(201).json({ token: jwt.sign(publicUser(user), SECRET, { expiresIn: '7d' }), user: publicUser(user) });
});

app.post('/auth/login', async (req, res) => {
  const user = db.users.find((u) => u.email === (req.body.email || '').toLowerCase());
  if (!user || !(await bcrypt.compare(req.body.password || '', user.password)))
    return res.status(401).json({ message: 'Credenciales incorrectas' });
  res.json({ token: jwt.sign(publicUser(user), SECRET, { expiresIn: '7d' }), user: publicUser(user) });
});

// ---------- establecimientos ----------
app.get('/establishments', auth(), (req, res) => {
  const q = (req.query.q || '').toLowerCase();
  const list = db.establishments.filter((e) => {
    if (!q) return true;
    const services = db.services.filter((s) => s.establishmentId === e.id);
    return e.name.toLowerCase().includes(q) || e.description.toLowerCase().includes(q) ||
      services.some((s) => s.name.toLowerCase().includes(q));
  });
  res.json(list);
});
app.get('/establishments/mine', auth('admin'), (req, res) => {
  res.json(db.establishments.find((e) => e.ownerId === req.user.id) || null);
});
app.post('/establishments', auth('admin'), (req, res) => {
  if (db.establishments.some((e) => e.ownerId === req.user.id)) return res.status(409).json({ message: 'Ya tienes un establecimiento' });
  const { name, description = '', address = '', openTime = '09:00', closeTime = '18:00', days = [1, 2, 3, 4, 5, 6] } = req.body;
  if (!name) return res.status(400).json({ message: 'El nombre es obligatorio' });
  if (toMin(openTime) >= toMin(closeTime)) return res.status(400).json({ message: 'Horario inválido' });
  const est = { id: id(), ownerId: req.user.id, name, description, address, openTime, closeTime, days };
  db.establishments.push(est); save();
  res.status(201).json(est);
});
app.put('/establishments/mine', auth('admin'), (req, res) => {
  const est = ownEstablishment(req, res); if (!est) return;
  const { name, description, address, openTime, closeTime, days } = req.body;
  if (openTime && closeTime && toMin(openTime) >= toMin(closeTime)) return res.status(400).json({ message: 'Horario inválido' });
  Object.assign(est, Object.fromEntries(Object.entries({ name, description, address, openTime, closeTime, days }).filter(([, v]) => v !== undefined)));
  save(); res.json(est);
});

// ---------- servicios ----------
app.get('/establishments/:id/services', auth(), (req, res) => {
  res.json(db.services.filter((s) => s.establishmentId === req.params.id));
});
app.post('/services', auth('admin'), (req, res) => {
  const est = ownEstablishment(req, res); if (!est) return;
  const { name, description = '', price, durationMin } = req.body;
  if (!name || !(price >= 0) || !(durationMin > 0)) return res.status(400).json({ message: 'Nombre, precio y duración son obligatorios' });
  const s = { id: id(), establishmentId: est.id, name, description, price: Number(price), durationMin: Number(durationMin) };
  db.services.push(s); save(); res.status(201).json(s);
});
app.put('/services/:id', auth('admin'), (req, res) => {
  const est = ownEstablishment(req, res); if (!est) return;
  const s = db.services.find((x) => x.id === req.params.id && x.establishmentId === est.id);
  if (!s) return res.status(404).json({ message: 'Servicio no encontrado' });
  ['name', 'description'].forEach((k) => req.body[k] !== undefined && (s[k] = req.body[k]));
  if (req.body.price !== undefined) s.price = Number(req.body.price);
  if (req.body.durationMin !== undefined) s.durationMin = Number(req.body.durationMin);
  save(); res.json(s);
});
app.delete('/services/:id', auth('admin'), (req, res) => {
  const est = ownEstablishment(req, res); if (!est) return;
  const before = db.services.length;
  db.services = db.services.filter((x) => !(x.id === req.params.id && x.establishmentId === est.id));
  if (before === db.services.length) return res.status(404).json({ message: 'Servicio no encontrado' });
  save(); res.status(204).end();
});
app.get('/services/:id/availability', auth(), (req, res) => {
  const s = db.services.find((x) => x.id === req.params.id);
  if (!s) return res.status(404).json({ message: 'Servicio no encontrado' });
  if (!/^\d{4}-\d{2}-\d{2}$/.test(req.query.date || '')) return res.status(400).json({ message: 'Fecha inválida' });
  res.json(availableSlots(s, req.query.date));
});

// ---------- reservaciones ----------
const expand = (r) => ({
  ...r,
  service: db.services.find((s) => s.id === r.serviceId) || null,
  establishment: db.establishments.find((e) => e.id === r.establishmentId) || null,
  client: publicUser(db.users.find((u) => u.id === r.clientId) || { id: '', name: '?', email: '', role: '' }),
});

app.post('/reservations', auth('cliente'), (req, res) => {
  const s = db.services.find((x) => x.id === req.body.serviceId);
  if (!s) return res.status(404).json({ message: 'Servicio no encontrado' });
  const start = new Date(req.body.start);
  if (isNaN(start)) return res.status(400).json({ message: 'Fecha inválida' });
  if (start.getTime() <= Date.now()) return res.status(400).json({ message: 'No se puede reservar en fechas pasadas' });
  const dateStr = req.body.start.slice(0, 10);
  // Se valida de nuevo en el servidor para evitar dobles reservaciones
  const slots = availableSlots(s, dateStr);
  if (!slots.includes(start.toISOString())) return res.status(409).json({ message: 'El horario ya no está disponible' });
  const r = {
    id: id(), clientId: req.user.id, establishmentId: s.establishmentId, serviceId: s.id,
    start: start.toISOString(), end: new Date(start.getTime() + s.durationMin * 60000).toISOString(),
    status: 'pendiente', createdAt: new Date().toISOString(),
  };
  db.reservations.push(r);
  const est = db.establishments.find((e) => e.id === s.establishmentId);
  notify(est.ownerId, 'Nueva reservación', `${req.user.name} reservó ${s.name}`);
  save(); res.status(201).json(expand(r));
});
app.get('/reservations/mine', auth('cliente'), (req, res) => {
  res.json(db.reservations.filter((r) => r.clientId === req.user.id).sort((a, b) => b.start.localeCompare(a.start)).map(expand));
});
app.get('/reservations/establishment', auth('admin'), (req, res) => {
  const est = ownEstablishment(req, res); if (!est) return;
  res.json(db.reservations.filter((r) => r.establishmentId === est.id).sort((a, b) => a.start.localeCompare(b.start)).map(expand));
});
app.patch('/reservations/:id/status', auth(), (req, res) => {
  const r = db.reservations.find((x) => x.id === req.params.id);
  if (!r) return res.status(404).json({ message: 'Reservación no encontrada' });
  const { status } = req.body;
  const est = db.establishments.find((e) => e.id === r.establishmentId);
  const transitions = {
    cliente: { pendiente: ['cancelada'], confirmada: ['cancelada'] },
    admin: { pendiente: ['confirmada', 'cancelada'], confirmada: ['finalizada', 'cancelada'] },
  };
  if (req.user.role === 'cliente' && r.clientId !== req.user.id) return res.status(403).json({ message: 'Sin permisos' });
  if (req.user.role === 'admin' && est.ownerId !== req.user.id) return res.status(403).json({ message: 'Sin permisos' });
  if (!(transitions[req.user.role][r.status] || []).includes(status))
    return res.status(400).json({ message: `No se puede cambiar de ${r.status} a ${status}` });
  r.status = status;
  const svc = db.services.find((s) => s.id === r.serviceId);
  if (req.user.role === 'admin') notify(r.clientId, 'Tu cita cambió', `${svc ? svc.name : 'Servicio'}: ${status}`);
  else notify(est.ownerId, 'Cita cancelada', `${req.user.name} canceló ${svc ? svc.name : 'una cita'}`);
  save(); res.json(expand(r));
});

// ---------- notificaciones ----------
app.get('/notifications', auth(), (req, res) => {
  res.json(db.notifications.filter((n) => n.userId === req.user.id).sort((a, b) => b.createdAt.localeCompare(a.createdAt)));
});
app.post('/notifications/read', auth(), (req, res) => {
  db.notifications.filter((n) => n.userId === req.user.id).forEach((n) => (n.read = true));
  save(); res.status(204).end();
});

app.listen(PORT, () => console.log(`API de reservaciones en http://localhost:${PORT}`));
