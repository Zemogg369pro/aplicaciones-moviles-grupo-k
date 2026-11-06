// API REST para recibir reportes de incidencias sincronizados desde la app (Offline-First)
// Idempotente: el id lo genera el cliente (UUID), así los reintentos NUNCA duplican registros.
const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 4000;
const DB_FILE = path.join(__dirname, 'reports.json');
const UPLOADS = path.join(__dirname, 'uploads');
if (!fs.existsSync(UPLOADS)) fs.mkdirSync(UPLOADS);

let reports = fs.existsSync(DB_FILE) ? JSON.parse(fs.readFileSync(DB_FILE, 'utf8')) : {};
const save = () => fs.writeFileSync(DB_FILE, JSON.stringify(reports, null, 2));

const app = express();
app.use(cors());
app.use(express.json({ limit: '15mb' }));
app.use('/uploads', express.static(UPLOADS));

// Simulación opcional de red inestable: SIMULATE_FAILURES=0.3 -> 30 % de las peticiones fallan
const failRate = Number(process.env.SIMULATE_FAILURES || 0);
app.use((req, res, next) => (req.path !== '/health' && Math.random() < failRate ? res.status(503).json({ message: 'Fallo simulado' }) : next()));

// La app la usa para verificar conectividad REAL con el servidor (no sólo tener Wi-Fi/datos)
app.get('/health', (_, res) => res.json({ ok: true, time: new Date().toISOString() }));

app.get('/reports', (_, res) => res.json(Object.values(reports).filter((r) => !r.deleted)));

function upsert(req, res) {
  const id = req.params.id || req.body.id;
  const { title, description, category, lat, lng, date, updatedAt, photoBase64 } = req.body;
  if (!id || !title || !category) return res.status(400).json({ message: 'id, title y category son obligatorios' });
  const existing = reports[id];
  // Si llega una versión más vieja que la guardada (reintento tardío) se ignora pero se confirma
  if (existing && updatedAt && existing.updatedAt && existing.updatedAt >= updatedAt) {
    return res.status(200).json({ ...existing, duplicate: true });
  }
  let photoUrl = existing?.photoUrl ?? null;
  if (photoBase64) {
    const file = `${id}.jpg`;
    fs.writeFileSync(path.join(UPLOADS, file), Buffer.from(photoBase64, 'base64'));
    photoUrl = `/uploads/${file}`;
  }
  reports[id] = {
    id, title, description: description || '', category, lat, lng, date, updatedAt,
    photoUrl, deleted: false,
    receivedAt: existing?.receivedAt || new Date().toISOString(),
    version: (existing?.version || 0) + 1,
  };
  save();
  res.status(existing ? 200 : 201).json(reports[id]); // confirmación de recepción
}

app.put('/reports/:id', upsert); // crear o actualizar (idempotente)
app.post('/reports', upsert);

app.delete('/reports/:id', (req, res) => {
  if (reports[req.params.id]) {
    reports[req.params.id].deleted = true;
    save();
  }
  res.status(200).json({ id: req.params.id, deleted: true }); // idempotente: borrar dos veces no falla
});

app.listen(PORT, () => console.log(`API de incidencias en http://localhost:${PORT} (fallos simulados: ${failRate * 100}%)`));
