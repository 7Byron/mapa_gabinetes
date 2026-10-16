class MatrizDistribuicaoItem {
  final String serieId;
  final String medicoId;
  final String medicoNome;
  final String especialidade;
  final String gabineteId;
  final String tipo;
  final String ciclo;
  final int dia;
  final int inicioMinutos;
  final int fimMinutos;
  final bool conflito;
  final DateTime? validadeInicio;
  final DateTime? validadeFim;
  final Set<DateTime> ocorrencias;

  const MatrizDistribuicaoItem({
    required this.serieId,
    required this.medicoId,
    required this.medicoNome,
    required this.especialidade,
    required this.gabineteId,
    required this.tipo,
    required this.ciclo,
    required this.dia,
    required this.inicioMinutos,
    required this.fimMinutos,
    this.conflito = false,
    this.validadeInicio,
    this.validadeFim,
    this.ocorrencias = const {},
  });

  String? get periodo {
    final inicio = validadeInicio;
    final fim = validadeFim;
    if (inicio == null || fim == null) return null;
    // A projeção anual já limita a validade ao ano selecionado. Mostrar
    // datas apenas nos segmentos que não abrangem o ano completo.
    final anoCompleto = inicio.year == fim.year &&
        inicio.month == 1 &&
        inicio.day == 1 &&
        fim.month == 12 &&
        fim.day == 31;
    if (anoCompleto) return null;
    return 'De ${_data(inicio)} a ${_data(fim)}';
  }

  static String _data(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

  String get horario => '${_hora(inicioMinutos)} – ${_hora(fimMinutos)}';
  static String _hora(int minutos) =>
      '${(minutos ~/ 60).toString().padLeft(2, '0')}:${(minutos % 60).toString().padLeft(2, '0')}';

  MatrizDistribuicaoItem comConflito() => MatrizDistribuicaoItem(
        serieId: serieId,
        medicoId: medicoId,
        medicoNome: medicoNome,
        especialidade: especialidade,
        gabineteId: gabineteId,
        tipo: tipo,
        ciclo: ciclo,
        dia: dia,
        inicioMinutos: inicioMinutos,
        fimMinutos: fimMinutos,
        conflito: true,
        validadeInicio: validadeInicio,
        validadeFim: validadeFim,
        ocorrencias: ocorrencias,
      );
}

class MatrizDistribuicao {
  final List<MatrizDistribuicaoItem> itens;
  final List<String> regrasSemGabinete;

  const MatrizDistribuicao(
      {required this.itens, required this.regrasSemGabinete});
}
