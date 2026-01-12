import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/unidade.dart';
import '../utils/app_theme.dart';

/// Tela de scripts para operações diretas na base de dados do Firebase
/// Apenas visível em modo debug
class ScriptsScreen extends StatefulWidget {
  final Unidade? unidade;

  const ScriptsScreen({super.key, this.unidade});

  @override
  State<ScriptsScreen> createState() => _ScriptsScreenState();
}

class _ScriptsScreenState extends State<ScriptsScreen> {
  @override
  Widget build(BuildContext context) {
    // Garantir que só é acessível em modo debug
    if (!kDebugMode) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Acesso Negado'),
        ),
        body: const Center(
          child: Text('Esta funcionalidade só está disponível em modo debug.'),
        ),
      );
    }

    if (widget.unidade == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Scripts...'),
          backgroundColor: MyAppTheme.azulEscuro,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Nenhuma unidade selecionada'),
        ),
      );
    }

    final ocupantesRef = FirebaseFirestore.instance
        .collection('unidades')
        .doc(widget.unidade!.id)
        .collection('ocupantes');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scripts...'),
        backgroundColor: MyAppTheme.azulEscuro,
        foregroundColor: Colors.white,
        actions: [
          if (kDebugMode)
            Tooltip(
              message: 'Esta área permite executar scripts diretamente na base de dados do Firebase. Use com cuidado!',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(Icons.warning, color: Colors.orange[300]),
              ),
            ),
        ],
      ),
      body: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        margin: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informação da unidade atual
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.unidade!.nome,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${widget.unidade!.id}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Título da seção
            Text(
              'Documentos na coleção "ocupantes":',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            
            // Lista de documentos (visualização em árvore)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: ocupantesRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Erro ao carregar documentos: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'Nenhum documento encontrado na coleção "ocupantes"',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      return _DocumentoCard(
                        docId: doc.id,
                        data: doc.data() as Map<String, dynamic>?,
                        ocupantesRef: ocupantesRef,
                        unidadeId: widget.unidade!.id,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card que representa um documento na coleção ocupantes
class _DocumentoCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic>? data;
  final CollectionReference ocupantesRef;
  final String unidadeId;

  const _DocumentoCard({
    required this.docId,
    required this.data,
    required this.ocupantesRef,
    required this.unidadeId,
  });

  @override
  State<_DocumentoCard> createState() => _DocumentoCardState();
}

class _DocumentoCardState extends State<_DocumentoCard> {
  bool _isExpanded = false;
  bool _isLoadingSubcolecoes = false;
  Map<String, List<DocumentSnapshot>> _subcolecoes = {};

  Future<void> _loadSubcolecoes() async {
    if (_isExpanded && _subcolecoes.isNotEmpty) {
      // Já carregado, apenas fechar
      setState(() {
        _isExpanded = false;
      });
      return;
    }

    setState(() {
      _isExpanded = true;
      _isLoadingSubcolecoes = true;
    });

    try {
      final docRef = widget.ocupantesRef.doc(widget.docId);
      final subcolecoesConhecidas = ['disponibilidades', 'series', 'excecoes'];
      final Map<String, List<DocumentSnapshot>> subcolecoesCarregadas = {};

      for (final subNome in subcolecoesConhecidas) {
        try {
          final subcolecaoRef = docRef.collection(subNome);
          final snapshot = await subcolecaoRef.get();
          if (snapshot.docs.isNotEmpty) {
            subcolecoesCarregadas[subNome] = snapshot.docs;
          }
        } catch (e) {
          debugPrint('Erro ao carregar subcoleção $subNome: $e');
        }
      }

      setState(() {
        _subcolecoes = subcolecoesCarregadas;
        _isLoadingSubcolecoes = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSubcolecoes = false;
      });
      debugPrint('Erro ao carregar subcoleções: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataIsEmpty = widget.data == null || widget.data!.isEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(
          dataIsEmpty ? Icons.description_outlined : Icons.description,
          color: dataIsEmpty ? Colors.orange : Colors.blue,
        ),
        title: Text(
          widget.docId,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: dataIsEmpty ? Colors.orange[700] : Colors.grey[800],
          ),
        ),
        subtitle: Text(
          dataIsEmpty
              ? 'Documento vazio {}'
              : '${widget.data!.length} campo(s)',
          style: TextStyle(
            fontSize: 12,
            color: dataIsEmpty ? Colors.orange[600] : Colors.grey[600],
          ),
        ),
        trailing: _isExpanded
            ? const Icon(Icons.expand_less)
            : const Icon(Icons.expand_more),
        onExpansionChanged: (expanded) {
          if (expanded) {
            _loadSubcolecoes();
          } else {
            setState(() {
              _isExpanded = false;
            });
          }
        },
        children: [
          if (_isLoadingSubcolecoes)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_subcolecoes.isEmpty && _isExpanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Nenhuma subcoleção encontrada (disponibilidades, series, excecoes)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ..._subcolecoes.entries.map((entry) {
              final subNome = entry.key;
              final docs = entry.value;
              return _SubcolecaoSection(
                nome: subNome,
                documentos: docs,
                docId: widget.docId,
                unidadeId: widget.unidadeId,
              );
            }),
        ],
      ),
    );
  }
}

/// Seção que representa uma subcoleção
class _SubcolecaoSection extends StatelessWidget {
  final String nome;
  final List<DocumentSnapshot> documentos;
  final String docId;
  final String unidadeId;

  const _SubcolecaoSection({
    required this.nome,
    required this.documentos,
    required this.docId,
    required this.unidadeId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                nome,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${documentos.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...documentos.take(5).map((doc) {
            return Padding(
              padding: const EdgeInsets.only(left: 24, top: 4, bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      doc.id,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[700],
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (documentos.length > 5)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 4),
              child: Text(
                '... e mais ${documentos.length - 5} documento(s)',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
