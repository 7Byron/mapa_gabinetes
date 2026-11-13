import 'relatorio_horas_especialidade.dart';

/// Minutos efetivos por dia, já limitados à abertura e sem sobreposições.
class MedicoHorasMes {
  final String id;
  final String nome;
  final String especialidade;
  final List<int> minutos;

  MedicoHorasMes(
      {required this.id,
      required this.nome,
      required this.especialidade,
      required List<int> minutos})
      : minutos = List.unmodifiable(minutos);

  Map<String, Object> toMap() => {
        'id': id,
        'nome': nome,
        'especialidade': especialidade,
        'minutos': minutos
      };
}

class ResumoHorasMes {
  final DateTime mes;
  final List<MedicoHorasMes> medicos;

  ResumoHorasMes({required DateTime mes, required List<MedicoHorasMes> medicos})
      : mes = DateTime(mes.year, mes.month),
        medicos = List.unmodifiable(medicos);

  Map<String, Object> toMap() => {
        'ano': mes.year,
        'mes': mes.month,
        'medicos': medicos.map((m) => m.toMap()).toList()
      };

  factory ResumoHorasMes.fromMap(Map<String, dynamic> dados) {
    final ano = dados['ano'] as int, numero = dados['mes'] as int;
    if (ano < 1900 || ano > 2200 || numero < 1 || numero > 12) {
      throw const FormatException('Mês inválido na cache de horas.');
    }
    final dias = DateTime(ano, numero + 1, 0).day;
    final ids = <String>{};
    final medicos = (dados['medicos'] as List).map((valor) {
      final m = Map<String, dynamic>.from(valor as Map);
      final id = m['id'] as String;
      final minutos = (m['minutos'] as List).cast<int>();
      if (id.isEmpty ||
          !ids.add(id) ||
          minutos.length != dias ||
          minutos.any((n) => n < 0 || n > 1440)) {
        throw const FormatException('Minutos inválidos na cache de horas.');
      }
      return MedicoHorasMes(
          id: id,
          nome: m['nome'] as String,
          especialidade: m['especialidade'] as String,
          minutos: minutos);
    }).toList();
    return ResumoHorasMes(mes: DateTime(ano, numero), medicos: medicos);
  }

  /// Combina apenas os dias pedidos; semanas e períodos personalizados
  /// reutilizam os mesmos meses e mantêm o total global da clínica.
  static RelatorioHorasEspecialidade relatorio({
    required List<ResumoHorasMes> meses,
    required DateTime inicio,
    required DateTime fim,
    Set<String>? medicoIds,
    Set<String>? especialidades,
  }) {
    final porId = <String, MedicoHorasMes>{};
    final minutos = <String, int>{};
    for (final resumo in meses) {
      final de =
          resumo.mes.year == inicio.year && resumo.mes.month == inicio.month
              ? inicio.day
              : 1;
      final ate = resumo.mes.year == fim.year && resumo.mes.month == fim.month
          ? fim.day
          : DateTime(resumo.mes.year, resumo.mes.month + 1, 0).day;
      for (final medico in resumo.medicos) {
        porId[medico.id] = medico;
        var total = 0;
        for (var dia = de; dia <= ate; dia++) {
          total += medico.minutos[dia - 1];
        }
        minutos.update(medico.id, (n) => n + total, ifAbsent: () => total);
      }
    }
    if (medicoIds != null && !porId.keys.toSet().containsAll(medicoIds)) {
      throw StateError(
          'Um dos médicos selecionados já não está ativo nesta unidade.');
    }
    final todas = porId.values
        .map((m) => RelatorioHorasMedicoLinha(
            medicoId: m.id,
            nome: m.nome,
            especialidade: m.especialidade,
            horasConsulta: (minutos[m.id] ?? 0) / 60))
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
    final selecionadas = todas
        .where((m) => medicoIds != null
            ? medicoIds.contains(m.medicoId)
            : especialidades == null ||
                especialidades.contains(m.especialidade))
        .toList();
    // Os denominadores vêm de toda a clínica, antes dos filtros do relatório.
    // O detalhe mensal em cache já contém estes médicos: não há novas leituras.
    final gruposClinica = <String, List<RelatorioHorasMedicoLinha>>{};
    for (final medico in todas) {
      gruposClinica.putIfAbsent(medico.especialidade, () => []).add(medico);
    }
    final especialidadesClinica = {
      for (final grupo in gruposClinica.entries)
        grupo.key: RelatorioHorasEspecialidadeLinha(
          especialidade: grupo.key,
          medicosAtivos: grupo.value.length,
          medicosComDisponibilidade:
              grupo.value.where((m) => m.horasConsulta > 0).length,
          horasConsulta: grupo.value.fold(0.0, (n, m) => n + m.horasConsulta),
        ),
    };
    final grupos = <String, List<RelatorioHorasMedicoLinha>>{};
    for (final medico in selecionadas.where((m) => m.horasConsulta > 0)) {
      grupos.putIfAbsent(medico.especialidade, () => []).add(medico);
    }
    final linhas = grupos.entries
        .map((e) => RelatorioHorasEspecialidadeLinha(
            especialidade: e.key,
            medicosAtivos: e.value.length,
            medicosComDisponibilidade: e.value.length,
            horasConsulta: e.value.fold(0.0, (n, m) => n + m.horasConsulta)))
        .toList()
      ..sort((a, b) {
        final horas = b.horasConsulta.compareTo(a.horasConsulta);
        return horas == 0 ? a.especialidade.compareTo(b.especialidade) : horas;
      });
    return RelatorioHorasEspecialidade(
        inicio: inicio,
        fim: fim,
        linhas: linhas,
        medicos: medicoIds == null ? const [] : selecionadas,
        totalHorasConsultaClinica: minutos.values.fold(0, (a, b) => a + b) / 60,
        totalMedicosAtivosClinica: todas.length,
        especialidadesClinica: Map.unmodifiable(especialidadesClinica),
        especialidadesSelecionadas: especialidades?.toList() ?? const []);
  }
}
