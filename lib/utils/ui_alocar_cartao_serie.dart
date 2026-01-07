import 'package:flutter/material.dart';
import '../models/disponibilidade.dart';
import '../models/unidade.dart';
import '../services/alocacao_unica_service.dart';
import '../services/alocacao_serie_service.dart';

/// Função reutilizável para alocar um cartão de série
/// 
/// Esta função:
/// 1. Mostra um diálogo perguntando se o usuário quer alocar apenas este dia ou toda a série
/// 2. Processa a escolha:
///    - Se "1dia": aloca apenas este dia usando AlocacaoUnicaService
///    - Se "serie": aloca toda a série usando AlocacaoSerieService
/// 
/// Parâmetros:
/// - [context]: Contexto do Flutter para mostrar diálogos
/// - [medicoId]: ID do médico a ser alocado
/// - [gabineteId]: ID do gabinete de destino
/// - [data]: Data da alocação
/// - [disponibilidade]: Disponibilidade do médico para a data
/// - [tipoDisponibilidade]: Tipo da disponibilidade (Semanal, Quinzenal, Mensal, Consecutivo, etc.)
/// - [onAlocarMedico]: Callback para alocar um médico (usado para alocação única)
/// - [onAtualizarEstado]: Callback para atualizar o estado após alocação
/// - [onAlocacaoSerieOtimista]: Callback opcional para atualização otimista durante alocação de série
/// - [onProgresso]: Callback para atualizar progresso durante alocação de série (progresso, mensagem)
/// - [unidade]: Unidade para buscar séries
/// - [serieIdExtraido]: ID da série extraído (opcional)
/// 
/// Retorna:
/// - `true` se a alocação foi bem-sucedida ou o usuário cancelou (sem erro)
/// - `false` se houve algum erro
Future<bool> alocarCartaoSerie({
  required BuildContext context,
  required String medicoId,
  required String gabineteId,
  required DateTime data,
  required Disponibilidade disponibilidade,
  required String tipoDisponibilidade,
  required Future<void> Function(
    String medicoId,
    String gabineteId, {
    DateTime? dataEspecifica,
    List<String>? horarios,
  }) onAlocarMedico,
  required VoidCallback onAtualizarEstado,
  void Function(String medicoId, String gabineteId, DateTime data)? onAlocacaoSerieOtimista,
  required void Function(double progresso, String mensagem) onProgresso,
  required Unidade? unidade,
  String? serieIdExtraido,
}) async {
  try {

    // Mostrar diálogo perguntando se quer alocar apenas este dia ou toda a série
    if (!context.mounted) return false;
    
    final escolha = await showDialog<String>(
      context: context,
      builder: (ctxDialog) {
        return AlertDialog(
          title: const Text('Alocar série?'),
          content: Text(
            'Esta disponibilidade é do tipo "$tipoDisponibilidade".\n'
            'Deseja alocar apenas este dia (${data.day}/${data.month}) '
            'ou todos os dias da série a partir deste?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctxDialog).pop('1dia'),
              child: const Text('Apenas este dia'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctxDialog).pop('serie'),
              child: const Text('Toda a série'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctxDialog).pop(null),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    // Se o usuário cancelou, retornar true (sem erro)
    if (escolha == null) {
      return true;
    }

    if (escolha == '1dia') {
      // Alocar apenas este dia usando AlocacaoUnicaService

      final sucesso = await AlocacaoUnicaService.alocar(
        medicoId: medicoId,
        gabineteId: gabineteId,
        data: data,
        disponibilidade: disponibilidade,
        onAlocarMedico: onAlocarMedico,
        context: context,
        unidade: unidade,
        serieIdExtraido: serieIdExtraido,
      );

      return sucesso;
    } else if (escolha == 'serie') {
      // Alocar toda a série usando AlocacaoSerieService

      if (!context.mounted) return false;

      final resultado = await AlocacaoSerieService.alocar(
        medicoId: medicoId,
        gabineteId: gabineteId,
        data: data,
        disponibilidade: disponibilidade,
        unidade: unidade,
        context: context,
        onAlocacaoSerieOtimista: onAlocacaoSerieOtimista,
        onAtualizarEstado: onAtualizarEstado,
        onProgresso: onProgresso,
        serieIdExtraido: serieIdExtraido,
      );

      return resultado;
    }

    return true;
  } catch (e) {

    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erro ao alocar série: $e'),
        backgroundColor: Colors.red,
      ),
    );
    return false;
  }
}

