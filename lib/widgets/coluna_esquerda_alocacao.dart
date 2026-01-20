import 'package:flutter/material.dart';
import '../models/gabinete.dart';
import '../utils/app_theme.dart';
import '../utils/alocacao_medicos_logic.dart' as logic;
import '../widgets/calendario_disponibilidades.dart';
import '../widgets/filtros_section.dart';
import '../widgets/pesquisa_section.dart';

class ColunaEsquerdaAlocacao extends StatelessWidget {
  final DateTime selectedDate;
  final List<Gabinete> gabinetes;
  final List<String> pisosSelecionados;
  final String? pesquisaNome;
  final String? pesquisaEspecialidade;
  final String filtroOcupacao;
  final bool mostrarConflitos;
  final String? filtroEspecialidadeGabinete;
  final List<String> opcoesNome;
  final List<String> opcoesEspecialidade;
  final List<String> especialidadesGabinetes;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onViewChanged;
  final ValueChanged<String?> onPesquisaNomeChanged;
  final ValueChanged<String?> onPesquisaEspecialidadeChanged;
  final VoidCallback onLimparPesquisa;
  final void Function(String setor, bool isSelected) onTogglePiso;
  final ValueChanged<String> onFiltroOcupacaoChanged;
  final ValueChanged<bool> onMostrarConflitosChanged;
  final ValueChanged<String?> onFiltroEspecialidadeGabineteChanged;

  const ColunaEsquerdaAlocacao({
    super.key,
    required this.selectedDate,
    required this.gabinetes,
    required this.pisosSelecionados,
    required this.pesquisaNome,
    required this.pesquisaEspecialidade,
    required this.filtroOcupacao,
    required this.mostrarConflitos,
    required this.filtroEspecialidadeGabinete,
    required this.opcoesNome,
    required this.opcoesEspecialidade,
    required this.especialidadesGabinetes,
    required this.onDateSelected,
    required this.onViewChanged,
    required this.onPesquisaNomeChanged,
    required this.onPesquisaEspecialidadeChanged,
    required this.onLimparPesquisa,
    required this.onTogglePiso,
    required this.onFiltroOcupacaoChanged,
    required this.onMostrarConflitosChanged,
    required this.onFiltroEspecialidadeGabineteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Column(
        children: [
          CalendarioDisponibilidades(
            diasSelecionados: [selectedDate],
            onAdicionarData: (date, tipo) {},
            onRemoverData: (date, removeSerie) {},
            dataCalendario: selectedDate,
            modoApenasSelecao: true,
            onDateSelected: (date) {
              final dataNormalizada = DateTime(date.year, date.month, date.day);
              logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
              onDateSelected(date);
            },
            onViewChanged: onViewChanged,
          ),
          PesquisaSection(
            pesquisaNome: pesquisaNome,
            pesquisaEspecialidade: pesquisaEspecialidade,
            opcoesNome: opcoesNome,
            opcoesEspecialidade: opcoesEspecialidade,
            onPesquisaNomeChanged: onPesquisaNomeChanged,
            onPesquisaEspecialidadeChanged: onPesquisaEspecialidadeChanged,
            onLimparPesquisa: onLimparPesquisa,
          ),
          Container(
            decoration: BoxDecoration(
              color: MyAppTheme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 2,
              ),
              boxShadow: MyAppTheme.shadowCard3D,
            ),
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.none,
            child: FiltrosSection(
              todosSetores: gabinetes.map((g) => g.setor).toSet().toList(),
              pisosSelecionados: pisosSelecionados,
              onTogglePiso: onTogglePiso,
              filtroOcupacao: filtroOcupacao,
              onFiltroOcupacaoChanged: onFiltroOcupacaoChanged,
              mostrarConflitos: mostrarConflitos,
              onMostrarConflitosChanged: onMostrarConflitosChanged,
              filtroEspecialidadeGabinete: filtroEspecialidadeGabinete,
              onFiltroEspecialidadeGabineteChanged:
                  onFiltroEspecialidadeGabineteChanged,
              especialidadesGabinetes: especialidadesGabinetes,
            ),
          ),
        ],
      ),
    );
  }
}
