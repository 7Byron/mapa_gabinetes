const { test } = require('node:test');
const assert = require('node:assert/strict');

process.env.GCLOUD_PROJECT = 'demo-mapa-gabinetes';
const triggers = require('../index');
const { getFirestore } = require('firebase-admin/firestore');

for (const [name, collection] of [
  ['onDisponibilidadeWrite', 'disponibilidades'],
  ['onAlocacaoWrite', 'alocacoes'],
]) {
  test(`${name}: sincroniza criação, mudança de dia e eliminação com o SDK atualizado`, async (t) => {
    const operations = [];
    let commits = 0;
    t.mock.method(getFirestore(), 'batch', () => ({
      set: (ref, data, options) => operations.push(['set', ref.path, data, options]),
      delete: (ref) => operations.push(['delete', ref.path]),
      commit: async () => { commits++; },
    }));
    const old = { id: 'registo', data: '2026-10-27T00:00:00.000Z' };
    const updated = { ...old, data: '2026-10-28T00:00:00.000Z' };
    const snapshot = (data) => ({ exists: !!data, data: () => data });
    const run = (before, after) => triggers[name].run({
      before: snapshot(before), after: snapshot(after),
    }, { params: { unidadeId: 'unidade' } });
    const path = (day) => `unidades/unidade/dias/${day}/${collection}/registo`;

    await run(null, old);
    await run(old, updated);
    await run(updated, null);

    assert.deepEqual(operations, [
      ['set', path('2026-10-27'), old, { merge: true }],
      ['delete', path('2026-10-27')],
      ['set', path('2026-10-28'), updated, { merge: true }],
      ['delete', path('2026-10-28')],
    ]);
    assert.equal(commits, 3);
  });
}
