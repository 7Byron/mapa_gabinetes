const { createHash } = require('node:crypto');
const campoHash = '_vistaDiariaHash';
function ordenar(valor) {
  if (Array.isArray(valor)) return valor.map(ordenar);
  if (valor !== null && typeof valor === 'object') {
    return Object.fromEntries(Object.keys(valor).sort()
      .filter((k) => k !== campoHash).map((k) => [k, ordenar(valor[k])]));
  }
  return valor;
}
function assinatura(dados) {
  return createHash('sha256').update(JSON.stringify(ordenar(dados))).digest('hex');
}
function vistaDiariaJaSincronizada(dados) {
  return dados != null && typeof dados[campoHash] === 'string' &&
    dados[campoHash] === assinatura(dados);
}
module.exports = { assinatura, vistaDiariaJaSincronizada };
