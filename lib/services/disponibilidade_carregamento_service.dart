import '../models/disponibilidade.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
import '../models/unidade.dart';
import '../services/serie_service.dart';
import '../services/disponibilidade_unica_service.dart';
import '../services/serie_generator.dart';
import '../utils/cadastro_medicos_helper.dart';

/// Serviço para carregar disponibilidades do Firestore
/// Extracted from cadastro_medicos.dart to reduce code size
class DisponibilidadeCarregamentoService {
  /// Carrega todas as disponibilidades para um médico e ano específicos
  /// Retorna um mapa com:
  /// - 'disponibilidades': `List<Disponibilidade>`
  /// - 'series': `List<SerieRecorrencia>`
  /// - 'excecoes': `List<ExcecaoSerie>`
  static Future<Map<String, dynamic>> carregarDisponibilidadesCompletas(
    String medicoId,
    int anoParaCarregar,
    Unidade? unidade,
    List<SerieRecorrencia> seriesExistentes,
    List<ExcecaoSerie> excecoesExistentes,
    List<Disponibilidade> disponibilidadesExistentes,
    bool seriesJaCarregadas,
  ) async {
    final dataInicio = DateTime(anoParaCarregar, 1, 1);
    final dataFim = DateTime(anoParaCarregar + 1, 1, 1);

    List<SerieRecorrencia> seriesCarregadas;
    List<ExcecaoSerie> excecoesCarregadas = [];
    List<Disponibilidade> disponibilidades = [];

    // Carregar séries se necessário
    if (!seriesJaCarregadas) {
      seriesCarregadas = await SerieService.carregarSeries(
        medicoId,
        unidade: unidade,
      );
    } else {
      seriesCarregadas = seriesExistentes;
    }

    // Atualizar lista de séries se necessário (será feito no estado)

    if (seriesCarregadas.isNotEmpty) {
      // Carregar exceções se necessário
      final excecoesJaCarregadas = excecoesExistentes.isNotEmpty &&
          excecoesExistentes.any((e) => e.data.year == anoParaCarregar);

      if (!excecoesJaCarregadas) {
        excecoesCarregadas = await SerieService.carregarExcecoes(
          medicoId,
          unidade: unidade,
          dataInicio: dataInicio,
          dataFim: dataFim,
        );
      } else {
        excecoesCarregadas = excecoesExistentes
            .where((e) => e.data.year == anoParaCarregar)
            .toList();
      }

      // Criar cópia para não modificar a lista original
      final disponibilidadesExistentesCopia =
          List<Disponibilidade>.from(disponibilidadesExistentes);

      // Remover disponibilidades do ano atual (apenas séries)
      disponibilidadesExistentesCopia.removeWhere((d) =>
          d.id.startsWith('serie_') &&
          d.medicoId == medicoId &&
          d.data.year == anoParaCarregar);

      // Carregar disponibilidades únicas do Firestore
      final dispsUnicas =
          await DisponibilidadeUnicaService.carregarDisponibilidadesUnicas(
        medicoId,
        anoParaCarregar,
        unidade,
      );

      // Gerar disponibilidades a partir das séries
      final dispsGeradas = SerieGenerator.gerarDisponibilidades(
        series: seriesCarregadas,
        excecoes: excecoesCarregadas,
        dataInicio: dataInicio,
        dataFim: dataFim,
      );

      // Organizar disponibilidades em um mapa
      final disponibilidadesUnicas = <String, Disponibilidade>{};

      // Adicionar disponibilidades existentes de outros anos
      for (final disp in disponibilidadesExistentes) {
        final chave = CadastroMedicosHelper.gerarChaveDisponibilidade(disp);
        disponibilidadesUnicas[chave] = disp;
      }

      // Adicionar disponibilidades geradas de séries
      for (final dispGerada in dispsGeradas) {
        final chave =
            CadastroMedicosHelper.gerarChaveDisponibilidade(dispGerada);
        disponibilidadesUnicas[chave] = dispGerada;
      }

      // Adicionar disponibilidades únicas do Firestore (sem sobrescrever locais)
      for (final dispUnica in dispsUnicas) {
        final chave =
            CadastroMedicosHelper.gerarChaveDisponibilidade(dispUnica);
        if (!disponibilidadesUnicas.containsKey(chave)) {
          disponibilidadesUnicas[chave] = dispUnica;
        }
      }

      // Converter para lista e ordenar
      final listaOrdenada = disponibilidadesUnicas.values.toList();
      listaOrdenada.sort((a, b) => a.data.compareTo(b.data));

      // Mesclar com disponibilidades existentes
      final disponibilidadesFinais =
          CadastroMedicosHelper.mesclarDisponibilidadesComAno(
        disponibilidadesExistentesCopia,
        listaOrdenada,
        medicoId,
        anoParaCarregar,
      );

      disponibilidades = disponibilidadesFinais.values.toList();
      disponibilidades.sort((a, b) => a.data.compareTo(b.data));
    } else {
      // Se não há séries, carregar apenas disponibilidades únicas
      try {
        final dispsUnicas =
            await DisponibilidadeUnicaService.carregarDisponibilidadesUnicas(
          medicoId,
          anoParaCarregar,
          unidade,
        );

        final listaOrdenada = CadastroMedicosHelper.mesclarApenasUnicas(
          disponibilidadesExistentes,
          dispsUnicas,
          medicoId,
        );

        disponibilidades = listaOrdenada;
      } catch (e) {
        // Erro ao carregar - retornar lista vazia
        disponibilidades = [];
      }
    }

    return {
      'disponibilidades': disponibilidades,
      'series': seriesCarregadas,
      'excecoes': excecoesCarregadas.isNotEmpty ? excecoesCarregadas : [],
    };
  }
}
