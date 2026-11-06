// Servidor de mensajería: API REST (auth, conversaciones, adjuntos) + WebSocket (tiempo real)
// + archivos de verificación para Android App Links / iOS Universal Links.
const express = require('express');
const http = require('http');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');

const PORT = process.env.PORT || 5000;
const SECRET = process.env.JWT_SECRET || 'chat-secret';
const PUBLIC_URL = process.env.PUBLIC_URL || 'https://chat.ejemplo.com';
const ANDROID_PACKAGE = process.env.ANDROID_PACKAGE || 'com.example.chat_realtime';
const ANDROID_SHA256 = process.env.ANDROID_SHA256 || 'AA:BB:CC:...'; // keytool -list -v -keystore ...
const IOS_APP_ID = process.env.IOS_APP_ID || 'TEAMID.com.example.chatRealtime';
const DB_FILE = path.join(__dirname, 'db.json');
const UPLOADS = path.join(__dirname, 'uploads');
if (!fs.existsSync(UPLOADS)) fs.mkdirSync(UPLOADS);

let db = { users: [], conversations: [], messages: [] };
if (fs.existsSync(DB_FILE)) db = JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
let saveTimer;
const save = () => { clearTimeout(saveTimer); saveTimer = setTimeout(() => fs.writeFileSync(DB_FILE, JSON.stringify(db, null, 2)), 200); };
const uid = () => crypto.randomUUID();

const app = express();
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(UPLOADS));

// ===================== helpers =====================
const online = new Map(); // userId -> Set<WebSocket>
const lastSeen = new Map();
const pub = (u) => ({ id: u.id, name: u.name, username: u.username, online: online.has(u.id), lastSeen: lastSeen.get(u.id) || null });
const conv = (id) => db.conversations.find((c) => c.id === id);
const isMember = (c, userId) => c && c.members.includes(userId);

function auth(req, res, next) {
  try {
    req.user = jwt.verify((req.headers.authorization || '').replace('Bearer ', ''), SECRET);
    next();
  } catch {
    res.status(401).json({ message: 'No autenticado' });
  }
}

function convView(c, me) {
  const msgs = db.messages.filter((m) => m.conversationId === c.id && !m.deleted);
  const last = msgs[msgs.length - 1] || null;
  const unread = msgs.filter((m) => m.senderId !== me && !m.readBy.includes(me)).length;
  const members = c.members.map((id) => pub(db.users.find((u) => u.id === id)));
  const other = c.type === 'direct' ? members.find((m) => m.id !== me) : null;
  return {
    id: c.id, type: c.type, name: c.type === 'group' ? c.name : other?.name, members, unread,
    lastMessage: last, joinPolicy: c.joinPolicy, adminId: c.adminId, link: `${PUBLIC_URL}/chat/${c.id}`,
    pendingRequests: c.adminId === me ? (c.requests || []).map((id) => pub(db.users.find((u) => u.id === id))) : [],
    updatedAt: last?.createdAt || c.createdAt,
  };
}

/** Estado agregado de un mensaje para su remitente */
function statusOf(m) {
  const c = conv(m.conversationId);
  const others = c.members.filter((x) => x !== m.senderId);
  if (others.length && others.every((o) => m.readBy.includes(o))) return 'leido';
  if (others.length && others.every((o) => m.deliveredTo.includes(o))) return 'entregado';
  return 'enviado';
}
const msgView = (m) => ({ ...m, status: statusOf(m) });

function sendTo(userId, payload) {
  const set = online.get(userId);
  if (!set) return false;
  const data = JSON.stringify(payload);
  set.forEach((ws) => ws.readyState === 1 && ws.send(data));
  return true;
}
const broadcastConv = (c, payload, except) => c.members.forEach((u) => u !== except && sendTo(u, payload));
function broadcastPresence(userId) {
  const contacts = new Set(db.conversations.filter((c) => c.members.includes(userId)).flatMap((c) => c.members));
  const p = { type: 'presence', userId, online: online.has(userId), lastSeen: lastSeen.get(userId) || null };
  // a todos los usuarios conectados (lista de usuarios disponibles)
  online.forEach((_, u) => u !== userId && sendTo(u, p));
  contacts.clear();
}

