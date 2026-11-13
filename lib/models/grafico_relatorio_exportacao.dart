import 'relatorio_horas_especialidade.dart';

sealed class GraficoRelatorioExportacao {
  const GraficoRelatorioExportacao();
}

class GraficoHorasEspecialidadeExportacao extends GraficoRelatorioExportacao {
  final List<RelatorioHorasEspecialidadeLinha> linhas;
  final int totalMedicosAtivosClinica;

  const GraficoHorasEspecialidadeExportacao({
    required this.linhas,
    required this.totalMedicosAtivosClinica,
  });
}

class GraficoHorasMedicoExportacao extends GraficoRelatorioExportacao {
  final RelatorioHorasEspecialidade relatorio;

  const GraficoHorasMedicoExportacao(this.relatorio);
}

class TaxaGraficoExportacao {
  final String titulo;
  final String descricao;
  final double horasOcupadas;
  final double horasDisponiveis;

  const TaxaGraficoExportacao({
    required this.titulo,
    required this.descricao,
    required this.horasOcupadas,
    required this.horasDisponiveis,
  });

  double get percentagem =>
      horasDisponiveis > 0 ? horasOcupadas / horasDisponiveis * 100 : 0;
}

class GraficoTaxasExportacao extends GraficoRelatorioExportacao {
  final List<TaxaGraficoExportacao> taxas;

  const GraficoTaxasExportacao(this.taxas);
}

class IntervaloGraficoExportacao {
  final int inicio;
  final int fim;

  const IntervaloGraficoExportacao(this.inicio, this.fim);
}

class DiaGraficoExportacao {
  final DateTime data;
  final double horasOcupadas;
  final double horasDisponiveis;
  final List<IntervaloGraficoExportacao> intervalos;
  final int inicioMinutos;
  final int fimMinutos;

  const DiaGraficoExportacao({
    required this.data,
    required this.horasOcupadas,
    required this.horasDisponiveis,
    this.intervalos = const [],
    this.inicioMinutos = 0,
    this.fimMinutos = 24 * 60,
  });

  double get percentagem =>
      horasDisponiveis > 0 ? horasOcupadas / horasDisponiveis * 100 : 0;
}

class GraficoOcupacaoExportacao extends GraficoRelatorioExportacao {
  final bool porHora;
  final List<DiaGraficoExportacao> dias;

  const GraficoOcupacaoExportacao({required this.porHora, required this.dias});
}
