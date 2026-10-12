import '../models/gabinete.dart';
import '../models/medico.dart';
import '../models/serie_recorrencia.dart';
import '../models/matriz_distribuicao.dart';
import 'matriz_distribuicao_service.dart';

typedef MatrizVersoes = (int medicos, int gabinetes, int series);

/// Dados privados da matriz, separados dos objetos mutáveis das outras telas.
class MatrizDistribuicaoDados {
  final List<Gabinete> gabinetes;
  final List<Medico> _medicos;
  final List<SerieRecorrencia> _series;
  final Map<DateTime, MatrizDistribuicao> _matrizes = {};

  MatrizDistribuicaoDados({
    required List<Gabinete> gabinetes,
    required List<Medico> medicos,
    required List<SerieRecorrencia> series,
  })  : gabinetes = List.unmodifiable(
            gabinetes.map((g) => Gabinete.fromMap(g.toMap()))),
        _medicos = List.unmodifiable(medicos.map((m) => Medico(
              id: m.id,
              nome: m.nome,
              especialidade: m.especialidade,
              ativo: m.ativo,
              disponibilidades: const [],
            ))),
        _series = List.unmodifiable(series.map((s) => SerieRecorrencia(
              id: s.id,
              medicoId: s.medicoId,
              dataInicio: s.dataInicio,
              dataFim: s.dataFim,
              tipo: s.tipo,
              horarios: List.from(s.horarios),
              gabineteId: s.gabineteId,
              ativo: s.ativo,
              parametros: Map.from(s.parametros),
            )));

  MatrizDistribuicao matrizPara(DateTime referencia) {
    final dia = DateTime(referencia.year, referencia.month, referencia.day);
    final cached = _matrizes[dia];
    if (cached != null) return cached;
    final gerada = MatrizDistribuicaoService.gerar(
        medicos: _medicos, series: _series, referencia: dia);
    return _guardarMatriz(dia, gerada);
  }

  Future<MatrizDistribuicao> matrizParaProgressiva(DateTime referencia,
      {void Function(double)? onProgresso}) async {
    final dia = DateTime(referencia.year, referencia.month, referencia.day);
    final cached = _matrizes[dia];
    if (cached != null) {
      onProgresso?.call(1);
      return cached;
    }
    final gerada = await MatrizDistribuicaoService.gerarProgressivo(
        medicos: _medicos,
        series: _series,
        referencia: dia,
        onProgresso: onProgresso);
    return _guardarMatriz(dia, gerada);
  }

  MatrizDistribuicao _guardarMatriz(DateTime dia, MatrizDistribuicao gerada) {
    final matriz = MatrizDistribuicao(
      itens: List.unmodifiable(gerada.itens),
      regrasSemGabinete: List.unmodifiable(gerada.regrasSemGabinete),
    );
    // Limita a memória quando se consultam muitas datas diferentes.
    if (_matrizes.length >= 8) _matrizes.remove(_matrizes.keys.first);
    _matrizes[dia] = matriz;
    return matriz;
  }
}

/// Cache em memória; versões remotas são verificadas antes de reutilizar dados.
class MatrizDistribuicaoCacheService {
  static final _entradas = <String, (MatrizVersoes, MatrizDistribuicaoDados)>{};
  static final _revisoes = <String, int>{};
  static int _sequencia = 0;
  static int _revisaoGlobal = 0;

  static int revisao(String unidadeId) =>
      _revisoes[unidadeId] ?? _revisaoGlobal;

  static MatrizDistribuicaoDados? buscar(
      String unidadeId, MatrizVersoes versoes) {
    final entrada = _entradas[unidadeId];
    if (entrada == null) return null;
    if (entrada.$1 != versoes) {
      invalidar(unidadeId: unidadeId);
      return null;
    }
    return entrada.$2;
  }

  static void guardar(
      String unidadeId, MatrizVersoes versoes, MatrizDistribuicaoDados dados,
      {required int revisaoInicial}) {
    // Uma alteração durante o carregamento não pode repor uma cache antiga.
    if (revisao(unidadeId) != revisaoInicial) return;
    _entradas[unidadeId] = (versoes, dados);
  }

  static void invalidar({String? unidadeId}) {
    _sequencia++;
    if (unidadeId == null || unidadeId.isEmpty) {
      _entradas.clear();
      _revisoes.clear();
      _revisaoGlobal = _sequencia;
    } else {
      _entradas.remove(unidadeId);
      _revisoes[unidadeId] = _sequencia;
    }
  }
}