// ===================== Auth =====================
app.post('/auth/register', async (req, res) => {
  const { name, username, password } = req.body;
  if (!name || !username || !password || password.length < 6) return res.status(400).json({ message: 'Datos inválidos (contraseña mínimo 6)' });
  if (db.users.some((u) => u.username === username.toLowerCase())) return res.status(409).json({ message: 'El usuario ya existe' });
  const u = { id: uid(), name, username: username.toLowerCase(), password: await bcrypt.hash(password, 10) };
  db.users.push(u); save();
  res.status(201).json({ token: jwt.sign({ id: u.id, name: u.name }, SECRET, { expiresIn: '30d' }), user: pub(u) });
});
app.post('/auth/login', async (req, res) => {
  const u = db.users.find((x) => x.username === (req.body.username || '').toLowerCase());
  if (!u || !(await bcrypt.compare(req.body.password || '', u.password))) return res.status(401).json({ message: 'Credenciales incorrectas' });
  res.json({ token: jwt.sign({ id: u.id, name: u.name }, SECRET, { expiresIn: '30d' }), user: pub(u) });
});

// ===================== Usuarios y conversaciones =====================
app.get('/users', auth, (req, res) => res.json(db.users.filter((u) => u.id !== req.user.id).map(pub)));

app.get('/conversations', auth, (req, res) => {
  res.json(db.conversations.filter((c) => isMember(c, req.user.id)).map((c) => convView(c, req.user.id))
    .sort((a, b) => (b.updatedAt || '').localeCompare(a.updatedAt || '')));
});

app.post('/conversations', auth, (req, res) => {
  const me = req.user.id;
  if (req.body.type === 'group') {
    const { name, memberIds = [], joinPolicy = 'approval' } = req.body;
    if (!name) return res.status(400).json({ message: 'El grupo necesita nombre' });
    const c = { id: uid(), type: 'group', name, members: [...new Set([me, ...memberIds])], adminId: me, joinPolicy,
      inviteCode: crypto.randomBytes(6).toString('hex'), requests: [], createdAt: new Date().toISOString() };
    db.conversations.push(c); save();
    c.members.forEach((u) => sendTo(u, { type: 'conversation', conversation: convView(c, u) }));
    return res.status(201).json(convView(c, me));
  }
  const other = req.body.userId;
  if (!db.users.some((u) => u.id === other)) return res.status(404).json({ message: 'Usuario no encontrado' });
  let c = db.conversations.find((x) => x.type === 'direct' && x.members.includes(me) && x.members.includes(other));
  if (!c) {
    c = { id: uid(), type: 'direct', members: [me, other], createdAt: new Date().toISOString() };
    db.conversations.push(c); save();
  }
  res.json(convView(c, me));
});

// Usado por el deep link: valida que la conversación exista y que el usuario sea participante
app.get('/conversations/:id', auth, (req, res) => {
  const c = conv(req.params.id);
  if (!c) return res.status(404).json({ message: 'La conversación no existe' });
  if (!isMember(c, req.user.id)) {
    return res.status(403).json({ message: 'No tienes acceso a esta conversación', canRequestJoin: c.type === 'group', joinPolicy: c.joinPolicy });
  }
  res.json(convView(c, req.user.id));
});

// Historial (orden cronológico); sólo participantes
app.get('/conversations/:id/messages', auth, (req, res) => {
  const c = conv(req.params.id);
  if (!c) return res.status(404).json({ message: 'La conversación no existe' });
  if (!isMember(c, req.user.id)) return res.status(403).json({ message: 'Sin acceso' });
  res.json(db.messages.filter((m) => m.conversationId === c.id).sort((a, b) => a.createdAt.localeCompare(b.createdAt)).map(msgView));
});

