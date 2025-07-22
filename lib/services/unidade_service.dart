// lib/services/unidade_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/unidade.dart';

class UnidadeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Busca todas as unidades ativas
  static Future<List<Unidade>> buscarUnidades() async {
    try {
      print('🔍 Buscando unidades no Firebase...');

      final snapshot = await _firestore
          .collection('unidades')
          .where('ativa', isEqualTo: true)
          .orderBy('nome')
          .get();

      print('📊 Total de documentos encontrados: ${snapshot.docs.length}');

      final unidades = snapshot.docs.map((doc) {
        print('📄 Documento ID: ${doc.id}');
        print('📄 Dados: ${doc.data()}');
        return Unidade.fromMap({...doc.data(), 'id': doc.id});
      }).toList();

      print('✅ Unidades carregadas: ${unidades.length}');
      for (final unidade in unidades) {
        print(
            '🏥 Unidade: ${unidade.nome} (${unidade.tipo}) - Ativa: ${unidade.ativa}');
      }

      return unidades;
    } catch (e) {
      print('❌ Erro ao buscar unidades: $e');
      return [];
    }
  }

  /// Busca uma unidade específica por ID
  static Future<Unidade?> buscarUnidadePorId(String id) async {
    try {
      final doc = await _firestore.collection('unidades').doc(id).get();
      if (doc.exists) {
        return Unidade.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      print('Erro ao buscar unidade por ID: $e');
      return null;
    }
  }

  /// Cria uma nova unidade
  static Future<String?> criarUnidade(Unidade unidade) async {
    try {
      print('➕ Criando nova unidade...');
      print('📝 Dados da unidade: ${unidade.toMap()}');

      final docRef =
          await _firestore.collection('unidades').add(unidade.toMap());

      print('✅ Unidade criada com ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Erro ao criar unidade: $e');
      return null;
    }
  }

  /// Atualiza uma unidade existente
  static Future<bool> atualizarUnidade(Unidade unidade) async {
    try {
      await _firestore
          .collection('unidades')
          .doc(unidade.id)
          .update(unidade.toMap());
      return true;
    } catch (e) {
      print('Erro ao atualizar unidade: $e');
      return false;
    }
  }

  /// Desativa uma unidade (soft delete)
  static Future<bool> desativarUnidade(String id) async {
    try {
      await _firestore.collection('unidades').doc(id).update({'ativa': false});
      return true;
    } catch (e) {
      print('Erro ao desativar unidade: $e');
      return false;
    }
  }

  /// Remove uma unidade permanentemente
  static Future<bool> removerUnidade(String id) async {
    try {
      await _firestore.collection('unidades').doc(id).delete();
      return true;
    } catch (e) {
      print('Erro ao remover unidade: $e');
      return false;
    }
  }

  /// Verifica se uma unidade existe
  static Future<bool> unidadeExiste(String id) async {
    try {
      final doc = await _firestore.collection('unidades').doc(id).get();
      return doc.exists;
    } catch (e) {
      print('Erro ao verificar se unidade existe: $e');
      return false;
    }
  }

  /// Busca unidades por tipo
  static Future<List<Unidade>> buscarUnidadesPorTipo(String tipo) async {
    try {
      final snapshot = await _firestore
          .collection('unidades')
          .where('tipo', isEqualTo: tipo)
          .where('ativa', isEqualTo: true)
          .orderBy('nome')
          .get();

      return snapshot.docs
          .map((doc) => Unidade.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Erro ao buscar unidades por tipo: $e');
      return [];
    }
  }

  /// Lista todos os tipos de unidades disponíveis
  static Future<List<String>> listarTiposUnidades() async {
    try {
      final snapshot = await _firestore
          .collection('unidades')
          .where('ativa', isEqualTo: true)
          .get();

      final tipos = snapshot.docs
          .map((doc) => doc.data()['tipo'] as String)
          .toSet()
          .toList();

      tipos.sort();
      return tipos;
    } catch (e) {
      print('Erro ao listar tipos de unidades: $e');
      return ['Clínica', 'Hospital', 'Centro Médico', 'Hotel'];
    }
  }
}
