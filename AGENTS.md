# Versionamento e publicação

- Usar o formato `AAAA.MM.DD+N`: a data identifica a publicação e `N` é um contador global crescente.
- A base acordada é `2026.10.16+2`. Não recalcular nem recuperar a contagem de builds anteriores.
- Em cada nova publicação, incrementar em uma unidade o contador atual do `pubspec.yaml` (`+2` → `+3` → `+4` → …). Nunca reiniciar o contador quando mudar o dia, mês ou ano.
- Incrementar uma vez por nova versão preparada para publicação. Recompilar ou repetir um deploy da mesma versão não incrementa o contador.
- Manter a versão sincronizada em `pubspec.yaml`, `lib/utils/app_version.dart` e no teste `test/custom_drawer_version_test.dart`. Gerar `web/version.json` através de `dart run tool/build_web.dart`.
- Não alterar a versão nem publicar apenas por editar estas instruções.