// Enlace de invitación a grupo
app.get('/conversations/:id/invite', auth, (req, res) => {
  const c = conv(req.params.id);
  if (!c || c.type !== 'group' || !isMember(c, req.user.id)) return res.status(404).json({ message: 'Grupo no encontrado' });
  res.json({ link: `${PUBLIC_URL}/join/${c.inviteCode}`, joinPolicy: c.joinPolicy });
});

// Unirse por enlace: abierto => entra directo; aprobación => solicitud al admin
app.post('/join/:code', auth, (req, res) => {
  const c = db.conversations.find((x) => x.inviteCode === req.params.code);
  if (!c) return res.status(404).json({ message: 'Enlace de invitación inválido' });
  const me = req.user.id;
  if (isMember(c, me)) return res.json({ status: 'member', conversation: convView(c, me) });
  if (c.joinPolicy === 'open') {
    c.members.push(me); save();
    broadcastConv(c, { type: 'conversation', conversation: null, refresh: true });
    return res.json({ status: 'joined', conversation: convView(c, me) });
  }
  if (!c.requests.includes(me)) c.requests.push(me);
  save();
  sendTo(c.adminId, { type: 'join_request', conversationId: c.id, user: pub(db.users.find((u) => u.id === me)) });
  res.status(202).json({ status: 'requested', groupName: c.name });
});

app.post('/conversations/:id/requests/:userId', auth, (req, res) => {
  const c = conv(req.params.id);
  if (!c || c.adminId !== req.user.id) return res.status(403).json({ message: 'Sólo el administrador' });
  c.requests = c.requests.filter((x) => x !== req.params.userId);
  if (req.body.accept) c.members.push(req.params.userId);
  save();
  if (req.body.accept) sendTo(req.params.userId, { type: 'conversation', conversation: convView(c, req.params.userId) });
  res.json(convView(c, req.user.id));
});

// Adjuntos por HTTP; el WebSocket notifica su disponibilidad
const upload = multer({
  storage: multer.diskStorage({
    destination: UPLOADS,
    filename: (_, f, cb) => cb(null, `${uid()}${path.extname(f.originalname)}`),
  }),
  limits: { fileSize: 20 * 1024 * 1024 },
});
app.post('/upload', auth, upload.single('file'), (req, res) => {
  if (!req.file) return res.status(400).json({ message: 'Archivo requerido' });
  res.status(201).json({ url: `/uploads/${req.file.filename}`, name: req.file.originalname, mime: req.file.mimetype, size: req.file.size });
});

// ===================== Deep Linking (App Links / Universal Links) =====================
app.get('/.well-known/assetlinks.json', (_, res) => res.json([{
  relation: ['delegate_permission/common.handle_all_urls'],
  target: { namespace: 'android_app', package_name: ANDROID_PACKAGE, sha256_cert_fingerprints: [ANDROID_SHA256] },
}]));
app.get('/.well-known/apple-app-site-association', (_, res) => res.json({
  applinks: { apps: [], details: [{ appID: IOS_APP_ID, paths: ['/chat/*', '/join/*'] }] },
}));
// Si la app no está instalada, el enlace abre esta página web
app.get(['/chat/:id', '/join/:code'], (req, res) => res.send(`<!doctype html><meta name="viewport" content="width=device-width">
  <h2>Chat en tiempo real</h2><p>Abre este enlace desde tu teléfono con la app instalada.</p>
  <a href="chatapp:/${req.path}">Abrir en la app</a>`));

// ===================== WebSocket =====================
const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });

