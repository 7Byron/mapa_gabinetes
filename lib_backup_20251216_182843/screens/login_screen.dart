import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:flutter/foundation.dart';
import '../services/password_service.dart';
import '../models/unidade.dart';
import 'alocacao_medicos_screen.dart';
import 'selecao_unidade_screen.dart';

class LoginScreen extends StatefulWidget {
  final Unidade unidade;

  const LoginScreen({super.key, required this.unidade});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isFirstTime = true;
  bool _showPassword = false;
  bool _lembrarPassword = true; // Por defeito marcada

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
    _carregarPreferenciaLembrarPassword();
  }

  Future<void> _checkFirstTime() async {
    final isFirstTime = await PasswordService.isFirstTime();
    setState(() {
      _isFirstTime = isFirstTime;
    });
  }

  Future<void> _carregarPreferenciaLembrarPassword() async {
    final remember = await PasswordService.getRememberPassword();
    setState(() {
      _lembrarPassword = remember;
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Bypass da password em modo debug
    if (kDebugMode) {
      print('🔧 MODO DEBUG: Bypass da password ativado');
      setState(() => _isLoading = true);

      // Simula um pequeno delay para mostrar o loading
      await Future.delayed(const Duration(milliseconds: 500));

      // Login automático como administrador em modo debug
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AlocacaoMedicos(
            unidade: widget.unidade,
            isAdmin: true, // Sempre administrador em debug
          ),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔧 Modo Debug: Login automático ativado'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final password = _passwordController.text.trim();
      bool isValid = false;
      bool isAdmin = false;

      print('🔐 Tentativa de login:');
      print('   - Primeira vez: $_isFirstTime');
      print('   - Lembrar password: $_lembrarPassword');
      print(
          '   - Password introduzida: ${password.isNotEmpty ? "Sim" : "Não"}');
      print('   - Unidade ID: ${widget.unidade.id}');

      // Só verifica passwords configuradas se for primeira vez E quiser lembrar
      if (_isFirstTime && _lembrarPassword) {
        final hasPasswords = await PasswordService.hasPasswordsConfigured(
            unidadeId: widget.unidade.id);
        print('   - Passwords configuradas: $hasPasswords');
        if (!hasPasswords) {
          // Se não há passwords configuradas, vai para a tela de seleção de unidades
          print(
              '   - Redirecionando para seleção de unidades (sem passwords configuradas)');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const SelecaoUnidadeScreen(),
            ),
          );
          return;
        }
      }

      // Verifica a password do projeto
      isValid = await PasswordService.verifyProjectPassword(password,
          unidadeId: widget.unidade.id);
      print('   - Password do projeto válida: $isValid');

      if (!isValid) {
        // Se não for a password do projeto, tenta a password do administrador
        isValid = await PasswordService.verifyAdminPassword(password,
            unidadeId: widget.unidade.id);
        if (isValid) {
          isAdmin = true;
          print('   - Password do administrador válida: $isValid');
        }
      }

      print('   - Login válido: $isValid');
      print('   - É administrador: $isAdmin');

      if (isValid) {
        // Guarda a preferência de lembrar password
        await PasswordService.setRememberPassword(_lembrarPassword);

        // Se "Lembrar password" estiver marcado, guarda a password
        if (_lembrarPassword) {
          if (isAdmin) {
            await PasswordService.saveAdminPassword(password,
                unidadeId: widget.unidade.id);
          } else {
            await PasswordService.saveProjectPassword(password,
                unidadeId: widget.unidade.id);
          }
          print('   - Password guardada para lembrar');
        } else {
          print('   - Password não guardada (não lembrar)');
        }

        // Login bem-sucedido - vai para a tela de alocação
        print('   - Redirecionando para tela de alocação');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AlocacaoMedicos(
              unidade: widget.unidade,
              isAdmin: isAdmin, // Passa informação se é administrador
            ),
          ),
        );

        // Mostra mensagem de boas-vindas
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isAdmin
                    ? 'Bem-vindo Administrador!'
                    : 'Bem-vindo à ${widget.unidade.nome}!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Password incorreta
        print('   - Password incorreta');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password incorreta. Tente novamente.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('   - Erro no login: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao fazer login: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Aceder a ${widget.unidade.nome}'),
        backgroundColor: MyAppTheme.azulEscuro,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Indicador de modo debug
                  if (kDebugMode)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bug_report, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'MODO DEBUG',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (kDebugMode) const SizedBox(height: 16),

                  // Logo/Ícone
                  Image.asset(
                    'images/am_icon.png',
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 32),

                  // Título
                  const Text(
                    'AlocMap',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: MyAppTheme.azulEscuro,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Nome da unidade
                  Text(
                    widget.unidade.nome,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtítulo
                  const Text(
                    'Digite a password para aceder ao sistema',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Container para reduzir largura do campo de password e botão em 30%
                  Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 420, // 70% de 600 (redução de 30%)
                      child: Column(
                        children: [
                          // Campo de password
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.lock),
                              hintText:
                                  'Digite a password do projeto ou administrador',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                              ),
                            ),
                            obscureText: !_showPassword,
                            validator: (value) {
                              if (kDebugMode) {
                                // Em modo debug, não valida a password
                                return null;
                              }
                              if (value == null || value.trim().isEmpty) {
                                return 'Digite a password';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 16),

                          // Checkbox "Lembrar password"
                          Row(
                            children: [
                              Checkbox(
                                value: _lembrarPassword,
                                onChanged: (value) {
                                  setState(() {
                                    _lembrarPassword = value ?? true;
                                  });
                                },
                                activeColor: MyAppTheme.azulEscuro,
                              ),
                              const Expanded(
                                child: Text(
                                  'Lembrar password neste dispositivo',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Botão de login
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MyAppTheme.azulEscuro,
                                foregroundColor: Colors.white,
                                // Aumento de 30% da altura: padding vertical de 16 -> 21 (16 * 1.3 ≈ 21)
                                padding:
                                    const EdgeInsets.symmetric(vertical: 21),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : Text(kDebugMode
                                      ? 'Entrar (Automático)'
                                      : 'Entrar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    kDebugMode
                        ? '🔧 Modo Debug: Login automático ativado\nNão é necessário introduzir password'
                        : 'Utilize a password do projeto para acesso normal\nou a password do administrador para acesso completo',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
