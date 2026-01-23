## Funções Cloud - Vista Diária

Foi adicionada uma pasta `functions/` com duas Cloud Functions (Node 18):

- `onDisponibilidadeWrite`: mantém `unidades/{unidadeId}/dias/{yyyy-MM-dd}/disponibilidades` sincronizado ao criar/editar/apagar disponibilidades.
- `onAlocacaoWrite`: mantém `unidades/{unidadeId}/dias/{yyyy-MM-dd}/alocacoes` sincronizado para as alocações.

Deploy (na raiz do projeto):

```bash
cd functions && npm install && cd ..
firebase deploy --only functions
```

Depois do deploy, pode ler os dados do dia com 1–2 queries por `unidades/{id}/dias/{yyyy-MM-dd}`.

# mapa_gabinetes

App para gerir dotações de gabinetes médicos

## Getting Started


## Estrutura firebase

/unidades/{unidadeId}/
├── ocupantes/{medicoId}/
│   ├── disponibilidades/
│   │   ├── 2025/registos/{disponibilidadeId}
│   │   ├── 2026/registos/{disponibilidadeId}
│   │   └── ...
│   └── (dados do médico)
├── alocacoes/
│   ├── 2025/registos/{alocacaoId}
│   ├── 2026/registos/{alocacaoId}
│   └── ...
├── gabinetes/{gabineteId}
├── horarios_clinica/{horarioId}
└── feriados/{feriadoId}



## para deploy no firebase
flutter build web --release
firebase deploy --only hosting

## para fazer o upload para o github
git status
git add .
git status
git commit -m "23 jan"
git push origin master


