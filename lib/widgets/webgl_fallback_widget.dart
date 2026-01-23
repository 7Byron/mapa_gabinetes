// ignore_for_file: deprecated_member_use
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../utils/web_gl_support.dart';
import '../utils/network_utils.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// Função para verificar se há problemas de rede
bool _hasNetworkIssues() {
  if (!kIsWeb) return false;
  return NetworkUtils.hasNetworkIssues;
}

class WebGLFallbackWidget extends StatelessWidget {
  const WebGLFallbackWidget({
    super.key,
    required this.buildNormalWidget,
    this.fallbackWidget,
    this.showWebGLWarning = true,
  });

  final Widget Function() buildNormalWidget;
  final Widget? fallbackWidget;
  final bool showWebGLWarning;

  @override
  Widget build(BuildContext context) {
    final canUseWebGL = !kIsWeb || hasWebGL();
    final hasNetworkProblems = _hasNetworkIssues();

    // Se WebGL está disponível e não há problemas de rede, usar widget normal
    if (canUseWebGL && !hasNetworkProblems) {
      return buildNormalWidget();
    }

    // Fallback para quando WebGL não está disponível ou há problemas de rede
    return fallbackWidget ??
        _DefaultFallbackWidget(
          showWarning: showWebGLWarning,
          hasNetworkIssues: hasNetworkProblems,
        );
  }
}

class _DefaultFallbackWidget extends StatelessWidget {
  const _DefaultFallbackWidget({
    this.showWarning = true,
    this.hasNetworkIssues = false,
  });

  final bool showWarning;
  final bool hasNetworkIssues;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showWarning) ...[
                  Icon(
                    hasNetworkIssues
                        ? Icons.wifi_off
                        : Icons.warning_amber_rounded,
                    color: hasNetworkIssues
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    hasNetworkIssues
                        ? 'Problemas de Rede'
                        : 'Compatibilidade Limitada',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: hasNetworkIssues
                              ? Colors.red.shade700
                              : Colors.orange.shade700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hasNetworkIssues
                        ? 'A aplicação está a funcionar em modo offline devido a restrições de rede corporativa. Alguns dados podem não estar atualizados.'
                        : 'Este navegador tem funcionalidades limitadas devido a restrições de segurança corporativa.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                ],
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Modo de Compatibilidade Ativo',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A aplicação está a funcionar com funcionalidades básicas.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.blue.shade600,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Tentar recarregar a aplicação
                    if (kIsWeb) {
                      // Recarregar a página
                      html.window.location.reload();
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar Novamente'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget para proteger contra crashes de inicialização
Widget safeWidget(Widget Function() build) {
  try {
    return build();
  } catch (e) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 32),
          const SizedBox(height: 8),
          Text(
            'Erro ao carregar componente',
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tente recarregar a página',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
