import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
import '../utils/series_helper.dart';
import '../utils/app_theme.dart';
import 'dialogo_excecao_periodo.dart';
import 'dialogo_excecao_serie.dart';

/// Widget que exibe o cartão de Exceções
/// Pode ser usado tanto na versão desktop quanto mobile
class ExcecoesCard extends StatelessWidget {
  final List<SerieRecorrencia> series;
  final List<ExcecaoSerie> excecoes;
  final Future<void> Function(DateTime dataInicio, DateTime dataFim)
      onCriarExcecaoPeriodoGeral;
  final Future<void> Function(
      SerieRecorrencia serie, DateTime dataInicio, DateTime dataFim)
      onCriarExcecaoPeriodo;
  final Future<void> Function(SerieRecorrencia serie, DateTime dataFim)?
      onCancelarSerie; // Novo: para cancelar série a partir de data
  final Future<void> Function(List<ExcecaoSerie> excecoesParaRemover)
      onRemoverExcecoesEmLote;
  final Future<void> Function(ExcecaoSerie excecao)? onRemoverExcecao;
  final bool isMobile;

  const ExcecoesCard({
    super.key,
    required this.series,
    required this.excecoes,
    required this.onCriarExcecaoPeriodoGeral,
    required this.onCriarExcecaoPeriodo,
    this.onCancelarSerie,
    required this.onRemoverExcecoesEmLote,
    this.onRemoverExcecao,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    // Se não há séries, não mostrar o cartão
    if (series.isEmpty) {
      return const SizedBox.shrink();
    }

    if (isMobile) {
      return _buildMobileCard(context);
    } else {
      return _buildDesktopCard(context);
    }
  }

  /// Constrói o cartão para desktop
  Widget _buildDesktopCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.none,
      decoration: BoxDecoration(
        color: MyAppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: MyAppTheme.shadowCard3D,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Exceções',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.block, color: Colors.white, size: 16),
                  label: const Text('Criar Exceção',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                  ),
                  onPressed: () => _mostrarDialogoCriarExcecao(context),
                ),
              ],
            ),
            if (excecoes.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._buildListaExcecoes(context, usarLote: true),
            ],
          ],
        ),
      ),
    );
  }

  /// Constrói o cartão para mobile
  Widget _buildMobileCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Exceções',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.block,
                      color: Colors.white, size: 16),
                  label: const Text('Criar Exceção',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                  ),
                  onPressed: () => _mostrarDialogoCriarExcecaoMobile(context),
                ),
              ],
            ),
            if (excecoes.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._buildListaExcecoes(context, usarLote: false),
            ],
          ],
        ),
      ),
    );
  }

  /// Mostra o diálogo para criar exceção (versão desktop)
  Future<void> _mostrarDialogoCriarExcecao(BuildContext context) async {
    // Mostrar diálogo para escolher tipo de exceção
    final tipoExcecao = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tipo de Exceção'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.orange),
              title: const Text('Exceção de Período'),
              subtitle: const Text(
                  'Remove todos os cartões no período selecionado (ex: congresso, férias)'),
              onTap: () => Navigator.pop(context, 'periodo'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.repeat, color: Colors.blue),
              title: const Text('Exceção de Série'),
              subtitle: const Text('Remove cartões de uma série específica'),
              onTap: () => Navigator.pop(context, 'serie'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;

    if (tipoExcecao == 'periodo') {
      // Criar exceção de período geral
      await showDialog(
        context: context,
        builder: (context) => DialogoExcecaoPeriodo(
          dataInicialMinima: null,
          dataFinalMaxima: null,
          onConfirmar: (dataInicio, dataFim) {
            onCriarExcecaoPeriodoGeral(dataInicio, dataFim);
          },
        ),
      );
    } else if (tipoExcecao == 'serie') {
      // Criar exceção para uma série específica
      if (series.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não há séries cadastradas'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (series.length == 1) {
        if (!context.mounted) return;
        await showDialog(
          context: context,
          builder: (context) => DialogoExcecaoSerie(
            serie: series.first,
            onConfirmar: (dataInicio, dataFim) {
              onCriarExcecaoPeriodo(series.first, dataInicio, dataFim);
            },
            onCancelarSerie: onCancelarSerie != null
                ? (dataFim) {
                    onCancelarSerie!(series.first, dataFim);
                  }
                : null,
          ),
        );
      } else {
        // Se houver múltiplas séries, mostrar diálogo para escolher
        if (!context.mounted) return;
        final serieEscolhida = await showDialog<SerieRecorrencia>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Selecionar Série'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: series.length,
                itemBuilder: (context, index) {
                  final serie = series[index];
                  String descricaoDia = '';
                  if (serie.tipo == 'Semanal' || serie.tipo == 'Quinzenal') {
                    final diasSemana = [
                      'Segunda',
                      'Terça',
                      'Quarta',
                      'Quinta',
                      'Sexta',
                      'Sábado',
                      'Domingo'
                    ];
                    descricaoDia =
                        ' (${diasSemana[serie.dataInicio.weekday - 1]})';
                  } else if (serie.tipo == 'Mensal') {
                    final diasSemana = [
                      'Segunda',
                      'Terça',
                      'Quarta',
                      'Quinta',
                      'Sexta',
                      'Sábado',
                      'Domingo'
                    ];
                    descricaoDia =
                        ' (${diasSemana[serie.dataInicio.weekday - 1]})';
                  }
                  return ListTile(
                    title: Text('${serie.tipo}$descricaoDia'),
                    subtitle: Text(
                        'Desde ${DateFormat('dd/MM/yyyy').format(serie.dataInicio)}'),
                    onTap: () => Navigator.pop(context, serie),
                  );
                },
              ),
            ),
          ),
        );
        if (serieEscolhida != null && context.mounted) {
          await showDialog(
            context: context,
            builder: (context) => DialogoExcecaoSerie(
              serie: serieEscolhida,
              onConfirmar: (dataInicio, dataFim) {
                onCriarExcecaoPeriodo(serieEscolhida, dataInicio, dataFim);
              },
              onCancelarSerie: onCancelarSerie != null
                  ? (dataFim) {
                      onCancelarSerie!(serieEscolhida, dataFim);
                    }
                  : null,
            ),
          );
        }
      }
    }
  }

  /// Mostra o diálogo para criar exceção (versão mobile)
  Future<void> _mostrarDialogoCriarExcecaoMobile(BuildContext context) async {
    // Se houver apenas uma série, abrir diretamente
    if (series.length == 1) {
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (context) => DialogoExcecaoSerie(
          serie: series.first,
          onConfirmar: (dataInicio, dataFim) {
            onCriarExcecaoPeriodo(series.first, dataInicio, dataFim);
          },
          onCancelarSerie: onCancelarSerie != null
              ? (dataFim) {
                  onCancelarSerie!(series.first, dataFim);
                }
              : null,
        ),
      );
    } else {
      // Se houver múltiplas séries, mostrar diálogo para escolher
      if (!context.mounted) return;
      final serieEscolhida = await showDialog<SerieRecorrencia>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Selecionar Série'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: series.length,
              itemBuilder: (context, index) {
                final serie = series[index];
                String descricaoDia = '';
                if (serie.tipo == 'Semanal' || serie.tipo == 'Quinzenal') {
                  final diasSemana = [
                    'Segunda',
                    'Terça',
                    'Quarta',
                    'Quinta',
                    'Sexta',
                    'Sábado',
                    'Domingo'
                  ];
                  descricaoDia =
                      ' (${diasSemana[serie.dataInicio.weekday - 1]})';
                } else if (serie.tipo == 'Mensal') {
                  final diasSemana = [
                    'Segunda',
                    'Terça',
                    'Quarta',
                    'Quinta',
                    'Sexta',
                    'Sábado',
                    'Domingo'
                  ];
                  descricaoDia =
                      ' (${diasSemana[serie.dataInicio.weekday - 1]})';
                }
                return ListTile(
                  title: Text('${serie.tipo}$descricaoDia'),
                  subtitle: Text(
                      'Desde ${DateFormat('dd/MM/yyyy').format(serie.dataInicio)}'),
                  onTap: () => Navigator.pop(context, serie),
                );
              },
            ),
          ),
        ),
      );
      if (serieEscolhida != null && context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => DialogoExcecaoSerie(
            serie: serieEscolhida,
            onConfirmar: (dataInicio, dataFim) {
              onCriarExcecaoPeriodo(serieEscolhida, dataInicio, dataFim);
            },
            onCancelarSerie: onCancelarSerie != null
                ? (dataFim) {
                    onCancelarSerie!(serieEscolhida, dataFim);
                  }
                : null,
          ),
        );
      }
    }
  }

  /// Constrói a lista de exceções agrupadas
  List<Widget> _buildListaExcecoes(BuildContext context,
      {required bool usarLote}) {
    final grupos = SeriesHelper.agruparExcecoesPorPeriodo(excecoes, series);
    return grupos.map((grupo) {
      final excecoesGrupo =
          grupo['excecoes'] as List<ExcecaoSerie>;
      final serie = grupo['serie'] as SerieRecorrencia;
      final dataInicio = grupo['dataInicio'] as DateTime;
      final dataFim = grupo['dataFim'] as DateTime;
      final isPeriodo = grupo['isPeriodo'] as bool;

      String textoData;
      if (isPeriodo) {
        textoData =
            '${DateFormat('dd/MM/yyyy').format(dataInicio)} - ${DateFormat('dd/MM/yyyy').format(dataFim)}';
      } else {
        textoData = DateFormat('dd/MM/yyyy').format(dataInicio);
      }

      return ListTile(
        dense: true,
        title: Text(
          '$textoData - ${serie.tipo}',
          style: const TextStyle(fontSize: 12),
        ),
        subtitle: Text(
          excecoesGrupo.first.cancelada ? 'Cancelada' : 'Modificada',
          style: TextStyle(
            fontSize: 11,
            color: excecoesGrupo.first.cancelada
                ? Colors.red
                : Colors.orange,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, size: 18),
          color: Colors.red,
          onPressed: () async {
            if (usarLote) {
              await onRemoverExcecoesEmLote(excecoesGrupo);
            } else if (onRemoverExcecao != null) {
              // Versão mobile: remover uma por uma
              for (final excecao in excecoesGrupo) {
                await onRemoverExcecao!(excecao);
              }
            }
          },
        ),
      );
    }).toList();
  }
}
