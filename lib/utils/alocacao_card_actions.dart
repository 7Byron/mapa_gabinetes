import 'package:flutter/material.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';
import '../models/gabinete.dart';
import '../models/unidade.dart';
import '../screens/alocacao_medicos_screen.dart';

/// Helper class para ações dos cartões de alocação
/// Centraliza toda a lógica de interação com os cartões
class AlocacaoCardActions {
  /// Determina cor do cartão baseado na validação dos horários
  static Color determinarCorDoCartao(Disponibilidade disponibilidade) {
    if (disponibilidade.horarios.isEmpty) {
      return Colors.orange.shade200; // Nenhum horário definido
    }
    if (disponibilidade.horarios.length == 1) {
      return Colors.orange.shade200; // Apenas um horário definido
    }

    try {
      final inicio = TimeOfDay(
        hour: int.parse(disponibilidade.horarios[0].split(':')[0]),
        minute: int.parse(disponibilidade.horarios[0].split(':')[1]),
      );
      final fim = TimeOfDay(
        hour: int.parse(disponibilidade.horarios[1].split(':')[0]),
        minute: int.parse(disponibilidade.horarios[1].split(':')[1]),
      );

      if (inicio.hour < fim.hour ||
          (inicio.hour == fim.hour && inicio.minute < fim.minute)) {
        return Colors.lightGreen.shade100; // Válido
      } else {
        return Colors.red.shade100; // Início depois do fim
      }
    } catch (e) {
      return Colors.red.shade300; // Erro de formatação
    }
  }

  /// Obtém o nome do gabinete para uma disponibilidade específica
  static String? getNomeGabineteParaDisponibilidade(
    Disponibilidade disponibilidade,
    List<Alocacao>? alocacoes,
    List<Gabinete>? gabinetes,
  ) {
    try {
      if (alocacoes == null || gabinetes == null) {
        return null;
      }

      if (alocacoes.isEmpty || gabinetes.isEmpty) {
        return null;
      }

      // Normalizar a data da disponibilidade
      final dataNormalizada = DateTime(
        disponibilidade.data.year,
        disponibilidade.data.month,
        disponibilidade.data.day,
      );

      // Buscar alocações do mesmo médico e mesma data
      final alocacoesDoDia = alocacoes.where((a) {
        try {
          final aDataNormalizada =
              DateTime(a.data.year, a.data.month, a.data.day);
          return a.medicoId == disponibilidade.medicoId &&
              aDataNormalizada == dataNormalizada;
        } catch (e) {
          return false;
        }
      }).toList();

      if (alocacoesDoDia.isEmpty) {
        return null;
      }

      // Tentar encontrar correspondência exata de horários primeiro (melhor match)
      Alocacao? alocacaoCorrespondente;
      if (disponibilidade.horarios.isNotEmpty &&
          disponibilidade.horarios.length >= 2) {
        try {
          final horarioInicioDisp = disponibilidade.horarios[0].trim();
          final horarioFimDisp = disponibilidade.horarios.length > 1
              ? disponibilidade.horarios[1].trim()
              : disponibilidade.horarios[0].trim();

          // Tentar encontrar correspondência exata
          alocacaoCorrespondente = alocacoesDoDia.firstWhere(
            (a) =>
                a.horarioInicio.trim() == horarioInicioDisp &&
                a.horarioFim.trim() == horarioFimDisp,
            orElse: () =>
                alocacoesDoDia.first, // FALLBACK: usar primeira se não encontrar match exato
          );
        } catch (e) {
          // Se houver erro, usar a primeira alocação
          if (alocacoesDoDia.isNotEmpty) {
            alocacaoCorrespondente = alocacoesDoDia.first;
          }
        }
      } else {
        // Se não há horários na disponibilidade, usar a primeira alocação
        if (alocacoesDoDia.isNotEmpty) {
          alocacaoCorrespondente = alocacoesDoDia.first;
        }
      }

      if (alocacaoCorrespondente == null) {
        return null;
      }

      // Buscar o nome do gabinete
      try {
        final gabineteId = alocacaoCorrespondente.gabineteId;
        final gabinete = gabinetes.firstWhere(
          (g) => g.id == gabineteId,
          orElse: () => Gabinete(
            id: gabineteId,
            setor: '',
            nome: gabineteId,
            especialidadesPermitidas: [],
          ),
        );

        return gabinete.nome;
      } catch (e) {
        return null;
      }
    } catch (e) {
      // Se houver qualquer erro, retornar null para não quebrar a UI
      return null;
    }
  }

  /// Obtém a alocação correspondente a uma disponibilidade
  static Alocacao? getAlocacaoParaDisponibilidade(
    Disponibilidade disponibilidade,
    List<Alocacao>? alocacoes,
  ) {
    try {
      if (alocacoes == null || alocacoes.isEmpty) {
        return null;
      }

      final dataNormalizada = DateTime(
        disponibilidade.data.year,
        disponibilidade.data.month,
        disponibilidade.data.day,
      );

      final alocacoesDoDia = alocacoes.where((a) {
        try {
          final aDataNormalizada =
              DateTime(a.data.year, a.data.month, a.data.day);
          return a.medicoId == disponibilidade.medicoId &&
              aDataNormalizada == dataNormalizada;
        } catch (e) {
          return false;
        }
      }).toList();

      if (alocacoesDoDia.isEmpty) {
        return null;
      }

      // Tentar encontrar correspondência exata de horários
      if (disponibilidade.horarios.isNotEmpty &&
          disponibilidade.horarios.length >= 2) {
        try {
          final horarioInicioDisp = disponibilidade.horarios[0].trim();
          final horarioFimDisp = disponibilidade.horarios.length > 1
              ? disponibilidade.horarios[1].trim()
              : disponibilidade.horarios[0].trim();

          final alocacaoCorrespondente = alocacoesDoDia.firstWhere(
            (a) =>
                a.horarioInicio.trim() == horarioInicioDisp &&
                a.horarioFim.trim() == horarioFimDisp,
            orElse: () => alocacoesDoDia.first,
          );
          return alocacaoCorrespondente;
        } catch (e) {
          return alocacoesDoDia.first;
        }
      } else {
        return alocacoesDoDia.first;
      }
    } catch (e) {
      return null;
    }
  }

  /// Navega para a tela de alocação no dia correspondente ao cartão
  static void navegarParaMapa(
    BuildContext context,
    DateTime data,
    Unidade? unidade, {
    VoidCallback? onVoltar,
  }) {
    if (unidade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unidade não definida')),
      );
      return;
    }

    // Normalizar a data para garantir que está no início do dia (sem horas/minutos/segundos)
    final dataNormalizada = DateTime(data.year, data.month, data.day);

    // Navegar para a tela de alocação com a data do cartão
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlocacaoMedicos(
          unidade: unidade,
          isAdmin: true, // Assumindo que se está editando, é admin
          dataInicial: dataNormalizada, // Passar a data do cartão
        ),
      ),
    ).then((_) {
      // Quando volta da tela de alocação, recarregar os dados
      onVoltar?.call();
    }).catchError((error) {
      debugPrint('Erro ao navegar para mapa: $error');
    });
  }

  /// Traduz dia da semana de inglês para português
  static String traduzirDiaSemana(String diaIngles) {
    const traducoes = {
      'Monday': '2ª feira',
      'Tuesday': '3ª feira',
      'Wednesday': '4ª feira',
      'Thursday': '5ª feira',
      'Friday': '6ª feira',
      'Saturday': 'Sábado',
      'Sunday': 'Domingo',
    };
    return traducoes[diaIngles] ?? diaIngles;
  }
}
