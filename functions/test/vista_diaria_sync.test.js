const { test } = require('node:test');
const assert = require('node:assert/strict');
const { assinatura, vistaDiariaJaSincronizada } = require('../vista_diaria_sync');
const dados = { id: 'cartao', medicoId: 'teste', data: '2026-10-28T00:00:00.000', horarios: ['14:00', '18:00'] };
test('clientes antigos continuam a sincronizar', () => {
  assert.equal(vistaDiariaJaSincronizada(dados), false);
  assert.equal(vistaDiariaJaSincronizada(null), false);
});
test('lote que escreveu a vista diária não duplica a escrita', () => {
  const marcado = { ...dados, _vistaDiariaHash: assinatura(dados) };
  assert.equal(vistaDiariaJaSincronizada(marcado), true);
  assert.equal(vistaDiariaJaSincronizada({ ...marcado, horarios: ['15:00', '18:00'] }), false);
});
test('assinatura partilhada com o cliente Dart', () => {
  assert.equal(assinatura(dados), '6730aeb9a0b2284c14d4e137826f0a4a7950006dcb6100b2bd27e840ef7f8d6b');
});
