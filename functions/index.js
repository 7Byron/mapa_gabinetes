// Firebase Functions v1 (1st Gen) para manter compatibilidade com funções já criadas
const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
admin.initializeApp();

// Util: normaliza yyyy-MM-dd
function dateKeyFromIso(iso) {
  const d = new Date(iso);
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

// Atualiza "vista diária" quando criamos/alteramos/apagamos disponibilidades
exports.onDisponibilidadeWrite = functions.firestore
  .document('unidades/{unidadeId}/ocupantes/{medicoId}/disponibilidades/{ano}/registos/{dispId}')
  .onWrite(async (change, context) => {
    const { unidadeId } = context.params;
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;

    const db = admin.firestore();
    const batch = db.batch();

    function upsert(dayKey, payload) {
      const ref = db
        .collection('unidades')
        .doc(unidadeId)
        .collection('dias')
        .doc(dayKey)
        .collection('disponibilidades')
        .doc(payload.id);
      batch.set(ref, payload, { merge: true });
    }

    function remove(dayKey, id) {
      const ref = db
        .collection('unidades')
        .doc(unidadeId)
        .collection('dias')
        .doc(dayKey)
        .collection('disponibilidades')
        .doc(id);
      batch.delete(ref);
    }

    if (before && after) {
      // update: pode mudar a data -> remover do dia antigo, inserir no novo
      const beforeKey = dateKeyFromIso(before.data);
      const afterKey = dateKeyFromIso(after.data);
      if (beforeKey !== afterKey) {
        remove(beforeKey, before.id);
      }
      upsert(afterKey, after);
    } else if (!before && after) {
      // create
      const dayKey = dateKeyFromIso(after.data);
      upsert(dayKey, after);
    } else if (before && !after) {
      // delete
      const dayKey = dateKeyFromIso(before.data);
      remove(dayKey, before.id);
    }

    await batch.commit();
    return null;
  });

// Atualiza "vista diária" para alocações
exports.onAlocacaoWrite = functions.firestore
  .document('unidades/{unidadeId}/alocacoes/{ano}/registos/{alocId}')
  .onWrite(async (change, context) => {
    const { unidadeId } = context.params;
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;

    const db = admin.firestore();
    const batch = db.batch();

    function upsert(dayKey, payload) {
      const ref = db
        .collection('unidades')
        .doc(unidadeId)
        .collection('dias')
        .doc(dayKey)
        .collection('alocacoes')
        .doc(payload.id);
      batch.set(ref, payload, { merge: true });
    }

    function remove(dayKey, id) {
      const ref = db
        .collection('unidades')
        .doc(unidadeId)
        .collection('dias')
        .doc(dayKey)
        .collection('alocacoes')
        .doc(id);
      batch.delete(ref);
    }

    if (before && after) {
      const beforeKey = dateKeyFromIso(before.data);
      const afterKey = dateKeyFromIso(after.data);
      if (beforeKey !== afterKey) {
        remove(beforeKey, before.id);
      }
      upsert(afterKey, after);
    } else if (!before && after) {
      const dayKey = dateKeyFromIso(after.data);
      upsert(dayKey, after);
    } else if (before && !after) {
      const dayKey = dateKeyFromIso(before.data);
      remove(dayKey, before.id);
    }

    await batch.commit();
    return null;
  });

