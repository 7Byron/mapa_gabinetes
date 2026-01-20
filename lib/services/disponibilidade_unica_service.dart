import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/disponibilidade.dart';
import '../models/unidade.dart';
import '../utils/cadastro_medicos_helper.dart';
import '../utils/alocacao_medicos_logic.dart';
import 'cache_version_service.dart';

/// Serviço para salvar disponibilidades únicas no Firestore
/// Extracted from cadastro_medicos.dart to reduce code duplication
class DisponibilidadeUnicaService {
  /// Salva uma lista de disponibilidades únicas no Firestore
  /// Retorna um mapa com 'salvas' e 'erros' contendo as contagens
  static Future<Map<String, int>> salvarDisponibilidadesUnicas(
    List<Disponibilidade> disponibilidades,
    String medicoId,
    Unidade? unidade,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final unidadeId = CadastroMedicosHelper.obterUnidadeId(unidade);

    int unicasSalvas = 0;
    int unicasErros = 0;
    const int batchSize = 400;
    WriteBatch batch = firestore.batch();
    int opsNoBatch = 0;
    final diasInvalidar = <DateTime>{};

    Future<void> commitBatch() async {
      if (opsNoBatch == 0) return;
      try {
        await batch.commit();
        unicasSalvas += opsNoBatch;
        for (final dia in diasInvalidar) {
          AlocacaoMedicosLogic.invalidateCacheForDay(dia);
        }
      } catch (e) {
        unicasErros += opsNoBatch;
        rethrow;
      } finally {
        batch = firestore.batch();
        opsNoBatch = 0;
        diasInvalidar.clear();
      }
    }

    for (final disp in disponibilidades) {
      // Garantir que a disponibilidade única tem um ID válido permanente
      String idParaSalvar = disp.id;
      if (CadastroMedicosHelper.isIdTemporarioOuInvalido(idParaSalvar)) {
        idParaSalvar =
            CadastroMedicosHelper.gerarIdPermanenteParaDisponibilidade(
                disp, medicoId);
      }

      final ano = disp.data.year.toString();
      final disponibilidadesRef = firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('ocupantes')
          .doc(medicoId)
          .collection('disponibilidades')
          .doc(ano)
          .collection('registos');

      // Criar uma cópia com o ID correto
      final dispComId = Disponibilidade(
        id: idParaSalvar,
        medicoId: disp.medicoId,
        data: disp.data,
        horarios: disp.horarios,
        tipo: disp.tipo,
      );

      final dataMap = dispComId.toMap();
      batch.set(disponibilidadesRef.doc(idParaSalvar), dataMap);
      opsNoBatch++;

      final dataNormalizada =
          DateTime(disp.data.year, disp.data.month, disp.data.day);
      diasInvalidar.add(dataNormalizada);

      if (opsNoBatch >= batchSize) {
        await commitBatch();
      }
    }

    await commitBatch();

    if (unicasSalvas > 0) {
      await CacheVersionService.bumpVersion(
        unidadeId: unidadeId,
        field: CacheVersionService.fieldDisponibilidades,
      );
    }

    return {'salvas': unicasSalvas, 'erros': unicasErros};
  }

  /// Carrega disponibilidades únicas do Firestore para um médico e ano específicos
  /// Retorna uma lista de disponibilidades únicas
  static Future<List<Disponibilidade>> carregarDisponibilidadesUnicas(
    String medicoId,
    int ano,
    Unidade? unidade,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final unidadeId = CadastroMedicosHelper.obterUnidadeId(unidade);
      final disponibilidadesRef = firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('ocupantes')
          .doc(medicoId)
          .collection('disponibilidades')
          .doc(ano.toString())
          .collection('registos');

      final snapshot =
          await disponibilidadesRef.where('tipo', isEqualTo: 'Única').get();

      return snapshot.docs
          .map((doc) => Disponibilidade.fromMap(doc.data()))
          .where((d) => d.tipo == 'Única' && d.medicoId == medicoId)
          .toList();
    } catch (e) {
      // Erro ao carregar disponibilidades únicas - retornar lista vazia
      return [];
    }
  }
}
