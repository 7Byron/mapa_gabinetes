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

