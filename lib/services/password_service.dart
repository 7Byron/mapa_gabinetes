import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PasswordService {
  static const String _projectPasswordKey = 'project_password';
  static const String _adminPasswordKey = 'admin_password';
  static const String _isFirstTimeKey = 'is_first_time';
  static const String _rememberPasswordKey = 'remember_password';

  static String _projectPasswordKeyFor(String unidadeId) =>
      '${_projectPasswordKey}_$unidadeId';
  static String _adminPasswordKeyFor(String unidadeId) =>
      '${_adminPasswordKey}_$unidadeId';
  static String _cacheKey(String baseKey, String? unidadeId) =>
      unidadeId != null && unidadeId.isNotEmpty
          ? '${baseKey}_$unidadeId'
          : baseKey;

  /// Verifica se é a primeira vez que o usuário acessa o app
  static Future<bool> isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstTimeKey) ?? true;
  }

  /// Marca que não é mais a primeira vez
  static Future<void> markAsNotFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFirstTimeKey, false);
  }

  /// Salva a password do projeto no documento da unidade
  static Future<void> saveProjectPassword(String password,
      {String? unidadeId}) async {
    try {
      debugPrint('🔐 === SALVANDO PASSWORD DO PROJETO ===');
      debugPrint('   - Unidade ID: $unidadeId');
      debugPrint('   - Password: ${password.length} caracteres');

      // Salva no documento da unidade se tiver unidadeId
      if (unidadeId != null && unidadeId.isNotEmpty) {
        debugPrint('   - Tentando salvar no documento da unidade...');

        final docRef =
            FirebaseFirestore.instance.collection('unidades').doc(unidadeId);

        debugPrint('   - Referência do documento: ${docRef.path}');

        await docRef.update({
          'project_password': password,
          'updated_at': FieldValue.serverTimestamp(),
        });

        debugPrint(
            '✅ Password do projeto salva no documento da unidade com sucesso!');

        // Verificar se foi realmente salva
        final doc = await docRef.get();
        if (doc.exists) {
          debugPrint('✅ Documento confirmado no Firebase:');
          debugPrint(
              '   - project_password: ${doc.data()?['project_password'] != null ? "Presente" : "Ausente"}');
          debugPrint(
              '   - updated_at: ${doc.data()?['updated_at'] != null ? "Presente" : "Ausente"}');
        } else {
          debugPrint('❌ Documento não encontrado após salvar!');
        }
      } else {
        debugPrint('⚠️ Unidade ID é nulo ou vazio - não salvando no Firebase');
      }

      // Também salva localmente para cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _cacheKey(_projectPasswordKey, unidadeId), password);
      debugPrint('✅ Password do projeto salva localmente');
    } catch (e) {
      debugPrint('❌ Erro ao salvar password do projeto: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');

      // Em caso de erro no Firebase, ainda salva localmente
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            _cacheKey(_projectPasswordKey, unidadeId), password);
        debugPrint(
            '✅ Password do projeto salva apenas localmente devido a erro no Firebase');
      } catch (localError) {
        debugPrint('❌ Erro ao salvar password localmente: $localError');
      }
      rethrow;
    }
  }

  /// Salva a password do administrador no documento da unidade
  static Future<void> saveAdminPassword(String password,
      {String? unidadeId}) async {
    try {
      debugPrint('🔐 === SALVANDO PASSWORD DO ADMINISTRADOR ===');
      debugPrint('   - Unidade ID: $unidadeId');
      debugPrint('   - Password: ${password.length} caracteres');

      // Salva no documento da unidade se tiver unidadeId
      if (unidadeId != null && unidadeId.isNotEmpty) {
        debugPrint('   - Tentando salvar no documento da unidade...');

        final docRef =
            FirebaseFirestore.instance.collection('unidades').doc(unidadeId);

        debugPrint('   - Referência do documento: ${docRef.path}');

        await docRef.update({
          'admin_password': password,
          'updated_at': FieldValue.serverTimestamp(),
        });

        debugPrint(
            '✅ Password do administrador salva no documento da unidade com sucesso!');

        // Verificar se foi realmente salva
        final doc = await docRef.get();
        if (doc.exists) {
          debugPrint('✅ Documento confirmado no Firebase:');
          debugPrint(
              '   - admin_password: ${doc.data()?['admin_password'] != null ? "Presente" : "Ausente"}');
          debugPrint(
              '   - updated_at: ${doc.data()?['updated_at'] != null ? "Presente" : "Ausente"}');
        } else {
          debugPrint('❌ Documento não encontrado após salvar!');
        }
      } else {
        debugPrint('⚠️ Unidade ID é nulo ou vazio - não salvando no Firebase');
      }

      // Também salva localmente para cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(_adminPasswordKey, unidadeId), password);
      debugPrint('✅ Password do administrador salva localmente');
    } catch (e) {
      debugPrint('❌ Erro ao salvar password do administrador: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');

      // Em caso de erro no Firebase, ainda salva localmente
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            _cacheKey(_adminPasswordKey, unidadeId), password);
        debugPrint(
            '✅ Password do administrador salva apenas localmente devido a erro no Firebase');
      } catch (localError) {
        debugPrint('❌ Erro ao salvar password localmente: $localError');
      }
      rethrow;
    }
  }

  /// Obtém a password do projeto (tenta Firebase primeiro, depois local)
  static Future<String?> getProjectPassword({String? unidadeId}) async {
    try {
      debugPrint('🔍 Obtendo password do projeto para unidade: $unidadeId');

      // Tenta obter do documento da unidade primeiro
      if (unidadeId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('unidades')
            .doc(unidadeId)
            .get();

        if (doc.exists && doc.data()?['project_password'] != null) {
          final password = doc.data()!['project_password'] as String;
          // Atualiza cache local
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_projectPasswordKeyFor(unidadeId), password);
          debugPrint('✅ Password do projeto obtida do documento da unidade');
          return password;
        } else {
          debugPrint(
              '⚠️ Password do projeto não encontrada no documento da unidade');
        }
      }

      // Se não conseguir do Firebase, tenta local
      final prefs = await SharedPreferences.getInstance();
      // Com uma unidade explícita, nunca usar a antiga chave global: ela pode
      // conter a password de outra clínica.
      final localPassword =
          prefs.getString(_cacheKey(_projectPasswordKey, unidadeId));
      if (localPassword != null) {
        debugPrint('✅ Password do projeto obtida do cache local');
      } else {
        debugPrint('⚠️ Password do projeto não encontrada localmente');
      }
      return localPassword;
    } catch (e) {
      debugPrint('❌ Erro ao obter password do projeto: $e');
      // Em caso de erro, tenta local
      try {
        final prefs = await SharedPreferences.getInstance();
        final localPassword =
            prefs.getString(_cacheKey(_projectPasswordKey, unidadeId));
        debugPrint('✅ Password do projeto obtida do cache local (fallback)');
        return localPassword;
      } catch (localError) {
        debugPrint('❌ Erro ao obter password localmente: $localError');
        return null;
      }
    }
  }

  /// Obtém a password do administrador (tenta Firebase primeiro, depois local)
  static Future<String?> getAdminPassword({String? unidadeId}) async {
    try {
      debugPrint(
          '🔍 Obtendo password do administrador para unidade: $unidadeId');

      // Tenta obter do documento da unidade primeiro
      if (unidadeId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('unidades')
            .doc(unidadeId)
            .get();

        if (doc.exists && doc.data()?['admin_password'] != null) {
          final password = doc.data()!['admin_password'] as String;
          // Atualiza cache local
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_adminPasswordKeyFor(unidadeId), password);
          debugPrint(
              '✅ Password do administrador obtida do documento da unidade');
          return password;
        } else {
          debugPrint(
              '⚠️ Password do administrador não encontrada no documento da unidade');
        }
      }

      // Se não conseguir do Firebase, tenta local
      final prefs = await SharedPreferences.getInstance();
      final localPassword =
          prefs.getString(_cacheKey(_adminPasswordKey, unidadeId));
      if (localPassword != null) {
        debugPrint('✅ Password do administrador obtida do cache local');
      } else {
        debugPrint('⚠️ Password do administrador não encontrada localmente');
      }
      return localPassword;
    } catch (e) {
      debugPrint('❌ Erro ao obter password do administrador: $e');
      // Em caso de erro, tenta local
      try {
        final prefs = await SharedPreferences.getInstance();
        final localPassword =
            prefs.getString(_cacheKey(_adminPasswordKey, unidadeId));
        debugPrint(
            '✅ Password do administrador obtida do cache local (fallback)');
        return localPassword;
      } catch (localError) {
        debugPrint('❌ Erro ao obter password localmente: $localError');
        return null;
      }
    }
  }

  /// Verifica se a password do projeto está correta
  static Future<bool> verifyProjectPassword(String inputPassword,
      {String? unidadeId}) async {
    final savedPassword = await getProjectPassword(unidadeId: unidadeId);
    return savedPassword != null && savedPassword == inputPassword;
  }

  /// Verifica se a password do administrador está correta
  static Future<bool> verifyAdminPassword(String inputPassword,
      {String? unidadeId}) async {
    final savedPassword = await getAdminPassword(unidadeId: unidadeId);
    return savedPassword != null && savedPassword == inputPassword;
  }

  /// Limpa todas as passwords salvas (apenas local)
  static Future<void> clearPasswords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_projectPasswordKey);
    await prefs.remove(_adminPasswordKey);
    await prefs.remove(_isFirstTimeKey);
    await prefs.remove(_rememberPasswordKey);
  }

  /// Limpa apenas a password do projeto (apenas local)
  static Future<void> clearProjectPassword({String? unidadeId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey(_projectPasswordKey, unidadeId));
  }

  /// Limpa apenas a password do administrador (apenas local)
  static Future<void> clearAdminPassword({String? unidadeId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey(_adminPasswordKey, unidadeId));
  }

  /// Verifica se as passwords estão configuradas
  static Future<bool> hasPasswordsConfigured({String? unidadeId}) async {
    try {
      debugPrint(
          '🔍 Verificando se passwords estão configuradas para unidade: $unidadeId');

      // Primeiro tenta verificar no documento da unidade
      if (unidadeId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('unidades')
            .doc(unidadeId)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          final hasProject = data['project_password'] != null &&
              data['project_password'].toString().isNotEmpty;
          final hasAdmin = data['admin_password'] != null &&
              data['admin_password'].toString().isNotEmpty;

          debugPrint('📊 Status das passwords no documento da unidade:');
          debugPrint(
              '   - Password do projeto: ${hasProject ? "✅ Configurada" : "❌ Não configurada"}');
          debugPrint(
              '   - Password do administrador: ${hasAdmin ? "✅ Configurada" : "❌ Não configurada"}');
          debugPrint(
              '   - Total: ${hasProject && hasAdmin ? "✅ Ambas configuradas" : "❌ Incompleto"}');

          if (hasProject && hasAdmin) {
            return true;
          }
        }
      }

      // Se não encontrou no documento da unidade, tenta local
      final projectPassword = await getProjectPassword(unidadeId: unidadeId);
      final adminPassword = await getAdminPassword(unidadeId: unidadeId);

      final hasProject = projectPassword != null && projectPassword.isNotEmpty;
      final hasAdmin = adminPassword != null && adminPassword.isNotEmpty;

      debugPrint('📊 Status das passwords no cache local:');
      debugPrint(
          '   - Password do projeto: ${hasProject ? "✅ Configurada" : "❌ Não configurada"}');
      debugPrint(
          '   - Password do administrador: ${hasAdmin ? "✅ Configurada" : "❌ Não configurada"}');
      debugPrint(
          '   - Total: ${hasProject && hasAdmin ? "✅ Ambas configuradas" : "❌ Incompleto"}');

      return hasProject && hasAdmin;
    } catch (e) {
      debugPrint('❌ Erro ao verificar passwords configuradas: $e');
      return false;
    }
  }

  /// Salva a preferência de lembrar password (apenas local)
  static Future<void> setRememberPassword(bool remember,
      {String? unidadeId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cacheKey(_rememberPasswordKey, unidadeId), remember);
  }

  /// Obtém a preferência de lembrar password (apenas local)
  static Future<bool> getRememberPassword({String? unidadeId}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_cacheKey(_rememberPasswordKey, unidadeId)) ??
        true; // Por defeito true
  }

  /// Verifica se há alguma password guardada
  static Future<bool> hasAnyPasswordSaved({String? unidadeId}) async {
    final projectPassword = await getProjectPassword(unidadeId: unidadeId);
    final adminPassword = await getAdminPassword(unidadeId: unidadeId);
    return projectPassword != null || adminPassword != null;
  }

  /// Limpa passwords locais se a opção "lembrar" estiver desativada
  static Future<void> clearPasswordsIfNotRemembered() async {
    final remember = await getRememberPassword();
    if (!remember) {
      await clearPasswords();
    }
  }

  /// Carrega passwords do documento da unidade para cache local
  static Future<void> loadPasswordsFromFirebase(String unidadeId) async {
    try {
      debugPrint('🔄 Carregando passwords do documento da unidade: $unidadeId');

      final prefs = await SharedPreferences.getInstance();
      final remember =
          prefs.getBool(_cacheKey(_rememberPasswordKey, unidadeId)) ?? true;
      if (!remember) {
        await prefs.remove(_projectPasswordKeyFor(unidadeId));
        await prefs.remove(_adminPasswordKeyFor(unidadeId));
        debugPrint('ℹ️ Cache de passwords desativado para esta unidade');
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('unidades')
          .doc(unidadeId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        if (data['project_password'] != null) {
          await prefs.setString(
              _projectPasswordKeyFor(unidadeId), data['project_password']);
          debugPrint('✅ Password do projeto carregada do documento da unidade');
        }

        if (data['admin_password'] != null) {
          await prefs.setString(
              _adminPasswordKeyFor(unidadeId), data['admin_password']);
          debugPrint(
              '✅ Password do administrador carregada do documento da unidade');
        }

        debugPrint('✅ Todas as passwords carregadas com sucesso');
      } else {
        debugPrint('⚠️ Documento da unidade não encontrado');
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar passwords do documento da unidade: $e');
    }
  }

  /// Verifica se o usuário atual é administrador
  static Future<bool> isCurrentUserAdmin({required String unidadeId}) async {
    try {
      final adminPassword = await getAdminPassword(unidadeId: unidadeId);
      if (adminPassword == null || adminPassword.isEmpty) {
        return false;
      }

      // Verificar se há uma sessão de admin ativa
      final prefs = await SharedPreferences.getInstance();
      final isAdminSession =
          prefs.getBool('is_admin_session_$unidadeId') ?? false;
      return isAdminSession;
    } catch (e) {
      debugPrint('❌ Erro ao verificar se usuário é administrador: $e');
      return false;
    }
  }
}
