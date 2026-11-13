import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/disponibilidade.dart';
import 'package:mapa_gabinetes/models/excecao_serie.dart';
import 'package:mapa_gabinetes/models/serie_recorrencia.dart';
import 'package:mapa_gabinetes/services/relatorio_horas_disponibilidades_service.dart';

void main() {
  test('Uma semana lê só os registos do período, mantendo as exceções da série',
      () async {
    final db = FakeFirebaseFirestore();
    final medico = db.doc('unidades/u/ocupantes/ana');
    final serie = SerieRecorrencia(
        id: 's',
        medicoId: 'ana',
        dataInicio: DateTime(2026, 1, 5),
        tipo: 'Semanal',
        horarios: ['08:00', '12:00']);
    await medico.collection('series').doc('s').set(serie.toMap());
    final loteUnicas = db.batch();
    final loteExcecoes = db.batch();
    for (var i = 0; i < 365; i++) {
      final data = DateTime(2026, 1, i + 1);
      loteUnicas.set(
          medico
              .collection('disponibilidades')
              .doc('2026')
              .collection('registos')
              .doc('$i'),
          Disponibilidade(
                  id: '$i',
                  medicoId: 'ana',
                  data: data,
                  horarios: ['14:00', '15:00'],
                  tipo: 'Única')
              .toMap());
      loteExcecoes.set(
          medico
              .collection('excecoes')
              .doc('2026')
              .collection('registos')
              .doc('$i'),
          ExcecaoSerie(
              id: '$i',
              serieId: 's',
              data: data,
              horarios: ['09:00', '11:00']).toMap());
    }
    await loteUnicas.commit();
    await loteExcecoes.commit();
    final lidas = <String, int>{};
    final resultado = await RelatorioHorasDisponibilidadesService.carregar(
      firestore: db,
      unidadeId: 'u',
      medicoId: 'ana',
      inicio: DateTime(2026, 11, 9),
      fim: DateTime(2026, 11, 15),
      onLeitura: (colecao, documentos) => lidas
          .update(colecao, (n) => n + documentos, ifAbsent: () => documentos),
    );
    expect(lidas, {'series': 1, 'disponibilidades': 7, 'excecoes': 7});
    expect(resultado.where((d) => d.tipo == 'Única').length, 7);
    expect(resultado.where((d) => d.tipo != 'Única').single.horarios,
        ['09:00', '11:00']);
    expect(
        resultado.every(
            (d) => d.data.month == 11 && d.data.day >= 9 && d.data.day <= 15),
        isTrue);
  });

  test(
      'Inclui o último dia com horas e não consulta exceções quando não há séries',
      () async {
    final db = FakeFirebaseFirestore();
    final medico = db.doc('unidades/u/ocupantes/ana');
    for (final data in [
      DateTime(2026, 12, 30),
      DateTime(2026, 12, 31, 23, 59),
      DateTime(2027, 1, 1, 18),
      DateTime(2027, 1, 2)
    ]) {
      await medico
          .collection('disponibilidades')
          .doc('${data.year}')
          .collection('registos')
          .doc('${data.month}-${data.day}')
          .set(Disponibilidade(
                  id: '${data.month}-${data.day}',
                  medicoId: 'ana',
                  data: data,
                  horarios: ['08:00', '09:00'],
                  tipo: 'Única')
              .toMap());
    }
    final leituras = <String>[];
    final resultado = await RelatorioHorasDisponibilidadesService.carregar(
      firestore: db,
      unidadeId: 'u',
      medicoId: 'ana',
      inicio: DateTime(2026, 12, 31),
      fim: DateTime(2027, 1, 1),
      onLeitura: (colecao, _) => leituras.add(colecao),
    );
    expect(resultado.length, 2);
    expect(resultado.map((d) => d.data),
        [DateTime(2026, 12, 31, 23, 59), DateTime(2027, 1, 1, 18)]);
    expect(leituras.where((c) => c == 'excecoes'), isEmpty);
    expect(leituras.where((c) => c == 'disponibilidades').length, 2);
    final outraUnidade = await RelatorioHorasDisponibilidadesService.carregar(
        firestore: db,
        unidadeId: 'outra',
        medicoId: 'ana',
        inicio: DateTime(2026, 12, 31),
        fim: DateTime(2027, 1, 1));
    expect(outraUnidade, isEmpty);
  });
}
