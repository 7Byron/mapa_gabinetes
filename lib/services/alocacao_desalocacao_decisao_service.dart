import 'package:flutter/foundation.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';

class DesalocacaoDecisao {
  final bool desalocarDireto;
  final String? mensagemDialogo;
  final String tipoDisponibilidade;
  final bool eTipoSerie;
  final bool podeSerSerie;

  const DesalocacaoDecisao({
    required this.desalocarDireto,
    required this.mensagemDialogo,
    required this.tipoDisponibilidade,
    required this.eTipoSerie,
    required this.podeSerSerie,
  });
}

class AlocacaoDesalocacaoDecisaoService {
  static DesalocacaoDecisao decidir({
    required String medicoId,
    required DateTime dataAlvo,
    required List<Disponibilidade> disponibilidades,
    required List<Alocacao> alocacoes,
  }) {
    final dataAlvoNormalizada =
        DateTime(dataAlvo.year, dataAlvo.month, dataAlvo.day);

    var disponibilidade = disponibilidades
            .where(
              (d) =>
                  d.medicoId == medicoId &&
                  d.data.year == dataAlvo.year &&
                  d.data.month == dataAlvo.month &&
                  d.data.day == dataAlvo.day,
            )
            .isNotEmpty
        ? disponibilidades
            .where(
              (d) =>
                  d.medicoId == medicoId &&
                  d.data.year == dataAlvo.year &&
                  d.data.month == dataAlvo.month &&
                  d.data.day == dataAlvo.day,
            )
            .first
        : null;

    final alocacoesLocaisDoMedico = alocacoes.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId && aDate == dataAlvoNormalizada;
    }).toList();

    bool podeSerSerieLocal = false;
    if (alocacoesLocaisDoMedico.length == 1) {
      final outrasAlocacoes = alocacoes.where((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.medicoId == medicoId && aDate != dataAlvoNormalizada;
      }).toList();

      final temDisponibilidadeSerie = disponibilidades.any((d) =>
          d.medicoId == medicoId &&
          (d.tipo == 'Semanal' ||
              d.tipo == 'Quinzenal' ||
              d.tipo == 'Mensal' ||
              d.tipo.startsWith('Consecutivo')));

      podeSerSerieLocal = outrasAlocacoes.isNotEmpty || temDisponibilidadeSerie;
    }

    List<Alocacao> alocacoesMedicoFirebase = [];
    if (alocacoesLocaisDoMedico.length == 1 && !podeSerSerieLocal) {
      debugPrint(
          '⚡ Pulando busca no Firebase - alocação única detectada (otimização)');
      alocacoesMedicoFirebase = alocacoesLocaisDoMedico;
    } else {
      final alocacoesLocaisDoMedicoTodas = alocacoes.where((a) {
        return a.medicoId == medicoId;
      }).toList();

      if (alocacoesLocaisDoMedicoTodas.length > 1 || podeSerSerieLocal) {
        debugPrint(
            '⚡ Usando lista local para verificação (${alocacoesLocaisDoMedicoTodas.length} alocações encontradas)');
        alocacoesMedicoFirebase = alocacoesLocaisDoMedicoTodas;
      } else {
        debugPrint(
            '⚡ Usando lista local para verificação (otimização - evitando busca no Firebase)');
        alocacoesMedicoFirebase = alocacoesLocaisDoMedicoTodas;
      }
    }

    final alocacoesFuturas = alocacoesMedicoFirebase.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      final aDateNormalizada = DateTime(aDate.year, aDate.month, aDate.day);
      return aDateNormalizada.isAfter(dataAlvoNormalizada);
    }).toList();

    final alocacoesPassadas = alocacoesMedicoFirebase.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      final aDateNormalizada = DateTime(aDate.year, aDate.month, aDate.day);
      return aDateNormalizada.isBefore(dataAlvoNormalizada);
    }).toList();

    final temAlocacoesFuturas = alocacoesFuturas.isNotEmpty;
    final temAlocacoesPassadas = alocacoesPassadas.isNotEmpty;
    final podeSerSerie = temAlocacoesFuturas || temAlocacoesPassadas;

    debugPrint('🔍 Verificando desalocação para médico $medicoId');
    debugPrint(
        '  📅 Data alvo: ${dataAlvo.day}/${dataAlvo.month}/${dataAlvo.year}');
    debugPrint(
        '  📊 Alocações futuras encontradas: ${alocacoesFuturas.length}');
    debugPrint(
        '  📊 Alocações passadas encontradas: ${alocacoesPassadas.length}');
    debugPrint('  🔄 Pode ser série: $podeSerSerie');
    if (alocacoesFuturas.isNotEmpty) {
      debugPrint('  📅 Próximas alocações:');
      for (var a in alocacoesFuturas.take(5)) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        debugPrint('    - ${aDate.day}/${aDate.month}/${aDate.year}');
      }
    }
    if (alocacoesPassadas.isNotEmpty) {
      debugPrint('  📅 Alocações passadas:');
      for (var a in alocacoesPassadas.take(5)) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        debugPrint('    - ${aDate.day}/${aDate.month}/${aDate.year}');
      }
    }

    String tipoSerie = 'Única';
    if (podeSerSerie) {
      debugPrint('  🔍 Pode ser série, buscando tipo correto da série...');
      final dispSerieList = disponibilidades
          .where((d) =>
              d.medicoId == medicoId &&
              (d.tipo == 'Semanal' ||
                  d.tipo == 'Quinzenal' ||
                  d.tipo == 'Mensal' ||
                  d.tipo.startsWith('Consecutivo')))
          .toList();

      if (dispSerieList.isNotEmpty) {
        tipoSerie = dispSerieList.first.tipo;
        debugPrint('  ✅ Tipo de série encontrado: $tipoSerie');
        if (disponibilidade == null) {
          disponibilidade = Disponibilidade(
            id: '',
            medicoId: '',
            data: DateTime(1900, 1, 1),
            horarios: [],
            tipo: tipoSerie,
          );
        } else if (disponibilidade.tipo == 'Única') {
          disponibilidade = Disponibilidade(
            id: disponibilidade.id,
            medicoId: disponibilidade.medicoId,
            data: disponibilidade.data,
            horarios: disponibilidade.horarios,
            tipo: tipoSerie,
          );
          debugPrint('  🔄 Tipo atualizado de "Única" para "$tipoSerie"');
        }
      } else {
        debugPrint(
            '  ⚠️ Nenhuma disponibilidade de série encontrada, tentando inferir do padrão das alocações...');
        if (alocacoesFuturas.isNotEmpty) {
          final primeiraFutura = alocacoesFuturas.first;
          final primeiraFuturaDate = DateTime(
            primeiraFutura.data.year,
            primeiraFutura.data.month,
            primeiraFutura.data.day,
          );
          final diasDiferenca =
              primeiraFuturaDate.difference(dataAlvoNormalizada).inDays;

          if (diasDiferenca == 7 || diasDiferenca % 7 == 0) {
            tipoSerie = 'Semanal';
            debugPrint(
                '  ✅ Tipo inferido: Semanal (diferença de $diasDiferenca dias)');
          } else if (diasDiferenca == 14 || diasDiferenca % 14 == 0) {
            tipoSerie = 'Quinzenal';
            debugPrint(
                '  ✅ Tipo inferido: Quinzenal (diferença de $diasDiferenca dias)');
          } else if (primeiraFuturaDate.day == dataAlvoNormalizada.day) {
            tipoSerie = 'Mensal';
            debugPrint('  ✅ Tipo inferido: Mensal (mesmo dia do mês)');
          }

          if (tipoSerie != 'Única') {
            disponibilidade = disponibilidade ??
                Disponibilidade(
                  id: '',
                  medicoId: '',
                  data: DateTime(1900, 1, 1),
                  horarios: [],
                  tipo: tipoSerie,
                );
            if (disponibilidade.tipo == 'Única') {
              disponibilidade = Disponibilidade(
                id: disponibilidade.id,
                medicoId: disponibilidade.medicoId,
                data: disponibilidade.data,
                horarios: disponibilidade.horarios,
                tipo: tipoSerie,
              );
              debugPrint(
                  '  🔄 Tipo atualizado de "Única" para "$tipoSerie" (inferido)');
            }
          }
        }
      }
    } else if (disponibilidade == null || disponibilidade.medicoId.isEmpty) {
      debugPrint('  ⚠️ Disponibilidade não encontrada no dia selecionado');
      disponibilidade = disponibilidade ??
          Disponibilidade(
            id: '',
            medicoId: '',
            data: DateTime(1900, 1, 1),
            horarios: [],
            tipo: 'Única',
          );
    } else {
      debugPrint(
          '  ✅ Disponibilidade encontrada no dia: tipo = ${disponibilidade.tipo}');
    }

    final disponibilidadeFinal = disponibilidade ??
        Disponibilidade(
          id: '',
          medicoId: '',
          data: DateTime(1900, 1, 1),
          horarios: [],
          tipo: podeSerSerie ? tipoSerie : 'Única',
        );

    final tipoDisponibilidade = disponibilidadeFinal.tipo;
    debugPrint('  📋 Tipo final da disponibilidade: $tipoDisponibilidade');
    debugPrint('  🔄 Tem alocações futuras: $temAlocacoesFuturas');

    final eTipoSerie = tipoDisponibilidade == 'Semanal' ||
        tipoDisponibilidade == 'Quinzenal' ||
        tipoDisponibilidade == 'Mensal' ||
        tipoDisponibilidade.startsWith('Consecutivo');

    debugPrint('  🔄 É tipo de série: $eTipoSerie');
    debugPrint(
        '  📊 Total de alocações do médico: ${alocacoes.where((a) => a.medicoId == medicoId).length}');
    debugPrint('  📊 Todas as alocações do médico:');
    for (var a in alocacoes.where((a) => a.medicoId == medicoId).take(10)) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      debugPrint(
          '    - ${aDate.day}/${aDate.month}/${aDate.year} (gabinete: ${a.gabineteId})');
    }

    if (!eTipoSerie && tipoDisponibilidade == 'Única' && !podeSerSerie) {
      debugPrint(
          '  ℹ️ Disponibilidade única sem alocações futuras/passadas - desalocando diretamente (sem diálogo)');
      return DesalocacaoDecisao(
        desalocarDireto: true,
        mensagemDialogo: null,
        tipoDisponibilidade: tipoDisponibilidade,
        eTipoSerie: eTipoSerie,
        podeSerSerie: podeSerSerie,
      );
    }

    debugPrint(
        '  ❓ Mostrando diálogo para escolher entre desalocar apenas o dia ou toda a série');
    final mensagem = (podeSerSerie && tipoDisponibilidade == 'Única')
        ? 'Este médico tem outras alocações em datas futuras ou passadas.\n'
            'Deseja desalocar apenas este dia (${dataAlvo.day}/${dataAlvo.month}) '
            'ou todos os dias da série?'
        : 'Esta disponibilidade é do tipo "$tipoDisponibilidade".\n'
            'Deseja desalocar apenas este dia (${dataAlvo.day}/${dataAlvo.month}) '
            'ou todos os dias da série a partir deste?';

    return DesalocacaoDecisao(
      desalocarDireto: false,
      mensagemDialogo: mensagem,
      tipoDisponibilidade: tipoDisponibilidade,
      eTipoSerie: eTipoSerie,
      podeSerSerie: podeSerSerie,
    );
  }
}
