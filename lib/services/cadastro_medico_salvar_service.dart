import 'package:flutter/material.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../models/disponibilidade.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
import '../services/disponibilidade_unica_service.dart';
import '../services/serie_service.dart';
import '../utils/cadastro_medicos_helper.dart';
import '../utils/cadastro_persistencia_snapshot.dart';
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
    CadastroPersistenciaSnapshot? persistenciaSnapshot,
    Medico? medicoOriginal,
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
        medicoOriginal: medicoOriginal,
        disponibilidadesOriginais: disponibilidadesOriginais
            .where((d) => !(d.tipo == 'Única' && d.medicoId == medicoId))
            .toList(),
      );

      final seriesPendentes =
          persistenciaSnapshot?.seriesPendentes(series) ?? series;
      final excecoesPendentes =
          persistenciaSnapshot?.excecoesPendentes(excecoes) ?? excecoes;

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

      await SerieService.salvarAlteracoes(
        series: seriesPendentes,
        excecoes: excecoesPendentes,
        originais: persistenciaSnapshot,
        medicoId: medicoId,
        unidade: unidade,
      );
      persistenciaSnapshot?.registarSeries(seriesPendentes);
      persistenciaSnapshot?.registarExcecoes(excecoesPendentes);

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