wss.on('connection', (ws, req) => {
  let user;
  try {
    const token = new URL(req.url, 'http://x').searchParams.get('token');
    user = jwt.verify(token, SECRET);
  } catch {
    ws.close(4001, 'No autenticado');
    return;
  }
  const me = user.id;
  if (!online.has(me)) online.set(me, new Set());
  online.get(me).add(ws);
  broadcastPresence(me);
  ws.isAlive = true;
  ws.on('pong', () => (ws.isAlive = true));

  // Al conectarse, los mensajes recibidos mientras estaba desconectado pasan a "entregado"
  const pendingDelivery = db.messages.filter((m) => m.senderId !== me && !m.deliveredTo.includes(me) && isMember(conv(m.conversationId), me));
  pendingDelivery.forEach((m) => {
    m.deliveredTo.push(me);
    sendTo(m.senderId, { type: 'status', messageId: m.id, conversationId: m.conversationId, status: statusOf(m) });
  });
  if (pendingDelivery.length) save();

  ws.on('message', (raw) => {
    let ev;
    try { ev = JSON.parse(raw); } catch { return; }
    const c = conv(ev.conversationId);
    if (ev.type !== 'ping' && !isMember(c, me)) return ws.send(JSON.stringify({ type: 'error', clientId: ev.clientId, message: 'Sin acceso a la conversación' }));

    switch (ev.type) {
      case 'message': {
        // Idempotencia: si el cliente reintenta con el mismo clientId no se duplica
        let m = db.messages.find((x) => x.clientId === ev.clientId && x.senderId === me);
        if (!m) {
          if (!ev.text && !ev.attachment) return;
          m = { id: uid(), clientId: ev.clientId, conversationId: c.id, senderId: me, senderName: user.name,
            text: (ev.text || '').slice(0, 4000), attachment: ev.attachment || null,
            createdAt: new Date().toISOString(), editedAt: null, deleted: false, deliveredTo: [], readBy: [] };
          c.members.forEach((u) => { if (u !== me && online.has(u)) m.deliveredTo.push(u); });
          db.messages.push(m); save();
          broadcastConv(c, { type: 'message', message: msgView(m) }, me);
        }
        ws.send(JSON.stringify({ type: 'ack', clientId: ev.clientId, message: msgView(m) }));
        // otras sesiones del mismo usuario
        online.get(me).forEach((s) => s !== ws && s.readyState === 1 && s.send(JSON.stringify({ type: 'message', message: msgView(m) })));
        break;
      }
      case 'typing':
        broadcastConv(c, { type: 'typing', conversationId: c.id, userId: me, name: user.name, isTyping: !!ev.isTyping }, me);
        break;
      case 'read': {
        const changed = db.messages.filter((m) => m.conversationId === c.id && m.senderId !== me && !m.readBy.includes(me));
        changed.forEach((m) => {
          m.readBy.push(me);
          if (!m.deliveredTo.includes(me)) m.deliveredTo.push(me);
          sendTo(m.senderId, { type: 'status', messageId: m.id, conversationId: c.id, status: statusOf(m) });
        });
        if (changed.length) save();
        break;
      }
      case 'edit': {
        const m = db.messages.find((x) => x.id === ev.messageId && x.senderId === me && !x.deleted);
        if (!m || !ev.text) return;
        m.text = ev.text.slice(0, 4000); m.editedAt = new Date().toISOString(); save();
        broadcastConv(c, { type: 'edited', message: msgView(m) });
        break;
      }
      case 'delete': {
        const m = db.messages.find((x) => x.id === ev.messageId && x.senderId === me);
        if (!m) return;
        m.deleted = true; m.text = ''; m.attachment = null; save();
        broadcastConv(c, { type: 'deleted', messageId: m.id, conversationId: c.id });
        break;
      }
    }
  });

  ws.on('close', () => {
    const set = online.get(me);
    set?.delete(ws);
    if (set && set.size === 0) {
      online.delete(me);
      lastSeen.set(me, new Date().toISOString());
      broadcastPresence(me);
    }
  });
});

// Heartbeat: detecta conexiones muertas
setInterval(() => wss.clients.forEach((ws) => {
  if (!ws.isAlive) return ws.terminate();
  ws.isAlive = false;
  ws.ping();
}), 30000);

server.listen(PORT, () => console.log(`Chat en http://localhost:${PORT}  ·  WebSocket ws://localhost:${PORT}/ws`));
