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
  });

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
      );
}

class MatrizDistribuicao {
  final List<MatrizDistribuicaoItem> itens;
  final List<String> regrasSemGabinete;

  const MatrizDistribuicao(
      {required this.itens, required this.regrasSemGabinete});
}
