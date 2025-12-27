import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math' as math;
import '../a_config_app/lista_testes.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/margem_helper.dart';
import '../funcoes/variaveis_globais.dart';
import '../paginas_testes/test_info.dart';
import '../outras_paginas/intro.dart';
import '../funcoes/spacing.dart';
import '../funcoes/theme_tokens.dart';

class ListaTesteUnificada extends StatefulWidget {
  final bool isIntroMode;
  final bool isDrawerMode;
  final bool isResultMode;
  final void Function(String)? onTestSelected;

  const ListaTesteUnificada({
    super.key,
    this.isIntroMode = false,
    this.isDrawerMode = false,
    this.isResultMode = false,
    this.onTestSelected,
  });

  @override
  State<ListaTesteUnificada> createState() => _ListaTesteUnificadaState();
}

class _ListaTesteUnificadaState extends State<ListaTesteUnificada> {
  // Controle para evitar cliques múltiplos
  bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
    // Usa GetBuilder para reagir às mudanças nas variáveis globais
    return GetBuilder<MyG>(
      builder: (myG) {
        final bool temTodosOsTestes = myG.allApps;

        if (temTodosOsTestes) {
          return _buildGridSimples();
        } else {
          return _buildGridMisto();
        }
      },
    );
  }

  // Navegação otimizada: previne cliques múltiplos
  Future<void> _navegarParaTeste(String tipoTeste) async {
    // Previne navegação múltipla
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      // Feedback visual imediato
      if (mounted) setState(() {});

      // Pequeno delay para garantir que o estado visual seja atualizado
      await Future.delayed(const Duration(milliseconds: 100));

      if (widget.onTestSelected != null) {
        // Usa callback interno (quando chamado da página intro)
        widget.onTestSelected!(tipoTeste);
      } else {
        // Navega externamente (quando chamado de outras páginas)
        final testInfo = getTestInfo(tipoTeste);
        if (testInfo["rota"]!.isEmpty) return;

        final args = ['testPrep', tipoTeste];

        // Se estamos no drawer MODAL (telas estreitas), fechar primeiro
        // Em telas largas (>=1024) o drawer fica fixo na lateral e não deve dar pop
        if (widget.isDrawerMode && Get.width < 1024) {
          Get.back();
          await Future.delayed(const Duration(milliseconds: 300));
        }

        // Forçar reconstrução da página intro
        Get.offAll(() => const Intro(), arguments: args);
      }
    } catch (e) {
      // Fallback: tentar navegação direta se houver erro
      try {
        final testInfo = getTestInfo(tipoTeste);
        if (testInfo["rota"]!.isNotEmpty) {
          await Get.toNamed(testInfo["rota"]!);
        }
      } catch (fallbackError) {
        // Ignora erros de navegação fallback
        // Se ambas as tentativas falharem, o usuário pode tentar novamente
      }
    } finally {
      // Sempre reabilita navegação após processo
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }

  Widget _buildGridSimples() {
    final testes = ListaTeste.gridItems;
    // Espaçamento uniforme igual à lista principal
    final mainAxisSpacing = 12.0;
    final crossAxisSpacing = 12.0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: widget.isDrawerMode ? 0.75 : 0.8,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: testes.length,
      itemBuilder: (context, index) {
        final teste = testes[index];
        return _buildTestCard(
          title: teste.title.tr,
          image: teste.imageAsset,
          isActive: true,
          isMainTest: teste.destaque &&
              !MyG.to
                  .allApps, // Teste destacado apenas quando não tem todos os testes
          onTap: () => _navegarParaTeste(teste.tipoTeste),
        );
      },
    );
  }

  Widget _buildGridMisto() {
    final testes = ListaTeste.gridItems;
    // Buscar todos os testes que têm destaque (ativos)
    final testesAtivos = testes.where((teste) => teste.destaque).toList();
    // Buscar todos os testes que não têm destaque (inativos)
    final testesInativos = testes.where((teste) => !teste.destaque).toList();

    // Espaçamento uniforme igual à lista principal
    final mainAxisSpacing = 12.0;
    final crossAxisSpacing = 12.0;

    // Organizar todos os testes em ordem: ativos primeiro, depois os inativos
    final testesOrdenados = [...testesAtivos, ...testesInativos];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: widget.isDrawerMode ? 0.75 : 0.8,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: testesOrdenados.length,
      itemBuilder: (context, index) {
        final teste = testesOrdenados[index];
        final isActive = teste.destaque; // Usar a configuração destaque
        // Verificar se é o teste principal (destacado quando não tem todos os testes)
        final isMainTest = teste.destaque && !MyG.to.allApps;

        return _buildTestCard(
          title: teste.title.tr,
          image: teste.imageAsset,
          isActive: isActive,
          isMainTest: isMainTest,
          onTap: isActive
              ? () => _navegarParaTeste(teste.tipoTeste)
              : () => Get.toNamed(RotasPaginas.pay),
        );
      },
    );
  }

  Widget _buildTestCard({
    required String title,
    required String image,
    required bool isActive,
    required bool isMainTest,
    required VoidCallback onTap,
  }) {
    double fontSize;
    if (widget.isDrawerMode) {
      fontSize = 10;
    } else if (Get.context!.isPhone) {
      fontSize = 12;
    } else {
      fontSize = 14;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isNavigating ? null : onTap,
        borderRadius: BorderRadius.circular(ThemeTokens.radiusMedium),
        child: Container(
          decoration: BoxDecoration(
            gradient: isMainTest ? ThemeTokens.gradMain : null,
            color: isMainTest
                ? null // Usar gradiente para teste principal
                : (isActive ? Colors.amber.shade200 : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(ThemeTokens.radiusMedium),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: 0.25), // Mais opaco para efeito 3D
                blurRadius: 8, // Mais difuso
                offset: const Offset(
                    0, 4), // Mais deslocado para efeito de elevação
              ),
            ],
          ),
          clipBehavior:
              Clip.antiAlias, // Garante que a sombra siga o borderRadius
          child: Padding(
            padding: EdgeInsets.all(Margem.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(ThemeTokens.radiusSmall),
                      color: isMainTest
                          ? Colors.white.withValues(alpha: 0.9)
                          : null,
                    ),
                    padding: isMainTest ? EdgeInsets.all(Spacing.xs) : null,
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(ThemeTokens.radiusSmall),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final int targetWidth = math.max(
                            1,
                            (constraints.maxWidth *
                                    MediaQuery.of(context).devicePixelRatio)
                                .round(),
                          );
                          if (isActive) {
                            return Image.asset(
                              image,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              cacheWidth: targetWidth,
                            );
                          } else {
                            return ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                Colors.grey.shade400,
                                BlendMode.saturation,
                              ),
                              child: Image.asset(
                                image,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                cacheWidth: targetWidth,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
                Spacing.vs,
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: Spacing.xs),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                          color: isMainTest
                              ? Colors.brown
                                  .shade800 // Teste principal com cor mais escura
                              : isActive
                                  ? Colors
                                      .brown.shade700 // Outros testes ativos
                                  : Colors.grey.shade600, // Testes inativos
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
