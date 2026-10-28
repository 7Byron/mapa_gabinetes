# Revisão para publicação — 2026.10.28+7

Data: 28/10/2026. Registo da revisão e preparação local do candidato, anterior ao deploy.
Ambiente: Flutter 3.47.7 / Dart 3.13.5, Chrome headless, viewport 1800 × 1000.

## Dependências

Atualizadas 17 dependências diretas/transitivas dentro das restrições existentes, através de `flutter pub upgrade`.

| Dependência direta | Antes | Preparada |
| --- | --- | --- |
| cloud_firestore | 6.10.0 | 6.10.2 |
| firebase_core | 4.15.0 | 4.15.2 |
| firebase_auth | 6.7.0 | 6.7.1 |
| firebase_storage | 13.6.0 | 13.6.1 |
| crypto | 3.0.7 | 3.0.8 |
| shared_preferences | 2.5.5 | 2.5.6 |
| url_launcher | 6.3.2 | 6.3.3 |
| fake_cloud_firestore (testes) | 4.3.0 | 4.4.0 |

As atualizações principais Firebase, Syncfusion e TypeAhead ficam para uma migração separada. Firebase Core 5 altera requisitos nativos; o changelog oficial identifica alterações incompatíveis: https://pub.dev/packages/firebase_core/changelog.

Functions: `npm audit --omit=dev` indicou zero vulnerabilidades; nenhuma atualização compatível requerida pelo `npm outdated`. Não foram alteradas nem publicadas Functions.

## Teste de utilização

Navegação real na app local, usando os serviços de leitura da unidade atual. O percurso funcional foi executado em debug, com a entrada automática de desenvolvimento existente. Não foram acionadas edições, alocações ou gravações. O arranque do bundle release é validado separadamente; não substitui um teste de autenticação com credenciais reais.

Percursos concluídos:

- Abrir unidade e login; carregar mapa geral.
- Mudar de 28 para 29 de outubro e regressar ao dia 28.
- Abrir Taxas de Ocupação, gerar e repetir o relatório semanal.
- Abrir Horas de Especialidade, gerar e repetir o relatório semanal.
- Abrir Ocupação por Gabinete, expandir Piso 1, selecionar 101, gerar e repetir.
- Abrir Matriz Livre, expandir Piso 1, ocultar e voltar a mostrar 101.
- Abrir as datas de um subcartão da matriz e fechar o diálogo.

Não foram observadas exceções JavaScript, erros de shaders ou avisos de overflow nestes percursos. Inspeção visual dos ecrãs gerados. Não é um estudo com utilizadores nem uma auditoria completa de acessibilidade.

## Leituras e caches

Medição: novos alvos `addTarget` enviados pelo SDK Firestore no transporte Listen, identificados no navegador por ação. Estes números representam pedidos de consulta/documento, **não documentos lidos nem leituras faturadas**. Podem incluir consultas vazias e dependem do aquecimento da cache. Os tempos do script incluem esperas intencionais e compilação debug, pelo que não são um benchmark de produção.

| Ação | Antes | Depois | Observação |
| --- | ---: | ---: | --- |
| Abrir mapa pela primeira vez | 194 | 193 | Continua a carregar dados e exceções anuais a frio |
| Mudar para um dia novo (29/10) | 169 | 5 | Removida a releitura forçada de exceções anuais |
| Voltar ao dia 28 em cache | 1 | 1 | Apenas validação das versões |
| Gerar Taxas de Ocupação | 5 | 3 | Validações de versão repetidas: 3 → 1 |
| Repetir Taxas de Ocupação | 5 | 3 | Ainda relê alocações anuais e médicos |
| Gerar Horas de Especialidade | 178 | 175 | Validações de versão repetidas: 4 → 1 |
| Repetir Horas de Especialidade | 1 | 1 | Resultado reutilizado |
| Gerar Ocupação por Gabinete | — | 3 | Alocações anuais, médicos e versões |
| Repetir Ocupação por Gabinete | — | 1 | Resultado reutilizado |
| Ocultar/mostrar gabinete na matriz | — | 0 | Filtragem local |
| Consultar datas de subcartão | — | 0 | Dados já carregados |

Correções aplicadas:

1. O mapa fornecia simultaneamente ano e dia; uma condição tratava isso como consulta anual e forçava o servidor. Agora apenas a consulta anual sem dia força esse percurso. Alterações remotas/invalidação explícita continuam a forçar atualização.
2. Cada ação partilha uma fotografia das versões entre os serviços chamados. Não existe TTL ou reutilização entre ações diferentes. Escritas invalidam a fotografia, unidades são isoladas e callbacks posteriores ao fim da ação voltam a consultar.
3. Retirado o registo de documentos completos de unidades na consola, por poder incluir configurações de acesso.

## Melhorias propostas para a próxima intervenção

1. **Cache de resultados em Taxas de Ocupação**, com chave por unidade/período/gabinetes e validação por versões, à semelhança dos outros relatórios. Evitaria reler alocações anuais e médicos ao repetir os mesmos filtros.
2. **Disponibilidades únicas em Horas de Especialidade:** a primeira geração semanal abriu 174 consultas anuais por médico. Avaliar consulta por período através das vistas diárias existentes, validando antes a sua completude e a compatibilidade com dados antigos; conservar fallback para evitar omissões.
3. **Invalidação entre ecrãs e utilizadores:** acrescentar testes de alterações remotas que afetem médicos, séries, exceções e configuração da clínica enquanto relatórios estão abertos. A validação das versões e a invalidação das caches base devem ser verificadas em conjunto.
4. Avaliar limites de memória para caches de relatórios por período, se sessões longas fizerem muitas consultas distintas. Não há medição suficiente para afirmar uma fuga de memória.

Estas alterações maiores não foram introduzidas nesta preparação.

## Validação do candidato

- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub`: 214 testes passaram.
- `node --test test/web/flutter_bootstrap_test.cjs`: 9 testes passaram.
- `dart run tool/build_web.dart --no-pub`: build release concluído.
- Versão sincronizada no pubspec, constante da app, teste do menu e `web/version.json`: `2026.10.28+7`.
- Aviso conhecido do dry-run WebAssembly: `flutter_keyboard_visibility_web` ainda usa `dart:html`. O build JavaScript/CanvasKit utilizado neste candidato conclui; não foi preparado um build Wasm.
- A falha gráfica intermitente reportada anteriormente não foi reproduzida. Existe deteção inicial, modo compatível e aviso de recuperação que não reinicia automaticamente nem bloqueia a aplicação após falha transitória. Isto não demonstra a causa exata da ocorrência anterior.

## Ajustes visuais posteriores à revisão

- Seleção de unidade: cabeçalho e botão com o azul do logótipo; versão sob o ícone.
- Horário de Abertura: quadro branco com cabeçalhos e seleção no azul do logótipo, colunas proporcionais e horas numa linha. Em ecrã estreito/letra ampliada, a tabela permite rolagem horizontal. Três testes adicionais cobrem dimensões e os callbacks dos controlos; preservada a gravação automática existente.

## Antes do deploy

No final desta revisão, o candidato foi gerado em `build/web`. A publicação e a verificação no endereço público constituem a etapa seguinte, autorizada posteriormente pelo utilizador.
