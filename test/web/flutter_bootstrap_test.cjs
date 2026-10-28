const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('web/flutter_bootstrap.js', 'utf8').replace(/{{flutter_(js|build_config)}}/g, '');

function start({gpu = true, stored = false, blocked = false, query = ''} = {}) {
  const elements = [];
  const navigations = [];
  const nodes = [];
  let options;
  let probes = 0;
  const element = () => {
    const node = {style: {}, children: [], setAttribute() {}, append(...items) {this.children.push(...items);}, focus() {}, remove() {this.removed = true;}};
    nodes.push(node);
    return node;
  };
  const gl = {
    createShader: () => ({}), shaderSource() {}, compileShader() {},
    getShaderParameter: () => gpu, createProgram: () => ({}),
    attachShader() {}, linkProgram() {}, getProgramParameter: () => gpu,
    isContextLost: () => false, deleteProgram() {}, deleteShader() {}, getExtension: () => null,
  };
  const context = {
    URL, URLSearchParams,
    navigator: {userAgent: 'Chrome test'},
    console: {error() {}, warn() {}, log() {}},
    window: {location: {search: query, href: `https://example.test/app/?_appv=6${query.replace('?', '&')}`, replace: (url) => navigations.push(url)}},
    sessionStorage: {
      getItem() {if (blocked) throw Error('blocked'); return stored ? '1' : null;},
      setItem() {if (blocked) throw Error('blocked');},
    },
    document: {
      createElement(tag) {if (tag === 'canvas') return {getContext() {probes++; return gl;}}; return element();},
      body: {append(node) {elements.push(node);}},
    },
    _flutter: {loader: {load(value) {options = value; return Promise.resolve();}}},
  };
  vm.runInNewContext(source, context);
  return {context, elements, navigations, nodes, options, probes};
}

test('Mantém GPU quando os shaders compilam', () => {
  const app = start();
  assert.equal(app.options.config.canvasKitForceCpuOnly, false);
  assert.equal(app.probes, 1);
});
test('Falha de compilação ativa CPU antes de iniciar Flutter', () => {
  assert.equal(start({gpu: false}).options.config.canvasKitForceCpuOnly, true);
});
test('Preferência e URL ativam compatibilidade sem nova sondagem GPU', () => {
  for (const settings of [{stored: true}, {query: '?render=software'}]) {
    const app = start(settings);
    assert.equal(app.options.config.canvasKitForceCpuOnly, true);
    assert.equal(app.probes, 0);
  }
});
test('Armazenamento bloqueado não impede o arranque', () => {
  assert.equal(start({blocked: true}).options.config.canvasKitForceCpuOnly, false);
});
test('Falha durante uso mostra recuperação sem perder a sessão automaticamente', () => {
  const app = start({blocked: true});
  app.context.console.error('Shader compilation error');
  app.context.console.warn('Shader compilation error');
  assert.equal(app.elements.length, 1);
  assert.equal(app.navigations.length, 0);
  const button = app.nodes.find((node) => node.onclick);
  button.onclick();
  const url = new URL(app.navigations[0]);
  assert.equal(url.searchParams.get('render'), 'software');
  assert.equal(url.searchParams.get('_appv'), '6');
});
test('Erros de dados normais não ativam recuperação gráfica', () => {
  const app = start();
  app.context.console.error('Erro ao carregar médico');
  assert.equal(app.elements.length, 0);
});
test('Falha de inicialização também mostra recuperação', async () => {
  const app = start();
  await app.options.onEntrypointLoaded({initializeEngine: async () => {throw Error('GPU');}});
  assert.equal(app.elements.length, 1);
  assert.equal(app.navigations.length, 0);
});
test('A opção CPU chega à inicialização do motor', async () => {
  const app = start({gpu: false});
  let config;
  let runs = 0;
  await app.options.onEntrypointLoaded({initializeEngine: async (value) => {
    config = value; return {runApp: async () => runs++};
  }});
  assert.equal(config.canvasKitForceCpuOnly, true);
  assert.equal(runs, 1);
});

test('Falha transitória permite fechar o aviso e regista diagnóstico sem recarga', () => {
  const app = start();
  app.context.console.error('Shader compilation error');
  const close = app.nodes.find((node) => node.textContent === 'Fechar aviso');
  assert.ok(close);
  close.onclick();
  assert.equal(app.elements[0].removed, true);
  assert.equal(app.navigations.length, 0);
  assert.equal(app.context.window.alocmapGraphicsDiagnostics.length, 1);
  assert.equal(app.context.window.alocmapGraphicsDiagnostics[0].fatal, false);
});
