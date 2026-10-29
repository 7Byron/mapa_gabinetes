import 'package:flutter/material.dart';
import '../models/unidade.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/relatorio_layout.dart';
import '../utils/app_colors.dart';
import 'cadastro_unidade_screen.dart';
import 'config_clinica_screen.dart';
import 'dias_encerramento_screen.dart';

class ConfiguracoesScreen extends StatefulWidget {
  final Unidade unidade;
  final bool destacarHorarios;

  const ConfiguracoesScreen({
    super.key,
    required this.unidade,
    this.destacarHorarios = false,
  });

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  int? _selecionado;
  final _visitados = <int>{};

  @override
  Widget build(BuildContext context) {
    const opcoes = [
      ('Configurar Unidade', Icons.settings_applications),
      ('Configurar Horários', Icons.schedule),
      ('Dias de Encerramento', Icons.event_busy),
    ];
    Widget pagina(int? indice) => switch (indice) {
          0 => CadastroUnidadeScreen(
              unidade: widget.unidade,
              confirmarAoAtualizar: true,
              incorporado: true,
            ),
          1 => ConfigClinicaScreen(unidade: widget.unidade, incorporado: true),
          2 =>
            DiasEncerramentoScreen(unidade: widget.unidade, incorporado: true),
          _ => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Selecione uma opção no menu à esquerda.',
                    textAlign: TextAlign.center),
              ),
            ),
        };
    return Scaffold(
      appBar: const CustomAppBar(title: 'Configurações'),
      body: RelatorioLayout(
        filtros: [
          for (var i = 0; i < opcoes.length; i++)
            ListTile(
              key: ValueKey('configuracoes_opcao_$i'),
              leading: Icon(opcoes[i].$2),
              title: Text(opcoes[i].$1, style: const TextStyle(fontSize: 14)),
              selected: _selecionado == i,
              trailing: i == 1 && widget.destacarHorarios
                  ? const Icon(Icons.arrow_back, color: AppColors.menta)
                  : null,
              onTap: () => setState(() {
                _visitados.add(i);
                _selecionado = i;
              }),
            ),
        ],
        resultado: IndexedStack(
          index: _selecionado ?? 3,
          children: [
            for (var i = 0; i < opcoes.length; i++)
              _visitados.contains(i) ? pagina(i) : const SizedBox.shrink(),
            pagina(null),
          ],
        ),
      ),
    );
  }
}
