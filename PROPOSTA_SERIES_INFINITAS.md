# Proposta: Séries Infinitas sem Consumo Excessivo de Recursos

## Problema Atual
- Cada cartão de disponibilidade/alocação é um documento individual no Firestore
- Séries semanais criam 52+ documentos por ano
- Séries mensais criam 12+ documentos por ano
- Para séries "infinitas", isso resultaria em milhares/milhões de documentos

## Solução Proposta: Modelo Híbrido

### 1. **Regras de Recorrência** (Series Rules)
Armazenar apenas a **regra** da série, não os cartões individuais:

```dart
class SerieRecorrencia {
  String id;
  String medicoId;
  DateTime dataInicio;        // Data de início da série
  DateTime? dataFim;          // null = infinito
  String tipo;                // "Semanal", "Quinzenal", "Mensal"
  List<String> horarios;      // Horários padrão
  String? gabineteId;         // Se já estiver alocado
  Map<String, dynamic> parametros; // Parâmetros específicos (ex: dia da semana, ocorrência no mês)
}
```

**Estrutura no Firestore:**
```
unidades/{unidadeId}/ocupantes/{medicoId}/series/{serieId}
```

### 2. **Exceções** (Overrides)
Quando uma data específica precisa ser diferente da regra:

```dart
class ExcecaoSerie {
  String serieId;             // ID da série à qual pertence
  DateTime data;              // Data específica
  bool cancelada;               // true = não acontece nesta data
  List<String>? horarios;     // null = usa horários da série, senão sobrescreve
  String? gabineteId;         // null = não alocado, senão sobrescreve gabinete
}
```

**Estrutura no Firestore:**
```
unidades/{unidadeId}/ocupantes/{medicoId}/excecoes/{ano}/{excecaoId}
```

### 3. **Geração Dinâmica**
Calcular cartões sob demanda baseado em:
- Regras ativas no período
- Exceções que modificam/cancelam datas específicas

## Vantagens

### Performance
- **1 documento** para uma série semanal infinita (vs. 52+ por ano)
- **1 documento** para uma série mensal infinita (vs. 12+ por ano)
- Carregar apenas regras + exceções do período visível

### Escalabilidade
- Séries infinitas = 1 documento (não milhares)
- Exceções apenas quando necessário (feriados, férias, alterações)
- Queries eficientes: buscar regras ativas + exceções do período

### Flexibilidade
- Fácil cancelar uma data específica (criar exceção com `cancelada: true`)
- Fácil alterar horários de uma data específica (criar exceção com novos horários)
- Fácil terminar uma série (atualizar `dataFim` na regra)

## Exemplo Prático

### Cenário: Médico com consulta toda terça-feira, 10:00-14:00

**Antes (modelo atual):**
- 52 documentos por ano
- 520 documentos em 10 anos
- Crescimento infinito

**Depois (modelo proposto):**
- 1 documento (regra): "Toda terça-feira, 10:00-14:00, início: 01/01/2025, fim: null"
- Exceções apenas quando necessário:
  - Feriado 25/04/2025 → 1 exceção (cancelada)
  - Férias 15/07-31/07/2025 → 3 exceções (canceladas)
- Total: 1 regra + ~4-5 exceções por ano = **5 documentos vs 52**

## Migração

### Fase 1: Compatibilidade
- Manter modelo atual funcionando
- Adicionar novo modelo em paralelo
- Converter séries existentes para regras

### Fase 2: Transição
- Novas séries usam modelo de regras
- Séries antigas podem ser convertidas gradualmente
- UI mostra ambos os modelos

### Fase 3: Consolidação
- Converter todas as séries para regras
- Remover código legado (opcional)

## Implementação Técnica

### 1. Novo Modelo de Dados
```dart
// lib/models/serie_recorrencia.dart
class SerieRecorrencia {
  String id;
  String medicoId;
  DateTime dataInicio;
  DateTime? dataFim;
  String tipo; // Semanal, Quinzenal, Mensal
  List<String> horarios;
  String? gabineteId;
  Map<String, dynamic> parametros; // weekday, ocorrencia, etc.
}

// lib/models/excecao_serie.dart
class ExcecaoSerie {
  String id;
  String serieId;
  DateTime data;
  bool cancelada;
  List<String>? horarios;
  String? gabineteId;
}
```

### 2. Gerador Dinâmico
```dart
// lib/services/serie_generator.dart
class SerieGenerator {
  static List<Disponibilidade> gerarCartoes(
    SerieRecorrencia serie,
    DateTime dataInicio,
    DateTime dataFim,
    List<ExcecaoSerie> excecoes,
  ) {
    // Gera cartões dinamicamente baseado na regra
    // Aplica exceções (cancelamentos, alterações)
  }
}
```

### 3. Queries Otimizadas
```dart
// Buscar apenas regras ativas no período
final series = await firestore
  .collection('unidades')
  .doc(unidadeId)
  .collection('ocupantes')
  .doc(medicoId)
  .collection('series')
  .where('dataInicio', isLessThanOrEqualTo: dataFim)
  .where('dataFim', isNull) // ou isGreaterThanOrEqualTo: dataInicio
  .get();

// Buscar exceções do período
final excecoes = await firestore
  .collection('unidades')
  .doc(unidadeId)
  .collection('ocupantes')
  .doc(medicoId)
  .collection('excecoes')
  .doc(ano.toString())
  .collection('registos')
  .where('data', isGreaterThanOrEqualTo: dataInicio)
  .where('data', isLessThanOrEqualTo: dataFim)
  .get();
```

## Considerações

### Cache
- Cachear regras (mudam raramente)
- Cachear exceções do período atual
- Invalidar cache quando regras/exceções mudam

### UI
- Mostrar cartões gerados dinamicamente (transparente para o usuário)
- Permitir editar regra (afeta todas as datas futuras)
- Permitir criar exceção (afeta apenas data específica)

### Performance
- Gerar cartões apenas para o período visível (mês/semana atual)
- Lazy loading ao navegar no calendário
- Pré-calcular próximo mês em background

