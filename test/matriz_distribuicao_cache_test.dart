import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/gabinete.dart';
import 'package:mapa_gabinetes/models/medico.dart';
import 'package:mapa_gabinetes/models/serie_recorrencia.dart';
import 'package:mapa_gabinetes/services/matriz_distribuicao_cache_service.dart';
import 'package:mapa_gabinetes/services/gabinete_service.dart';
import 'package:mapa_gabinetes/services/medico_salvar_service.dart';
import 'package:mapa_gabinetes/models/unidade.dart';
import 'package:mapa_gabinetes/services/serie_service.dart';

void main() {
  const versoes = (1, 2, 3);
  final referencia = DateTime(2026, 2, 2);
  late Gabinete gabinete;
  late Medico medico;
  late SerieRecorrencia serie;
  late MatrizDistribuicaoDados dados;
  final unidade = Unidade(
      id: 'a',
      nome: 'A',
      tipo: 'Clínica',
      endereco: '',
      dataCriacao: DateTime(2026),
      nomeOcupantes: 'Médicos',
      nomeAlocacao: 'Gabinetes');

  setUp(() {
    MatrizDistribuicaoCacheService.invalidar();
    gabinete = Gabinete(
        id: '101', setor: 'Piso 1', nome: '101', especialidadesPermitidas: []);
    medico = Medico(
        id: 'm', nome: 'Maria', especialidade: 'ORL', disponibilidades: []);
    serie = SerieRecorrencia(
        id: 's',
        medicoId: 'm',
        dataInicio: DateTime(2026, 1, 5),
        tipo: 'Quinzenal',
        horarios: ['08:00', '12:00'],
        gabineteId: '101');
    dados = MatrizDistribuicaoDados(
        gabinetes: [gabinete], medicos: [medico], series: [serie]);
  });

  void guardar(String unidadeId) =>
      MatrizDistribuicaoCacheService.guardar(unidadeId, versoes, dados,
          revisaoInicial: MatrizDistribuicaoCacheService.revisao(unidadeId));

  test('Reabrir com as mesmas versões reutiliza dados e matriz calculada', () {
    guardar('a');
    final matriz = dados.matrizPara(referencia);
    final cached = MatrizDistribuicaoCacheService.buscar('a', versoes)!;
    expect(cached, same(dados));
    expect(cached.matrizPara(DateTime(2026, 2, 2, 18)), same(matriz));
  });

  for (final alteradas in [(2, 2, 3), (1, 3, 3), (1, 2, 4)]) {
    test('Versões $alteradas invalidam apenas a unidade alterada', () {
      guardar('a');
      guardar('b');
      expect(MatrizDistribuicaoCacheService.buscar('a', alteradas), isNull);
      expect(MatrizDistribuicaoCacheService.buscar('b', versoes), same(dados));
    });
  }

  test('Mudança de referência mantém dados mas recalcula fase quinzenal', () {
    guardar('a');
    final primeira = dados.matrizPara(referencia);
    final segunda = dados.matrizPara(DateTime(2026, 2, 9));
    expect(primeira.itens.map((i) => i.dia), [1, 15, 29]);
    expect(segunda.itens.map((i) => i.dia), [8, 22]);
    expect(dados.matrizPara(referencia), same(primeira));
    expect(MatrizDistribuicaoCacheService.buscar('a', versoes), same(dados));
  });

  test('Snapshot não muda quando outros ecrãs alteram os objetos originais',
      () {
    gabinete.nome = 'Novo gabinete';
    medico.nome = 'Outro nome';
    serie.horarios[0] = '10:00';
    serie.gabineteId = '202';
    serie.tipo = 'Semanal';
    final matriz = dados.matrizPara(referencia);
    expect(dados.gabinetes.single.nome, '101');
    expect(matriz.itens.first.medicoNome, 'Maria');
    expect(matriz.itens.first.gabineteId, '101');
    expect(matriz.itens.first.inicioMinutos, 480);
    expect(matriz.itens.length, 3);
  });

  test('Matriz vazia também fica em cache', () {
    final vazios =
        MatrizDistribuicaoDados(gabinetes: [], medicos: [], series: []);
    MatrizDistribuicaoCacheService.guardar('a', versoes, vazios,
        revisaoInicial: MatrizDistribuicaoCacheService.revisao('a'));
    expect(MatrizDistribuicaoCacheService.buscar('a', versoes), same(vazios));
    expect(vazios.matrizPara(referencia).itens, isEmpty);
    expect(vazios.matrizPara(referencia), same(vazios.matrizPara(referencia)));
  });

  test('Invalidação durante carga impede repor dados antigos', () {
    final inicio = MatrizDistribuicaoCacheService.revisao('a');
    MatrizDistribuicaoCacheService.invalidar(unidadeId: 'a');
    MatrizDistribuicaoCacheService.guardar('a', versoes, dados,
        revisaoInicial: inicio);
    expect(MatrizDistribuicaoCacheService.buscar('a', versoes), isNull);
    guardar('a');
    expect(MatrizDistribuicaoCacheService.buscar('a', versoes), same(dados));
  });

  test('Limpar caches de médicos e gabinetes também invalida a matriz', () {
    guardar('a');
    limparCacheMedicos(unidade: unidade);
    expect(MatrizDistribuicaoCacheService.buscar('a', versoes), isNull);
    guardar('a');
    limparCacheGabinetes(unidade: unidade);
    expect(MatrizDistribuicaoCacheService.buscar('a', versoes), isNull);
  });

  test('Alterar uma série invalida a matriz da respetiva unidade', () {
    guardar('a');
    guardar('b');
    SerieService.invalidateCacheSeries('a', 'm');
    expect(MatrizDistribuicaoCacheService.buscar('a', versoes), isNull);
    expect(MatrizDistribuicaoCacheService.buscar('b', versoes), same(dados));
  });

  test('Limpeza global invalida cargas pendentes e todas as unidades', () {
    guardar('a');
    guardar('b');
    final inicio = MatrizDistribuicaoCacheService.revisao('a');
    MatrizDistribuicaoCacheService.invalidar();
    MatrizDistribuicaoCacheService.guardar('a', versoes, dados,
        revisaoInicial: inicio);
    expect(MatrizDistribuicaoCacheService.buscar('a', versoes), isNull);
    expect(MatrizDistribuicaoCacheService.buscar('b', versoes), isNull);
  });
  test('Via progressiva usa a mesma cache e comunica conclusão', () async {
    final primeira = await dados.matrizParaProgressiva(referencia);
    final progresso = <double>[];
    final segunda = await dados.matrizParaProgressiva(referencia,
        onProgresso: progresso.add);
    expect(segunda, same(primeira));
    expect(dados.matrizPara(referencia), same(primeira));
    expect(progresso, [1]);
  });
}
