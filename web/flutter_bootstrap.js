{{flutter_js}}
{{flutter_build_config}}

(() => {
  const storageKey = 'alocmap_software_rendering';
  const graphics = { userAgent: navigator.userAgent,
    pixelRatio: window.devicePixelRatio, vendor: null, renderer: null };
  window.alocmapGraphicsDiagnostics = [];
  const params = new URLSearchParams(window.location.search);
  const readPreference = () => {
    try { return sessionStorage.getItem(storageKey) === '1'; }
    catch (_) { return false; }
  };

  // Testar compilação e ligação antes de entregar o ecrã ao Flutter.
  // A presença de WebGL, por si só, não garante que o driver compile shaders.
  function graphicsAvailable() {
    let gl;
    let vertex;
    let fragment;
    let program;
    try {
      const canvas = document.createElement('canvas');
      gl = canvas.getContext('webgl2');
      if (!gl || gl.isContextLost()) return false;
      const info = gl.getExtension('WEBGL_debug_renderer_info');
      if (info) {
        graphics.vendor = gl.getParameter(info.UNMASKED_VENDOR_WEBGL);
        graphics.renderer = gl.getParameter(info.UNMASKED_RENDERER_WEBGL);
      }
      vertex = gl.createShader(gl.VERTEX_SHADER);
      fragment = gl.createShader(gl.FRAGMENT_SHADER);
      gl.shaderSource(vertex, '#version 300 es\nin vec2 position; void main(){gl_Position=vec4(position,0.0,1.0);}');
      gl.shaderSource(fragment, '#version 300 es\nprecision mediump float; uniform sampler2D image; out vec4 color; void main(){color=texture(image,vec2(0.5),-0.475);}');
      gl.compileShader(vertex);
      gl.compileShader(fragment);
      if (!gl.getShaderParameter(vertex, gl.COMPILE_STATUS) ||
          !gl.getShaderParameter(fragment, gl.COMPILE_STATUS)) return false;
      program = gl.createProgram();
      gl.attachShader(program, vertex);
      gl.attachShader(program, fragment);
      gl.linkProgram(program);
      return gl.getProgramParameter(program, gl.LINK_STATUS) && !gl.isContextLost();
    } catch (_) {
      return false;
    } finally {
      if (gl) {
        if (program) gl.deleteProgram(program);
        if (vertex) gl.deleteShader(vertex);
        if (fragment) gl.deleteShader(fragment);
        gl.getExtension('WEBGL_lose_context')?.loseContext();
      }
    }
  }

  const software = params.get('render') === 'software' || readPreference() || !graphicsAvailable();
  let recoveryShown = false;
  function showRecovery({ fatal = false } = {}) {
    const diagnostic = { ...graphics, software, fatal, time: new Date().toISOString() };
    window.alocmapGraphicsDiagnostics.push(diagnostic);
    if (window.alocmapGraphicsDiagnostics.length > 10) window.alocmapGraphicsDiagnostics.shift();
    console.warn('[AlocMap] Diagnóstico gráfico:', diagnostic);
    if (recoveryShown) return;
    recoveryShown = true;
    // HTML independente do canvas: continua visível se a GPU deixar de desenhar.
    const panel = document.createElement('section');
    panel.id = 'graphics-recovery';
    panel.setAttribute('role', fatal ? 'alertdialog' : 'alert');
    if (fatal) panel.setAttribute('aria-modal', 'true');
    panel.setAttribute('aria-labelledby', 'graphics-recovery-title');
    panel.style.cssText = fatal
      ? 'position:fixed;inset:0;z-index:2147483647;display:grid;place-items:center;background:#142e36dd;font:16px system-ui;color:#203540;padding:24px'
      : 'position:fixed;bottom:16px;right:16px;left:16px;z-index:2147483647;font:14px system-ui;color:#203540;pointer-events:none';
    const card = document.createElement('div');
    card.style.cssText = 'background:white;border:1px solid #dbe5e8;border-radius:12px;padding:20px;max-width:440px;margin-left:auto;box-shadow:0 8px 32px #0003;pointer-events:auto';
    const title = document.createElement('h2');
    title.id = 'graphics-recovery-title';
    title.textContent = fatal ? 'Não foi possível desenhar o ecrã' : 'Foi detetada uma falha gráfica';
    const message = document.createElement('p');
    message.textContent = !fatal
      ? 'Se o ecrã já recuperou, pode fechar este aviso e continuar. Se o problema persistir, pode reabrir em modo compatível.'
      : software
      ? 'O modo compatível também encontrou um problema. Pode tentar reabrir a aplicação.'
      : 'O navegador encontrou uma falha gráfica. Pode reabrir a aplicação em modo compatível.';
    const notice = document.createElement('p');
    notice.textContent = 'A aplicação só será reiniciada quando clicar no botão. Alterações por guardar podem perder-se.';
    const button = document.createElement('button');
    button.textContent = software ? 'Reabrir aplicação' : 'Continuar em modo compatível';
    button.style.cssText = 'background:#177e72;color:white;border:0;border-radius:8px;padding:12px 18px;font:inherit;cursor:pointer';
    button.onclick = () => {
      try { sessionStorage.setItem(storageKey, '1'); } catch (_) { /* URL é a alternativa. */ }
      const url = new URL(window.location.href);
      url.searchParams.set('render', 'software');
      window.location.replace(url.toString());
    };
    card.append(title, message, notice, button);
    if (!fatal) {
      const close = document.createElement('button');
      close.textContent = 'Fechar aviso';
      close.style.cssText = 'border:0;background:transparent;color:#177e72;padding:12px;font:inherit;cursor:pointer';
      close.onclick = () => panel.remove();
      card.append(close);
    }
    panel.append(card);
    document.body.append(panel);
    if (fatal) button.focus();
  }

  // CanvasKit regista estas falhas na consola, sem lançar uma exceção Dart.
  // Não reiniciar automaticamente: podem existir alterações por guardar.
  for (const level of ['error', 'warn', 'log']) {
    const original = console[level].bind(console);
    console[level] = (...args) => {
      original(...args);
      if (args.some((arg) => typeof arg === 'string' && /Shader compilation error|Failed to compile.*shader/i.test(arg))) {
        showRecovery();
      }
    };
  }

  _flutter.loader.load({
    config: { renderer: 'canvaskit', canvasKitForceCpuOnly: software },
    onEntrypointLoaded: async (engineInitializer) => {
      try {
        const appRunner = await engineInitializer.initializeEngine({
          renderer: 'canvaskit', canvasKitForceCpuOnly: software,
        });
        await appRunner.runApp();
      } catch (error) {
        console.error('Não foi possível iniciar o motor gráfico:', error);
        showRecovery({ fatal: true });
      }
    },
  });
})();
