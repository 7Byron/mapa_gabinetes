// Função para criar anúncios AdSense
function createAdSenseAd(adUnitId, width, height, format) {
  const adContainer = document.createElement('div');
  adContainer.style.width = width + 'px';
  adContainer.style.height = height + 'px';
  adContainer.style.margin = '0 auto';
  adContainer.style.display = 'block';
  adContainer.style.overflow = 'hidden';
  adContainer.style.borderRadius = '8px';

  const insElement = document.createElement('ins');
  insElement.className = 'adsbygoogle';
  insElement.style.display = 'block';
  insElement.setAttribute('data-ad-client', 'ca-pub-5079087452062016');
  insElement.setAttribute('data-ad-slot', adUnitId);
  insElement.setAttribute('data-ad-format', format);
  insElement.setAttribute('data-full-width-responsive', 'true');

  adContainer.appendChild(insElement);
  
  // Carregar o anúncio
  (adsbygoogle = window.adsbygoogle || []).push({});
  
  return adContainer;
}

// Função para criar anúncio responsivo
function createResponsiveAd(adUnitId) {
  return createAdSenseAd(adUnitId, 'auto', 'auto', 'auto');
}

// Função para criar banner horizontal (728x90)
function createBannerAd(adUnitId) {
  return createAdSenseAd(adUnitId, 728, 90, 'auto');
}

// Função para criar anúncio lateral (300x250)
function createSidebarAd(adUnitId) {
  return createAdSenseAd(adUnitId, 300, 250, 'auto');
}

// Função para criar anúncio responsivo baseado na largura da tela
function createAdaptiveAd(adUnitId) {
  const screenWidth = window.innerWidth;
  let width, height;
  
  if (screenWidth >= 728) {
    width = 728;
    height = 90;
  } else if (screenWidth >= 468) {
    width = 468;
    height = 60;
  } else {
    width = 320;
    height = 50;
  }
  
  return createAdSenseAd(adUnitId, width, height, 'auto');
}

// Função para verificar se o AdSense está carregado
function isAdSenseLoaded() {
  return typeof adsbygoogle !== 'undefined';
}

// Função para aguardar o carregamento do AdSense
function waitForAdSense(callback) {
  if (isAdSenseLoaded()) {
    callback();
  } else {
    setTimeout(() => waitForAdSense(callback), 100);
  }
}

// Função para criar anúncio com fallback
function createAdWithFallback(adUnitId, width, height, format) {
  const adContainer = document.createElement('div');
  adContainer.style.width = width + 'px';
  adContainer.style.height = height + 'px';
  adContainer.style.margin = '0 auto';
  adContainer.style.display = 'block';
  adContainer.style.borderRadius = '8px';
  adContainer.style.overflow = 'hidden';

  // Adicionar fallback visual
  const fallback = document.createElement('div');
  fallback.style.width = '100%';
  fallback.style.height = '100%';
  fallback.style.backgroundColor = '#f0f8ff';
  fallback.style.border = '1px solid #b0d4f1';
  fallback.style.display = 'flex';
  fallback.style.alignItems = 'center';
  fallback.style.justifyContent = 'center';
  fallback.style.fontFamily = 'Arial, sans-serif';
  fallback.style.fontSize = '12px';
  fallback.style.color = '#0066cc';
  fallback.textContent = 'Carregando anúncio...';

  adContainer.appendChild(fallback);

  // Tentar carregar o anúncio
  waitForAdSense(() => {
    try {
      const insElement = document.createElement('ins');
      insElement.className = 'adsbygoogle';
      insElement.style.display = 'block';
      insElement.setAttribute('data-ad-client', 'ca-pub-5079087452062016');
      insElement.setAttribute('data-ad-slot', adUnitId);
      insElement.setAttribute('data-ad-format', format);
      insElement.setAttribute('data-full-width-responsive', 'true');

      // Limpar fallback e adicionar anúncio
      adContainer.innerHTML = '';
      adContainer.appendChild(insElement);
      
      (adsbygoogle = window.adsbygoogle || []).push({});
    } catch (error) {
      console.log('Erro ao carregar anúncio:', error);
      // Manter o fallback se houver erro
    }
  });

  return adContainer;
} 