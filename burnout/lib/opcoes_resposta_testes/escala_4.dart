import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/variaveis_globais.dart';
import '../funcoes/spacing.dart';

class Botoes4Resposta extends StatefulWidget {
  final Function(String) onRespostaSelecionada;

  const Botoes4Resposta({super.key, required this.onRespostaSelecionada});

  @override
  State<Botoes4Resposta> createState() => _Botoes4RespostaState();
}

class _Botoes4RespostaState extends State<Botoes4Resposta> {
  final Map<String, bool> _buttonPressed = {
    'N': false,
    'R': false,
    'H': false,
    'S': false,
  };

  final List<Map<String, String>> botoes = const [
    {'imagem': RotaImagens.nunca, 'texto': 'Nunca', 'valor': 'N'},
    {'imagem': RotaImagens.raro, 'texto': 'Raramente', 'valor': 'R'},
    {'imagem': RotaImagens.habitual, 'texto': 'Habitualmente', 'valor': 'H'},
    {'imagem': RotaImagens.sempre, 'texto': 'Sempre', 'valor': 'S'},
  ];

  @override
  Widget build(BuildContext context) {
    // Removido FittedBox para não encolher o conteúdo. Usamos Expanded para
    // distribuir o espaço e permitir que as legendas cresçam.
    return Padding(
      padding: EdgeInsets.all(Spacing.m),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: botoes.map((botao) {
          return Expanded(
            child: _botaoEscolha(
                botao['imagem']!, botao['texto']!, botao['valor']!),
          );
        }).toList(),
      ),
    );
  }

  Widget _botaoEscolha(
      String imagemBotao, String textoBotao, String valorBotao) {
    final bool isPressed = _buttonPressed[valorBotao] ?? false;
    final double circleBase = MyG.to.margens['margem8']!;
    // Ícones reduzidos para ~metade do tamanho
    final double circleSize = circleBase * 0.30;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _buttonPressed[valorBotao] = true;
        });
      },
      onTapUp: (_) async {
        await Future.delayed(const Duration(milliseconds: 450));
        setState(() {
          _buttonPressed[valorBotao] = false;
        });
        widget.onRespostaSelecionada(valorBotao);
      },
      onTapCancel: () {
        setState(() {
          _buttonPressed[valorBotao] = false;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: circleSize,
            height: circleSize,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: isPressed ? circleSize * 0.8 : circleSize,
                height: isPressed ? circleSize * 0.8 : circleSize,
                decoration: isPressed
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                      )
                    : BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x80000000),
                            blurRadius: 20.0,
                            offset: Offset(0.0, 5.0),
                          ),
                        ],
                      ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: Image.asset(
                    imagemBotao,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: Spacing.s * 0.7),
          // Usa AutoSizeText para garantir que palavras não sejam cortadas
          // Reduz a fonte se necessário, e permite 2 linhas apenas para múltiplas palavras
          LayoutBuilder(
            builder: (context, constraints) {
              // Verifica se o texto tem múltiplas palavras (espaços)
              final bool hasMultipleWords = textoBotao.trim().contains(' ');

              return SizedBox(
                width: constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : double.infinity,
                child: AutoSizeText(
                  textoBotao,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown,
                    height: 1.05,
                  ),
                  maxFontSize: 14.0,
                  minFontSize:
                      6.0, // Reduzido para permitir mais redução se necessário
                  maxLines: hasMultipleWords
                      ? 2
                      : 1, // 2 linhas apenas se tiver múltiplas palavras
                  stepGranularity: 0.5,
                  // AutoSizeText preserva palavras inteiras por padrão
                  // Se for uma palavra única longa (como "Habitualmente"), reduz a fonte em vez de quebrar
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
