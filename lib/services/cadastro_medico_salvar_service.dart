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
  }) async {
    // Preparar disponibilidades únicas para salvar
    final disponibilidadesUnicasParaSalvar =
        CadastroMedicosHelper.prepararDisponibilidadesUnicasParaSalvar(
      disponibilidades,
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
      ativo: true,
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
      await CadastroMedicosHelper.salvarSeries(series, unidade);

      // Salvar disponibilidades únicas
      int unicasSalvas = 0;
      int unicasErros = 0;

      for (final disp in disponibilidadesUnicasParaSalvar) {
        try {
          await DisponibilidadeUnicaService.salvarDisponibilidadesUnicas(
            [disp],
            medicoId,
            unidade,
          );
          unicasSalvas++;
        } catch (e, stackTrace) {
          unicasErros++;
          debugPrint('❌ Erro ao salvar disponibilidade única ${disp.id}: $e');
          debugPrint('   Stack trace: $stackTrace');

          if (mostrarMensagensErro) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Erro ao salvar disponibilidade ${disp.data.day}/${disp.data.month}/${disp.data.year}: $e'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }

      // Aguardar um pouco para dar tempo à Cloud Function atualizar a vista diária
      await Future.delayed(const Duration(milliseconds: 1000));

      // Salvar exceções
      for (final excecao in excecoes) {
        await SerieService.salvarExcecao(excecao, medicoId, unidade: unidade);
      }

      // Invalidar cache
      CadastroMedicosHelper.invalidarCacheDisponibilidades(disponibilidades);

      // Invalidar cache de médicos ativos
      if (unidade != null) {
        AlocacaoMedicosLogic.invalidateMedicosAtivosCache(
            unidadeId: unidade.id);
        AlocacaoMedicosLogic.invalidateSeriesCacheForMedico(medicoId, null);
      }

      // Mostrar avisos se houver erros
      if (unicasErros > 0 && mostrarMensagensErro) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Aviso: $unicasErros disponibilidade(s) única(s) não foram salvas. Verifique os logs.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      return {
        'sucesso': true,
        'unicasSalvas': unicasSalvas,
        'unicasErros': unicasErros,
      };
    } catch (e) {
      if (mostrarMensagensErro) {
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
