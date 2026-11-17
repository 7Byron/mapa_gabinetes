import 'package:flutter/material.dart';

import '../models/dados_relatorio_exportacao.dart';
export '../models/dados_relatorio_exportacao.dart'
    show
        FormatoExportacaoRelatorio,
        ConteudoImagemRelatorio,
        OpcaoExportacaoRelatorio;

Future<OpcaoExportacaoRelatorio?> escolherExportacaoRelatorio(
  BuildContext context, {
  bool mostrarGrafico = true,
  String? descricaoGrafico,
  String? descricaoTabela,
}) =>
    showDialog<OpcaoExportacaoRelatorio>(
      context: context,
      builder: (context) {
        Widget opcao(
                OpcaoExportacaoRelatorio escolha, String nome, IconData icone,
                {bool recuar = false, String? descricao}) =>
            Padding(
              padding: EdgeInsets.only(left: recuar ? 32 : 0),
              child: SimpleDialogOption(
                onPressed: () => Navigator.pop(context, escolha),
                child: ListTile(
                    leading: Icon(icone),
                    title: Text(nome),
                    subtitle: descricao == null ? null : Text(descricao)),
              ),
            );
        return SimpleDialog(
          title: const Text('Exportar relatório'),
          children: [
            opcao(OpcaoExportacaoRelatorio.excel, 'Excel',
                Icons.table_chart_outlined),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Semantics(
                  header: true,
                  child: const ListTile(
                    leading: Icon(Icons.image_outlined),
                    title: Text('Imagem'),
                  )),
            ),
            if (mostrarGrafico)
              opcao(OpcaoExportacaoRelatorio.imagemGrafico, 'Gráfico',
                  Icons.bar_chart_outlined,
                  recuar: true, descricao: descricaoGrafico),
            opcao(OpcaoExportacaoRelatorio.imagemTabela, 'Tabela',
                Icons.table_chart_outlined,
                recuar: true, descricao: descricaoTabela),
            opcao(OpcaoExportacaoRelatorio.pdf, 'PDF',
                Icons.picture_as_pdf_outlined),
          ],
        );
      },
    );
