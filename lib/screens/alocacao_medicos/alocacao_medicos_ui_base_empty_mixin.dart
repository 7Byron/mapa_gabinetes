part of '../alocacao_medicos_screen.dart';

mixin AlocacaoMedicosUiBaseEmptyMixin on AlocacaoMedicosStateBase {
  @override
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_services,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Bem-vindo à ${widget.unidade.nome}!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Esta unidade ainda não tem dados configurados.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void _garantirPisosSelecionados() {
    // Se houver gabinetes e o filtro estiver vazio, inicializar com todos os setores
    if (pisosSelecionados.isEmpty && gabinetes.isNotEmpty) {
      final todosSetores = gabinetes.map((g) => g.setor).toSet().toList();
      pisosSelecionados = List<String>.from(todosSetores);
    }
  }
}
