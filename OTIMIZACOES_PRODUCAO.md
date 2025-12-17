# Otimizações Importantes para Produção

## 🔴 CRÍTICAS (Fazer antes de publicar)

### 1. Remover/Substituir Print Statements
- **Problema**: 539 ocorrências de `print()` em 29 ficheiros
- **Impacto**: Performance e segurança (pode expor informações sensíveis)
- **Ação**: 
  - Substituir todos os `print()` por `debugPrint()` ou sistema de logging condicional
  - Criar wrapper de logging que só funciona em debug mode
  - Ficheiros principais: `medico_salvar_service.dart`, `alocacao_medicos_screen.dart`, `serie_service.dart`

### 2. Corrigir BuildContext Async Gaps
- **Problema**: 30+ avisos sobre uso de `BuildContext` após operações async
- **Impacto**: Pode causar crashes se o widget for desmontado
- **Ação**: Adicionar verificações `if (mounted)` antes de usar `context`
- **Ficheiros afetados**: `cadastro_medicos.dart` (principalmente)

### 3. Substituir Deprecated APIs
- **Problema**: 12 usos de `withOpacity()` (deprecated)
- **Impacto**: Pode quebrar em versões futuras do Flutter
- **Ação**: Substituir por `withValues()`
- **Ficheiros**: `cadastro_medicos.dart`, `formulario_medico.dart`, `alocacao_medicos_screen.dart`

## 🟡 IMPORTANTES (Recomendado)

### 4. Limpar Variáveis Não Usadas
- **Problema**: Vários warnings sobre variáveis não usadas
- **Impacto**: Código mais limpo, menor bundle size
- **Ação**: Remover variáveis não utilizadas
- **Ficheiros**: `alocacao_medicos_logic.dart`, `cadastro_unidade_screen.dart`

### 5. Otimizar Carregamento de Dados
- **Problema**: Carregamento de todos os médicos/gabinetes de uma vez
- **Impacto**: Performance em unidades grandes
- **Ação**: Implementar paginação ou lazy loading onde apropriado

### 6. Tratamento de Erros
- **Problema**: Alguns erros podem não estar a ser tratados adequadamente
- **Impacto**: UX ruim, crashes potenciais
- **Ação**: Revisar try-catch blocks e adicionar tratamento de erros de rede

## 🟢 MELHORIAS (Opcional mas recomendado)

### 7. Remover Código Debug
- **Problema**: Ficheiros de debug ainda no código
- **Ação**: Remover ou mover para pasta separada
- **Ficheiros**: `debug_firebase.dart`, `debug_disponibilidades.dart`, etc.

### 8. Otimizar Imports
- **Problema**: Possíveis imports não utilizados
- **Ação**: Executar `dart fix --apply` para limpar imports

### 9. Adicionar Error Boundaries
- **Problema**: Erros não tratados podem quebrar a app
- **Ação**: Adicionar error boundaries em widgets críticos

### 10. Performance Monitoring
- **Ação**: Adicionar Firebase Performance Monitoring ou similar
- **Benefício**: Identificar bottlenecks em produção

## 📋 Checklist Pré-Publicação

- [ ] Substituir todos os `print()` por logging condicional
- [ ] Adicionar `mounted` checks em todos os async operations
- [ ] Substituir `withOpacity()` por `withValues()`
- [ ] Remover variáveis não usadas
- [ ] Testar em modo release (`flutter run --release`)
- [ ] Verificar tamanho do bundle
- [ ] Testar offline/online scenarios
- [ ] Revisar permissões e privacidade
- [ ] Verificar se todas as strings estão traduzidas (se aplicável)
- [ ] Testar em diferentes tamanhos de ecrã
- [ ] Verificar performance em dispositivos mais antigos

## 🚀 Comandos Úteis

```bash
# Verificar tamanho do bundle
flutter build apk --analyze-size
flutter build ios --analyze-size

# Verificar performance
flutter run --profile

# Limpar código
dart fix --apply
flutter analyze
```
