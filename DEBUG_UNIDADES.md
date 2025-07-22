# 🔍 Debug - Problema das Unidades Não Aparecendo

## 🚨 Problema Identificado

A unidade foi criada no Firebase mas **não está aparecendo** na lista de seleção de unidades.

## 🔧 Debug Implementado

### **1. Logs Adicionados:**

#### **No UnidadeService:**
- ✅ **Logs detalhados** na busca de unidades
- ✅ **Logs detalhados** na criação de unidades
- ✅ **Informações** sobre documentos encontrados
- ✅ **Dados completos** de cada documento

#### **Na Tela de Seleção:**
- ✅ **Logs** no carregamento de unidades
- ✅ **Logs** no estado da tela
- ✅ **Contagem** de unidades carregadas

#### **Script de Debug:**
- ✅ **Verificação completa** do Firebase
- ✅ **Análise** de todos os documentos
- ✅ **Verificação** do campo 'ativa'

## 🚀 Como Executar o Debug

### **1. Execute o App:**
```bash
flutter run
```

### **2. Verifique os Logs:**
Procure no console por:
- `🔍 === DEBUG FIREBASE ===`
- `📂 Verificando coleção "unidades"...`
- `📊 Total de documentos na coleção "unidades"`
- `✅ Unidades carregadas:`

### **3. Possíveis Cenários:**

#### **Cenário A: Documento sem campo 'ativa'**
```
❓ Sem ativa - ID: [ID_DO_DOCUMENTO]
❓ Dados: {nome: "Minha Clínica", tipo: "Clínica", ...}
```
**Solução:** O documento foi criado sem o campo `ativa: true`

#### **Cenário B: Documento com ativa = false**
```
❌ Inativa - ID: [ID_DO_DOCUMENTO]
❌ Dados: {nome: "Minha Clínica", ativa: false, ...}
```
**Solução:** O documento foi criado com `ativa: false`

#### **Cenário C: Documento não encontrado**
```
📊 Total de documentos na coleção "unidades": 0
```
**Solução:** A unidade não foi salva corretamente

#### **Cenário D: Erro na consulta**
```
❌ Erro ao buscar unidades: [MENSAGEM_DE_ERRO]
```
**Solução:** Problema de permissões ou configuração

## 🔧 Soluções Possíveis

### **Solução 1: Corrigir Documento sem Campo 'ativa'**
Se o documento foi criado sem o campo `ativa`, execute:

```dart
// No Firebase Console ou via código
await firestore.collection('unidades').doc('[ID_DO_DOCUMENTO]').update({
  'ativa': true
});
```

### **Solução 2: Corrigir Documento com ativa = false**
Se o documento tem `ativa: false`, execute:

```dart
// No Firebase Console ou via código
await firestore.collection('unidades').doc('[ID_DO_DOCUMENTO]').update({
  'ativa': true
});
```

### **Solução 3: Verificar Permissões do Firebase**
Verifique se as regras do Firestore permitem:
- ✅ **Leitura** da coleção 'unidades'
- ✅ **Filtro** por campo 'ativa'
- ✅ **Ordenação** por campo 'nome'

### **Solução 4: Verificar Estrutura dos Dados**
Certifique-se de que o documento tem:
- ✅ **Campo 'ativa'** com valor `true`
- ✅ **Campo 'nome'** preenchido
- ✅ **Campo 'tipo'** preenchido
- ✅ **Campo 'endereco'** preenchido

## 📊 Estrutura Esperada do Documento

```json
{
  "id": "auto-generated-id",
  "nome": "Minha Clínica",
  "tipo": "Clínica",
  "endereco": "Rua Exemplo, 123",
  "telefone": "123456789",
  "email": "clinica@exemplo.com",
  "dataCriacao": "2024-01-01T00:00:00.000Z",
  "ativa": true
}
```

## 🎯 Próximos Passos

### **1. Execute o Debug:**
- Rode o app e verifique os logs
- Identifique o cenário específico

### **2. Aplique a Solução:**
- Corrija o documento no Firebase
- Ou ajuste o código conforme necessário

### **3. Teste Novamente:**
- Crie uma nova unidade
- Verifique se aparece na lista

### **4. Remova o Debug:**
- Remova o import do `debug_firebase.dart`
- Remova a chamada `await debugFirebase()`
- Remova os logs de debug

## 🔍 Comandos Úteis

### **Verificar Firebase Console:**
1. Acesse [Firebase Console](https://console.firebase.google.com)
2. Vá para **Firestore Database**
3. Procure pela coleção **'unidades'**
4. Verifique os documentos criados

### **Verificar Regras do Firestore:**
```javascript
// Deve permitir:
match /unidades/{unidadeId} {
  allow read, write: if true;
}
```

## 📝 Logs Esperados

### **Sucesso:**
```
🔍 === DEBUG FIREBASE ===
📂 Verificando coleção "unidades"...
📊 Total de documentos na coleção "unidades": 1
📄 Documento ID: abc123
📄 Dados: {nome: "Minha Clínica", ativa: true, ...}
✅ Verificando documentos com ativa = true...
📊 Documentos ativos: 1
✅ Ativa - ID: abc123
✅ Dados: {nome: "Minha Clínica", ativa: true, ...}
🔄 Iniciando carregamento de unidades...
📋 Unidades carregadas na tela: 1
🏥 Unidade na tela: Minha Clínica (Clínica) - Ativa: true
✅ Estado atualizado com 1 unidades
```

### **Problema:**
```
🔍 === DEBUG FIREBASE ===
📂 Verificando coleção "unidades"...
📊 Total de documentos na coleção "unidades": 1
📄 Documento ID: abc123
📄 Dados: {nome: "Minha Clínica", ...} // Sem campo 'ativa'
❓ Sem ativa - ID: abc123
❓ Dados: {nome: "Minha Clínica", ...}
✅ Verificando documentos com ativa = true...
📊 Documentos ativos: 0
🔄 Iniciando carregamento de unidades...
📋 Unidades carregadas na tela: 0
✅ Estado atualizado com 0 unidades
```

Execute o debug e me informe os resultados! 🔍 