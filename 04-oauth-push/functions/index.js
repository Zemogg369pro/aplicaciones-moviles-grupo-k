// Cloud Functions (2ª gen): detección de coincidencias y envío de notificaciones push con FCM
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();

const jaccard = (a = [], b = []) => {
  const A = new Set(a), B = new Set(b);
  const inter = [...A].filter((x) => B.has(x)).length;
  const union = new Set([...A, ...B]).size;
  return union === 0 ? 0 : inter / union;
};

/** Envía una notificación a todos los dispositivos de un usuario y limpia tokens inválidos */
async function pushToUser(uid, title, body, data) {
  const user = await db.collection('users').doc(uid).get();
  const tokens = user.get('fcmTokens') || [];
  if (!tokens.length) return;
  const res = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body }, // con "notification" el SO la muestra aunque la app esté cerrada
    data, // usado por la app para abrir la publicación/conversación
    android: { priority: 'high', notification: { channelId: 'objetos_channel', clickAction: 'FLUTTER_NOTIFICATION_CLICK' } },
    apns: { payload: { aps: { sound: 'default' } } },
  });
  const invalid = res.responses
    .map((r, i) => (!r.success && ['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(r.error?.code) ? tokens[i] : null))
    .filter(Boolean);
  if (invalid.length) await user.ref.update({ fcmTokens: FieldValue.arrayRemove(...invalid) });
}

/**
 * Al crear (o editar) una publicación busca publicaciones del tipo opuesto, pendientes y de la
 * misma categoría. Calcula un puntaje con la descripción (60 %) y la ubicación (40 %).
 */
async function findMatches(postId, post) {
  if (post.status !== 'pendiente') return;
  const opposite = post.type === 'perdido' ? 'encontrado' : 'perdido';
  const candidates = await db.collection('posts')
    .where('type', '==', opposite)
    .where('category', '==', post.category)
    .where('status', '==', 'pendiente')
    .get();

  for (const doc of candidates.docs) {
    const other = doc.data();
    if (other.ownerId === post.ownerId) continue;
    const score = 0.6 * jaccard(post.keywords, other.keywords) + 0.4 * jaccard(post.locationKeywords, other.locationKeywords);
    if (score < 0.2) continue;

    const matchId = [postId, doc.id].sort().join('_');
    const ref = db.collection('matches').doc(matchId);
    if ((await ref.get()).exists) continue; // no notificar dos veces la misma coincidencia
    await ref.set({ postIds: [postId, doc.id], users: [post.ownerId, other.ownerId], score, createdAt: FieldValue.serverTimestamp() });

    const pct = Math.round(score * 100);
    await Promise.all([
      pushToUser(post.ownerId, 'Posible coincidencia 🔎', `"${other.name}" (${opposite}) en ${other.location} · ${pct}%`, { type: 'match', postId: doc.id }),
      pushToUser(other.ownerId, 'Posible coincidencia 🔎', `"${post.name}" (${post.type}) en ${post.location} · ${pct}%`, { type: 'match', postId }),
    ]);
  }
}

exports.onPostCreated = onDocumentCreated('posts/{postId}', (e) => findMatches(e.params.postId, e.data.data()));

exports.onPostUpdated = onDocumentUpdated('posts/{postId}', (e) => {
  const before = e.data.before.data(), after = e.data.after.data();
  const changed = ['name', 'description', 'category', 'location'].some((k) => before[k] !== after[k]);
  return changed ? findMatches(e.params.postId, after) : null;
});

/** Notifica al otro participante cuando llega un mensaje nuevo */
exports.onMessageCreated = onDocumentCreated('chats/{chatId}/messages/{msgId}', async (e) => {
  const msg = e.data.data();
  const chat = (await db.collection('chats').doc(e.params.chatId).get()).data();
  const to = chat.participants.find((p) => p !== msg.senderId);
  if (!to) return;
  const sender = chat.names?.[msg.senderId] || 'Alguien';
  await pushToUser(to, `${sender} · ${chat.postName}`, msg.text.slice(0, 120), { type: 'chat', chatId: e.params.chatId });
});
