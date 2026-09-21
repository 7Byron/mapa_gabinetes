import 'package:flutter/material.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../models/disponibilidade.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
import '../services/disponibilidade_unica_service.dart';
import '../services/serie_service.dart';
import '../utils/cadastro_medicos_helper.dart';
import '../utils/alocacao_medicos_logic.dart';
import 'medico_salvar_service.dart' as medico_salvar;

/// Serviço para salvar médico completo com todas as suas dependências
/// Extracted from cadastro_medicos.dart to reduce code duplication
class CadastroMedicoSalvarService {
  /// Salva um médico completo incluindo:
  /// - Dados do médico (nome, especialidade, observações)
  /// - Séries de recorrência
  /// - Disponibilidades únicas
  /// - Exceções de séries
  /// - Invalidação de cache
  ///
  /// Retorna um mapa com informações sobre o resultado:
  /// - 'sucesso': bool
  /// - 'unicasSalvas': int
  /// - 'unicasErros': int
  /// - 'mensagemErro': String? (se houver erro)
  static Future<Map<String, dynamic>> salvarMedicoCompletoComTudo(
    BuildContext context,
    String medicoId,
    String nome,
    String especialidade,
    String observacoes,
    List<Disponibilidade> disponibilidades,
    List<SerieRecorrencia> series,
    List<ExcecaoSerie> excecoes,
    List<Disponibilidade> disponibilidadesOriginais,
    Unidade? unidade, {
    bool mostrarMensagensErro = true,
    bool ativo = true, // Campo ativo do médico
  }) async {
    // Preparar disponibilidades únicas para salvar
    final disponibilidadesUnicasParaSalvar =
        CadastroMedicosHelper.prepararDisponibilidadesUnicasParaSalvar(
      CadastroMedicosHelper.disponibilidadesPendentes(
        disponibilidades,
        disponibilidadesOriginais,
      ),
      medicoId,
    );

    // Remover disponibilidades únicas da lista antes de passar para salvarMedicoCompleto
    final disponibilidadesSemUnicas =
        CadastroMedicosHelper.removerDisponibilidadesUnicas(
      disponibilidades,
      medicoId,
    );

    // Criar objeto médico
    final medico = Medico(
      id: medicoId,
      nome: nome,
      especialidade: especialidade,
      observacoes: observacoes,
      disponibilidades: disponibilidadesSemUnicas,
      ativo: ativo, // Usar o valor passado como parâmetro
    );

    try {
      // Salvar médico e disponibilidades antigas (compatibilidade)
      await medico_salvar.salvarMedicoCompleto(
        medico,
        unidade: unidade,
        disponibilidadesOriginais: disponibilidadesOriginais
            .where((d) => !(d.tipo == 'Única' && d.medicoId == medicoId))
            .toList(),
      );

      // Salvar séries de recorrência
      // CORREÇÃO CRÍTICA: As séries invalidam o cache automaticamente quando são salvas
      // através do CadastroMedicosHelper.salvarSeries que chama invalidateCacheParaSerie
      await CadastroMedicosHelper.salvarSeries(series, unidade);

      // Um único lote lógico: falhas propagam-se e impedem a saída da página.
      final resultadoUnicas = disponibilidadesUnicasParaSalvar.isEmpty
          ? {'salvas': 0, 'erros': 0}
          : await DisponibilidadeUnicaService.salvarDisponibilidadesUnicas(
              disponibilidadesUnicasParaSalvar,
              medicoId,
              unidade,
            );
      final unicasSalvas = resultadoUnicas['salvas']!;
      final unicasErros = resultadoUnicas['erros']!;
      if (unicasErros > 0) {
        throw StateError('Não foi possível guardar todos os cartões.');
      }

      // Salvar exceções
      // CORREÇÃO CRÍTICA: Exceções invalidam o cache automaticamente quando são salvas
      // através do SerieService.salvarExcecao
      for (final excecao in excecoes) {
        await SerieService.salvarExcecao(excecao, medicoId, unidade: unidade);
      }

      // CORREÇÃO CRÍTICA: Invalidar cache para todas as disponibilidades
      // Isso garante que mesmo disponibilidades que não foram salvas diretamente sejam atualizadas
      CadastroMedicosHelper.invalidarCacheDisponibilidades(disponibilidades);

      // CORREÇÃO CRÍTICA: Invalidar cache também para todas as séries
      // Para garantir que todas as séries sejam recarregadas
      for (final serie in series) {
        AlocacaoMedicosLogic.invalidateCacheParaSerie(serie, unidade: unidade);
      }

      // Invalidar cache de médicos ativos
      if (unidade != null) {
        // Cache removido - não precisa invalidar
      }

      return {
        'sucesso': true,
        'unicasSalvas': unicasSalvas,
        'unicasErros': unicasErros,
      };
    } catch (e) {
      if (mostrarMensagensErro && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar registo: $e')),
        );
      }
      return {
        'sucesso': false,
        'unicasSalvas': 0,
        'unicasErros': 0,
        'mensagemErro': e.toString(),
      };
    }
  }
}
