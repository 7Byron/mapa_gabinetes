import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';
import '../models/gabinete.dart';
import '../models/unidade.dart';
import '../utils/alocacao_card_actions.dart';

/// Widget base para cartão de alocação
/// Pode ser usado tanto para cartões únicos quanto de série
class AlocacaoCard extends StatelessWidget {
  final Disponibilidade disponibilidade;
  final List<Alocacao>? alocacoes;
  final List<Gabinete>? gabinetes;
  final Unidade? unidade;
  final VoidCallback? onChanged;
  final VoidCallback onTap; // Abre diálogo de seleção de gabinete
  final VoidCallback onRemover; // Remove o cartão
  final VoidCallback onNavegarParaMapa; // Navega para o mapa
  final VoidCallback onSelecionarHorarioInicio; // Seleciona horário de início
  final VoidCallback onSelecionarHorarioFim; // Seleciona horário de fim

  const AlocacaoCard({
    super.key,
    required this.disponibilidade,
    this.alocacoes,
    this.gabinetes,
    this.unidade,
    this.onChanged,
    required this.onTap,
    required this.onRemover,
    required this.onNavegarParaMapa,
    required this.onSelecionarHorarioInicio,
    required this.onSelecionarHorarioFim,
  });

  @override
  Widget build(BuildContext context) {
    // Traduzir dia da semana para português
    final diaSemanaIngles = DateFormat('EEEE', 'en_US').format(disponibilidade.data);
    final diaSemana = AlocacaoCardActions.traduzirDiaSemana(diaSemanaIngles);

    final horarioInicio = disponibilidade.horarios.isNotEmpty
        ? disponibilidade.horarios[0]
        : 'Início';
    final horarioFim = disponibilidade.horarios.length == 2
        ? disponibilidade.horarios[1]
        : 'Fim';

    // Obter nome do gabinete se houver alocação
    String? nomeGabinete;
    try {
      if (alocacoes != null &&
          gabinetes != null &&
          alocacoes!.isNotEmpty &&
          gabinetes!.isNotEmpty) {
        nomeGabinete = AlocacaoCardActions.getNomeGabineteParaDisponibilidade(
          disponibilidade,
          alocacoes,
          gabinetes,
        );
      }
    } catch (e) {
      // Se houver qualquer erro, simplesmente não mostrar o gabinete
      nomeGabinete = null;
    }

    final corCartao = AlocacaoCardActions.determinarCorDoCartao(disponibilidade);

    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.all(8),
        color: corCartao,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${disponibilidade.data.day}/${disponibilidade.data.month}/${disponibilidade.data.year} ($diaSemana)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Ícone de deletar
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: onRemover,
                  ),
                ],
              ),
              Text(
                'Série: ${disponibilidade.tipo}',
                style: const TextStyle(fontSize: 9),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Divider entre Série e Gabinete
              const Divider(height: 2, thickness: 0.5),
              // Exibir número do gabinete se houver alocação (texto maior)
              if (nomeGabinete != null && nomeGabinete.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Gab: $nomeGabinete',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.map, color: Colors.blue, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        tooltip: 'Ver no mapa',
                        onPressed: onNavegarParaMapa,
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Sem gabinete',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.map, color: Colors.blue, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        tooltip: 'Ver no mapa',
                        onPressed: onNavegarParaMapa,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade100,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(55, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onSelecionarHorarioInicio,
                      child: Text(
                        horarioInicio,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade100,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(55, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onSelecionarHorarioFim,
                      child: Text(
                        horarioFim,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
