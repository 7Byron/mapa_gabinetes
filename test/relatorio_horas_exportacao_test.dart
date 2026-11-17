import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/dados_relatorio_exportacao.dart';
import 'package:mapa_gabinetes/models/grafico_relatorio_exportacao.dart';
import 'package:mapa_gabinetes/models/relatorio_horas_especialidade.dart';
import 'package:mapa_gabinetes/services/relatorio_graficos_exportacao_service.dart';
import 'package:mapa_gabinetes/services/relatorio_exportacao_service.dart';
import 'package:mapa_gabinetes/services/relatorio_horas_exportacao_service.dart';
import 'package:mapa_gabinetes/utils/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fontes = FontLoader('Montserrat')
      ..addFont(rootBundle.load('fonts/Montserrat-Regular.ttf'))
      ..addFont(rootBundle.load('fonts/Montserrat-Bold.ttf'));
    await fontes.load();
  });

  RelatorioHorasEspecialidade relatorio({int quantidade = 2}) =>
      RelatorioHorasEspecialidade(
        inicio: DateTime(2026, 11, 1),
        fim: DateTime(2026, 11, 30),
        especialidadesSelecionadas: const [
          'Cardiologia',
          'Sem disponibilidade'
        ],
        linhas: [
          for (var i = 0; i < quantidade; i++)
            RelatorioHorasEspecialidadeLinha(
              especialidade: 'Especialidade $i com uma designação comprida',
              medicosAtivos: 2,
              medicosComDisponibilidade: 2,
              horasConsulta: 7.5,
            ),
        ],
      );

  test('Imagem por especialidade separa gráficos e tabela em horizontal',
      () async {
    final relatorio = RelatorioHorasEspecialidade(
      inicio: DateTime(2026, 11, 1),
      fim: DateTime(2026, 11, 30),
      totalMedicosAtivosClinica: 60,
      especialidadesSelecionadas: const ['MGF', 'ORL', 'Sem disponibilidade'],
      linhas: const [
        RelatorioHorasEspecialidadeLinha(
            especialidade: 'MGF',
            medicosAtivos: 15,
            medicosComDisponibilidade: 15,
            horasConsulta: 103.5),
        RelatorioHorasEspecialidadeLinha(
            especialidade: 'ORL',
            medicosAtivos: 3,
            medicosComDisponibilidade: 3,
            horasConsulta: 7.5),
      ],
    );
    final exportacao = RelatorioHorasExportacaoDados(relatorio);
    final dados =
        exportacao.documento('Clínica São João', incluirGraficos: true);
    final grafico =
        dados.graficos.single as GraficoHorasEspecialidadeExportacao;
    expect(grafico.totalMedicosAtivosClinica, 60);
    expect(grafico.linhas.first.medicosComDisponibilidade, 15);
    expect(grafico.linhas.first.horasConsulta, 103.5);
    expect(grafico.linhas.first.mediaHorasPorMedico, 6.9);
    expect(dados.detalhes.last, contains('Sem disponibilidade'));
    expect(exportacao.documento('Clínica').graficos, isEmpty);
    expect(dados.linhas.last, ['Total', 18, 18, 111.0, '']);

    for (final conteudo in [
      ConteudoImagemRelatorio.grafico,
      ConteudoImagemRelatorio.tabela
    ]) {
      final png = await RelatorioHorasExportacaoService.gerarImagem(
          unidade: 'Clínica São João',
          relatorio: relatorio,
          conteudo: conteudo,
          horizontal: true);
      final codec = await ui.instantiateImageCodec(png);
      final imagem = (await codec.getNextFrame()).image;
      try {
        expect(imagem.width, 2400);
        expect(imagem.width, greaterThan(imagem.height));
        final pixels = (await imagem.toByteData())!.buffer.asUint8List();
        final cor = MyAppTheme.corOcupacao(25).toARGB32() & 0xffffff;
        var encontrados = 0;
        for (var i = 0; i < pixels.length; i += 4) {
          if ((pixels[i] << 16 | pixels[i + 1] << 8 | pixels[i + 2]) == cor) {
            encontrados++;
          }
        }
        expect(
            encontrados,
            conteudo == ConteudoImagemRelatorio.grafico
                ? greaterThan(1000)
                : 0);
      } finally {
        imagem.dispose();
        codec.dispose();
      }
      final destino = Platform.environment['RELATORIO_PREVIEW_DIR'];
      if (destino != null) {
        await File('$destino/horas_especialidade_${conteudo.name}.png')
            .writeAsBytes(png);
      }
    }
    final pdf = latin1.decode(await RelatorioHorasExportacaoService.gerarPdf(
        unidade: 'Clínica', relatorio: relatorio));
    expect(RegExp(r'/Subtype\s*/Image\b').hasMatch(pdf), isFalse);
  });

  test('Gráficos aproveitam página vertical por especialidade e por médico',
      () async {
    final especialidades =
        RelatorioHorasExportacaoDados(relatorio(quantidade: 9))
            .documento('Clínica', incluirGraficos: true);
    final raw =
        await RelatorioGraficosExportacaoService.gerar(especialidades.graficos);
    expect(raw, hasLength(1));
    final codec = await ui.instantiateImageCodec(raw.single.bytes);
    final imagem = (await codec.getNextFrame()).image;
    expect(imagem.height, 1500);
    imagem.dispose();
    codec.dispose();
    final medicos = RelatorioHorasEspecialidade(
      inicio: DateTime(2026, 11),
      fim: DateTime(2026, 11, 30),
      linhas: const [],
      totalMedicosAtivosClinica: 10,
      totalHorasConsultaClinica: 100,
      medicos: [
        for (var i = 0; i < 10; i++)
          RelatorioHorasMedicoLinha(
              medicoId: '$i',
              nome: 'Médico $i',
              especialidade: 'MGF',
              horasConsulta: 10)
      ],
    );
    final dadosMedicos = RelatorioHorasExportacaoDados(medicos)
        .documento('Clínica', incluirGraficos: true);
    final rawMedicos =
        await RelatorioGraficosExportacaoService.gerar(dadosMedicos.graficos);
    expect(rawMedicos, hasLength(2));
    final codecMedicos = await ui.instantiateImageCodec(rawMedicos.first.bytes);
    final imgMedicos = (await codecMedicos.getNextFrame()).image;
    expect(imgMedicos.height, 1460);
    imgMedicos.dispose();
    codecMedicos.dispose();
    for (final dados in [especialidades, dadosMedicos]) {
      final imagens = await RelatorioExportacaoService.gerarImagensPaginadas(
          dados,
          conteudo: ConteudoImagemRelatorio.grafico);
      expect(imagens.length, identical(dados, especialidades) ? 1 : 2);
      final bytesPdf = await RelatorioExportacaoService.gerarPdf(
          dados: dados, portrait: true);
      final texto = latin1.decode(bytesPdf);
      expect(RegExp(r'/Subtype\s*/Image\b').allMatches(texto).length,
          greaterThanOrEqualTo(imagens.length));
      final caixa = RegExp(r'/MediaBox\s*\[0\s+0\s+([\d.]+)\s+([\d.]+)\]')
          .firstMatch(texto)!;
      expect(double.parse(caixa.group(2)!),
          greaterThan(double.parse(caixa.group(1)!)));
      final destino = Platform.environment['HORAS_PAGINA_PREVIEW'];
      if (destino != null) {
        await File(
                '${destino}_${identical(dados, especialidades) ? 'especialidades' : 'medicos'}.png')
            .writeAsBytes(imagens.first);
      }
    }
  });

  test('Gráficos incluem todas as especialidades e suportam relatório vazio',
      () async {
    final dados = RelatorioHorasExportacaoDados(relatorio(quantidade: 4))
        .documento('Clínica', incluirGraficos: true);
    final imagens =
        await RelatorioGraficosExportacaoService.gerar(dados.graficos);
    expect(imagens.length, 1);
    final png = await RelatorioHorasExportacaoService.gerarImagem(
        unidade: 'Clínica',
        relatorio: relatorio(quantidade: 4),
        conteudo: ConteudoImagemRelatorio.grafico,
        horizontal: true);
    final codec = await ui.instantiateImageCodec(png);
    final imagem = (await codec.getNextFrame()).image;
    expect(imagem.width, 2400);
    expect(imagem.width, greaterThan(imagem.height));
    imagem.dispose();
    codec.dispose();
    final vazio = await RelatorioHorasExportacaoService.gerarImagem(
        unidade: 'Clínica',
        relatorio: relatorio(quantidade: 0),
        conteudo: ConteudoImagemRelatorio.grafico,
        horizontal: true);
    expect(vazio.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });

  test('Exportação inclui os filtros mesmo sem disponibilidade', () {
    final dados = RelatorioHorasExportacaoDados(relatorio());
    expect(dados.filtros, 'Cardiologia, Sem disponibilidade');
    expect(dados.linhasFormatadas.last, ['Total', '4', '4', '15', '']);
    expect(dados.linhasFormatadas.first[3], '7,5');
    expect(dados.linhasFormatadas.first[4], '3,75');
  });

  test('Gráfico por médico usa o total da clínica e a média de todos os ativos',
      () async {
    final relatorio = RelatorioHorasEspecialidade(
      inicio: DateTime(2026, 11, 1),
      fim: DateTime(2026, 11, 30),
      linhas: const [],
      totalHorasConsultaClinica: 200,
      totalMedicosAtivosClinica: 10,
      especialidadesClinica: const {
        'Cardiologia': RelatorioHorasEspecialidadeLinha(
            especialidade: 'Cardiologia',
            medicosAtivos: 4,
            medicosComDisponibilidade: 3,
            horasConsulta: 80),
        'ORL': RelatorioHorasEspecialidadeLinha(
            especialidade: 'ORL',
            medicosAtivos: 6,
            medicosComDisponibilidade: 4,
            horasConsulta: 120),
      },
      medicos: const [
        RelatorioHorasMedicoLinha(
            medicoId: 'ana',
            nome: 'Ana João',
            especialidade: 'Cardiologia',
            horasConsulta: 20),
        RelatorioHorasMedicoLinha(
            medicoId: 'rui',
            nome: 'Rui Silva',
            especialidade: 'ORL',
            horasConsulta: 40),
      ],
    );
    final dados = RelatorioHorasExportacaoDados(relatorio)
        .documento('Clínica', incluirGraficos: true);
    final grafico = dados.graficos.single as GraficoHorasMedicoExportacao;
    expect(grafico.relatorio.totalHorasConsultaClinica, 200);
    expect(grafico.relatorio.totalHorasConsulta, 60);
    expect(grafico.relatorio.medicos.first.percentagemContribuicao(200), 10);
    expect(grafico.relatorio.mediaHorasPorMedicoClinica, 20);
    expect(
        grafico.relatorio.especialidadesClinica['Cardiologia']!.horasConsulta,
        80);
    expect(
        grafico.relatorio.especialidadesClinica['Cardiologia']!
            .mediaHorasPorMedicoAtivo,
        20);
    expect(dados.detalhes, contains('Total de horas da clínica: 200 h'));
    expect(dados.detalhes.last,
        'Média dos 10 médicos ativos (incluindo zero horas): 20 h');
    final png = await RelatorioHorasExportacaoService.gerarImagem(
        unidade: 'Clínica São João',
        relatorio: relatorio,
        conteudo: ConteudoImagemRelatorio.grafico,
        horizontal: true);
    final codec = await ui.instantiateImageCodec(png);
    final imagem = (await codec.getNextFrame()).image;
    try {
      expect(imagem.width, 2400);
      expect(imagem.width, greaterThan(imagem.height));
      final pixels = (await imagem.toByteData())!.buffer.asUint8List();
      final cores = {
        MyAppTheme.corOcupacao(10).toARGB32() & 0xffffff: 0,
        0x287c70: 0,
      };
      for (var i = 0; i < pixels.length; i += 4) {
        final cor = pixels[i] << 16 | pixels[i + 1] << 8 | pixels[i + 2];
        if (cores.containsKey(cor)) {
          cores[cor] = cores[cor]! + 1;
        }
      }
      for (final encontrados in cores.values) {
        expect(encontrados, greaterThan(1000),
            reason:
                'A imagem inclui os gráficos da clínica e da especialidade');
      }
    } finally {
      imagem.dispose();
      codec.dispose();
    }
    final destino = Platform.environment['RELATORIO_PREVIEW_DIR'];
    if (destino != null) {
      await File('$destino/horas_medico_contribuicao.png').writeAsBytes(png);
    }
  });

  test('PDF pagina relatórios extensos sem perder linhas', () async {
    final bytes = await RelatorioHorasExportacaoService.gerarPdf(
        unidade: 'Clínica São João', relatorio: relatorio(quantidade: 80));
    final conteudo = latin1.decode(bytes);
    expect(conteudo.startsWith('%PDF-'), isTrue);
    expect(
        RegExp(r'/Type\s*/Page\b').allMatches(conteudo).length, greaterThan(1));
    // Artefactos opcionais para inspeção visual local.
    final destino = Platform.environment['RELATORIO_PREVIEW_DIR'];
    if (destino != null) await File('$destino/horas.pdf').writeAsBytes(bytes);
  });

  test('Imagem PNG contém a altura de todo o relatório', () async {
    final bytes = await RelatorioHorasExportacaoService.gerarImagem(
        unidade: 'Clínica São João', relatorio: relatorio(quantidade: 38));
    expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 1600);
    expect(frame.image.height, greaterThan(3000));
    frame.image.dispose();
    codec.dispose();
    final destino = Platform.environment['RELATORIO_PREVIEW_DIR'];
    if (destino != null) await File('$destino/horas.png').writeAsBytes(bytes);
  });

  for (final horas in [0.0, 7.5]) {
    test('PDF e imagem por médico suportam $horas horas e acentos', () async {
      final dados = RelatorioHorasEspecialidade(
        inicio: DateTime(2026, 11, 1),
        fim: DateTime(2026, 11, 30),
        linhas: const [],
        medicos: [
          RelatorioHorasMedicoLinha(
            medicoId: 'ana',
            nome: 'Ana João',
            especialidade: 'Cardiologia',
            horasConsulta: horas,
          )
        ],
      );
      final exportacao = RelatorioHorasExportacaoDados(dados);
      expect(exportacao.cabecalhos,
          ['Médico', 'Especialidade', 'Horas de consulta']);
      expect(exportacao.linhas.last, ['Total', '', horas]);
      final pdf = await RelatorioHorasExportacaoService.gerarPdf(
          unidade: 'Clínica São João', relatorio: dados);
      expect(latin1.decode(pdf).startsWith('%PDF-'), isTrue);
      final png = await RelatorioHorasExportacaoService.gerarImagem(
          unidade: 'Clínica São João',
          relatorio: dados,
          conteudo: ConteudoImagemRelatorio.grafico);
      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    });
  }
}
