import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PasswordService {
  static const String _projectPasswordKey = 'project_password';
  static const String _adminPasswordKey = 'admin_password';
  static const String _isFirstTimeKey = 'is_first_time';
  static const String _rememberPasswordKey = 'remember_password';

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
      print('🔐 === SALVANDO PASSWORD DO PROJETO ===');
      print('   - Unidade ID: $unidadeId');
      print('   - Password: ${password.length} caracteres');

      // Salva no documento da unidade se tiver unidadeId
      if (unidadeId != null && unidadeId.isNotEmpty) {
        print('   - Tentando salvar no documento da unidade...');

        final docRef =
            FirebaseFirestore.instance.collection('unidades').doc(unidadeId);

        print('   - Referência do documento: ${docRef.path}');

        await docRef.update({
          'project_password': password,
          'updated_at': FieldValue.serverTimestamp(),
        });

        print(
            '✅ Password do projeto salva no documento da unidade com sucesso!');

        // Verificar se foi realmente salva
        final doc = await docRef.get();
        if (doc.exists) {
          print('✅ Documento confirmado no Firebase:');
          print(
              '   - project_password: ${doc.data()?['project_password'] != null ? "Presente" : "Ausente"}');
          print(
              '   - updated_at: ${doc.data()?['updated_at'] != null ? "Presente" : "Ausente"}');
        } else {
          print('❌ Documento não encontrado após salvar!');
        }
      } else {
        print('⚠️ Unidade ID é nulo ou vazio - não salvando no Firebase');
      }

      // Também salva localmente para cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_projectPasswordKey, password);
      print('✅ Password do projeto salva localmente');
    } catch (e) {
      print('❌ Erro ao salvar password do projeto: $e');
      print('❌ Stack trace: ${StackTrace.current}');

      // Em caso de erro no Firebase, ainda salva localmente
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_projectPasswordKey, password);
        print(
            '✅ Password do projeto salva apenas localmente devido a erro no Firebase');
      } catch (localError) {
        print('❌ Erro ao salvar password localmente: $localError');
      }
      rethrow;
    }
  }

  /// Salva a password do administrador no documento da unidade
  static Future<void> saveAdminPassword(String password,
      {String? unidadeId}) async {
    try {
      print('🔐 === SALVANDO PASSWORD DO ADMINISTRADOR ===');
      print('   - Unidade ID: $unidadeId');
      print('   - Password: ${password.length} caracteres');

      // Salva no documento da unidade se tiver unidadeId
      if (unidadeId != null && unidadeId.isNotEmpty) {
        print('   - Tentando salvar no documento da unidade...');

        final docRef =
            FirebaseFirestore.instance.collection('unidades').doc(unidadeId);

        print('   - Referência do documento: ${docRef.path}');

        await docRef.update({
          'admin_password': password,
          'updated_at': FieldValue.serverTimestamp(),
        });

        print(
            '✅ Password do administrador salva no documento da unidade com sucesso!');

        // Verificar se foi realmente salva
        final doc = await docRef.get();
        if (doc.exists) {
          print('✅ Documento confirmado no Firebase:');
          print(
              '   - admin_password: ${doc.data()?['admin_password'] != null ? "Presente" : "Ausente"}');
          print(
              '   - updated_at: ${doc.data()?['updated_at'] != null ? "Presente" : "Ausente"}');
        } else {
          print('❌ Documento não encontrado após salvar!');
        }
      } else {
        print('⚠️ Unidade ID é nulo ou vazio - não salvando no Firebase');
      }

      // Também salva localmente para cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_adminPasswordKey, password);
      print('✅ Password do administrador salva localmente');
    } catch (e) {
      print('❌ Erro ao salvar password do administrador: $e');
      print('❌ Stack trace: ${StackTrace.current}');

      // Em caso de erro no Firebase, ainda salva localmente
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_adminPasswordKey, password);
        print(
            '✅ Password do administrador salva apenas localmente devido a erro no Firebase');
      } catch (localError) {
        print('❌ Erro ao salvar password localmente: $localError');
      }
      rethrow;
    }
  }

  /// Obtém a password do projeto (tenta Firebase primeiro, depois local)
  static Future<String?> getProjectPassword({String? unidadeId}) async {
    try {
      print('🔍 Obtendo password do projeto para unidade: $unidadeId');

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
          await prefs.setString(_projectPasswordKey, password);
          print('✅ Password do projeto obtida do documento da unidade');
          return password;
        } else {
          print(
              '⚠️ Password do projeto não encontrada no documento da unidade');
        }
      }

      // Se não conseguir do Firebase, tenta local
      final prefs = await SharedPreferences.getInstance();
      final localPassword = prefs.getString(_projectPasswordKey);
      if (localPassword != null) {
        print('✅ Password do projeto obtida do cache local');
      } else {
        print('⚠️ Password do projeto não encontrada localmente');
      }
      return localPassword;
    } catch (e) {
      print('❌ Erro ao obter password do projeto: $e');
      // Em caso de erro, tenta local
      try {
        final prefs = await SharedPreferences.getInstance();
        final localPassword = prefs.getString(_projectPasswordKey);
        print('✅ Password do projeto obtida do cache local (fallback)');
        return localPassword;
      } catch (localError) {
        print('❌ Erro ao obter password localmente: $localError');
        return null;
      }
    }
  }

  /// Obtém a password do administrador (tenta Firebase primeiro, depois local)
  static Future<String?> getAdminPassword({String? unidadeId}) async {
    try {
      print('🔍 Obtendo password do administrador para unidade: $unidadeId');

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
          await prefs.setString(_adminPasswordKey, password);
          print('✅ Password do administrador obtida do documento da unidade');
          return password;
        } else {
          print(
              '⚠️ Password do administrador não encontrada no documento da unidade');
        }
      }

      // Se não conseguir do Firebase, tenta local
      final prefs = await SharedPreferences.getInstance();
      final localPassword = prefs.getString(_adminPasswordKey);
      if (localPassword != null) {
        print('✅ Password do administrador obtida do cache local');
      } else {
        print('⚠️ Password do administrador não encontrada localmente');
      }
      return localPassword;
    } catch (e) {
      print('❌ Erro ao obter password do administrador: $e');
      // Em caso de erro, tenta local
      try {
        final prefs = await SharedPreferences.getInstance();
        final localPassword = prefs.getString(_adminPasswordKey);
        print('✅ Password do administrador obtida do cache local (fallback)');
        return localPassword;
      } catch (localError) {
        print('❌ Erro ao obter password localmente: $localError');
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
  static Future<void> clearProjectPassword() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_projectPasswordKey);
  }

  /// Limpa apenas a password do administrador (apenas local)
  static Future<void> clearAdminPassword() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_adminPasswordKey);
  }

  /// Verifica se as passwords estão configuradas
  static Future<bool> hasPasswordsConfigured({String? unidadeId}) async {
    try {
      print(
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

          print('📊 Status das passwords no documento da unidade:');
          print(
              '   - Password do projeto: ${hasProject ? "✅ Configurada" : "❌ Não configurada"}');
          print(
              '   - Password do administrador: ${hasAdmin ? "✅ Configurada" : "❌ Não configurada"}');
          print(
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

      print('📊 Status das passwords no cache local:');
      print(
          '   - Password do projeto: ${hasProject ? "✅ Configurada" : "❌ Não configurada"}');
      print(
          '   - Password do administrador: ${hasAdmin ? "✅ Configurada" : "❌ Não configurada"}');
      print(
          '   - Total: ${hasProject && hasAdmin ? "✅ Ambas configuradas" : "❌ Incompleto"}');

      return hasProject && hasAdmin;
    } catch (e) {
      print('❌ Erro ao verificar passwords configuradas: $e');
      return false;
    }
  }

  /// Salva a preferência de lembrar password (apenas local)
  static Future<void> setRememberPassword(bool remember) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberPasswordKey, remember);
  }

  /// Obtém a preferência de lembrar password (apenas local)
  static Future<bool> getRememberPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberPasswordKey) ?? true; // Por defeito true
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
      print('🔄 Carregando passwords do documento da unidade: $unidadeId');

      final doc = await FirebaseFirestore.instance
          .collection('unidades')
          .doc(unidadeId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final prefs = await SharedPreferences.getInstance();

        if (data['project_password'] != null) {
          await prefs.setString(_projectPasswordKey, data['project_password']);
          print('✅ Password do projeto carregada do documento da unidade');
        }

        if (data['admin_password'] != null) {
          await prefs.setString(_adminPasswordKey, data['admin_password']);
          print(
              '✅ Password do administrador carregada do documento da unidade');
        }

        print('✅ Todas as passwords carregadas com sucesso');
      } else {
        print('⚠️ Documento da unidade não encontrado');
      }
    } catch (e) {
      print('❌ Erro ao carregar passwords do documento da unidade: $e');
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
      print('❌ Erro ao verificar se usuário é administrador: $e');
      return false;
    }
  }
}
