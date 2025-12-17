// lib/services/unidade_service.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/unidade.dart';

class UnidadeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Busca todas as unidades ativas
  static Future<List<Unidade>> buscarUnidades() async {
    try {
      debugPrint('🔍 Buscando unidades no Firebase...');

      // Primeiro, vamos buscar todas as unidades sem filtro para debug
      final snapshotAll = await _firestore.collection('unidades').get();

      debugPrint(
          '📊 Total de documentos encontrados (sem filtro): ${snapshotAll.docs.length}');

      for (final doc in snapshotAll.docs) {
        debugPrint('📄 Documento ID: ${doc.id}');
        debugPrint('📄 Dados completos: ${doc.data()}');
      }

      // Tentar buscar unidades ativas
      List<Unidade> unidades = [];

      // Buscar todas as unidades e filtrar no código para evitar problemas de índice
      unidades = snapshotAll.docs.map((doc) {
        final data = doc.data();
        // Se não tiver campo 'ativa', considerar como ativa
        if (data['ativa'] == null) {
          data['ativa'] = true;
        }
        return Unidade.fromMap({...data, 'id': doc.id});
      }).toList();

      // Filtrar apenas unidades ativas e ordenar por nome
      unidades = unidades.where((unidade) => unidade.ativa).toList();
      unidades.sort((a, b) => a.nome.compareTo(b.nome));

      debugPrint(
          '📊 Total de documentos ativos encontrados: ${unidades.length}');
      for (final unidade in unidades) {
        debugPrint(
            '📄 Unidade ativa: ${unidade.nome} - Ativa: ${unidade.ativa}');
      }

      debugPrint('✅ Unidades carregadas: ${unidades.length}');
      for (final unidade in unidades) {
        debugPrint(
            '🏥 Unidade: ${unidade.nome} (${unidade.tipo}) - Ativa: ${unidade.ativa}');
      }

      return unidades;
    } catch (e) {
      debugPrint('❌ Erro ao buscar unidades: $e');
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
      debugPrint('Erro ao buscar unidade por ID: $e');
      return null;
    }
  }

  /// Cria uma nova unidade
  static Future<String?> criarUnidade(Unidade unidade) async {
    try {
      debugPrint('➕ Criando nova unidade...');
      debugPrint('📝 Dados da unidade: ${unidade.toMap()}');

      final docRef =
          await _firestore.collection('unidades').add(unidade.toMap());

      debugPrint('✅ Unidade criada com ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Erro ao criar unidade: $e');
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
      debugPrint('Erro ao atualizar unidade: $e');
      return false;
    }
  }

  /// Desativa uma unidade (soft delete)
  static Future<bool> desativarUnidade(String id) async {
    try {
      await _firestore.collection('unidades').doc(id).update({'ativa': false});
      return true;
    } catch (e) {
      debugPrint('Erro ao desativar unidade: $e');
      return false;
    }
  }

  /// Remove uma unidade permanentemente
  static Future<bool> removerUnidade(String id) async {
    try {
      await _firestore.collection('unidades').doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('Erro ao remover unidade: $e');
      return false;
    }
  }

  /// Verifica se uma unidade existe
  static Future<bool> unidadeExiste(String id) async {
    try {
      final doc = await _firestore.collection('unidades').doc(id).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Erro ao verificar se unidade existe: $e');
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
      debugPrint('Erro ao buscar unidades por tipo: $e');
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
      debugPrint('Erro ao listar tipos de unidades: $e');
      return ['Clínica', 'Hospital', 'Centro Médico', 'Hotel'];
    }
  }
}
