# Como Aplicar as Regras do Firebase - Passo a Passo

## 🚨 Problema Atual
O seu app não consegue aceder ao Firebase porque as regras de segurança expiraram há 12 dias.

## ✅ Solução Rápida

### Passo 1: Aceder ao Firebase Console
1. Abra o navegador e vá para: https://console.firebase.google.com
2. Faça login com a sua conta Google
3. Selecione o projeto: **`mapa-gabinetes-hlcamadora`**

### Passo 2: Ir para Firestore Database
1. No menu lateral esquerdo, clique em **"Firestore Database"**
2. Clique no separador **"Rules"** (no topo da página)

### Passo 3: Substituir as Regras
1. Apague todo o conteúdo atual da caixa de texto
2. Cole o conteúdo do arquivo `firestore.rules` que criámos:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Regras para a coleção de médicos
    match /medicos/{medicoId} {
      // Permite leitura e escrita para todos (sem autenticação)
      allow read, write: if true;
      
      // Regras para subcoleção de disponibilidades
      match /disponibilidades/{disponibilidadeId} {
        allow read, write: if true;
      }
    }
    
    // Regras para a coleção de gabinetes
    match /gabinetes/{gabineteId} {
      allow read, write: if true;
    }
    
    // Regras para a coleção de alocações
    match /alocacoes/{alocacaoId} {
      allow read, write: if true;
    }
    
    // Regras para horários da clínica
    match /horarios_clinica/{horarioId} {
      allow read, write: if true;
    }
    
    // Regras para feriados
    match /feriados/{feriadoId} {
      allow read, write: if true;
    }
    
    // Regras para especialidades (se existir)
    match /especialidades/{especialidadeId} {
      allow read, write: if true;
    }
    
    // Regras para configurações da clínica (se existir)
    match /config_clinica/{configId} {
      allow read, write: if true;
    }
    
    // Regra padrão - nega acesso a qualquer outra coleção
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### Passo 4: Publicar as Regras
1. Clique no botão **"Publish"** (azul, no topo)
2. Aguarde a confirmação de que as regras foram publicadas

### Passo 5: Testar o App
1. Aguarde 2-3 minutos para propagação
2. Execute o seu app Flutter
3. Tente criar um novo gabinete
4. Verifique se funciona sem erros

## 🔧 Correções Feitas no Código

Também corrigi os seguintes problemas no código:

### ✅ `cadastro_gabinete.dart`
- Adicionado import do Firestore
- Implementada função `_carregarDados()` para carregar dados do Firestore
- Corrigida função `_salvarGabinete()` para salvar no Firestore
- Simplificados os campos de texto (removido TypeAheadField complexo)
- Adicionadas validações de formulário

### ✅ `lista_gabinetes.dart`
- Adicionado import do Firestore
- Implementada função `_carregarGabinetes()` para carregar do Firestore
- Corrigida função `_deletarGabinete()` para eliminar do Firestore
- Melhorado tratamento de erros

### ✅ `gabinete.dart` (modelo)
- Corrigido `fromMap()` para lidar com especialidades vazias
- Melhorado tratamento de dados nulos

## 🎯 Resultado Esperado

Após aplicar as regras e as correções:
- ✅ O app consegue aceder ao Firebase
- ✅ Pode criar novos gabinetes
- ✅ Pode editar gabinetes existentes
- ✅ Pode eliminar gabinetes
- ✅ Lista de gabinetes carrega corretamente

## 🆘 Se Ainda Tiver Problemas

1. **Verifique a conexão à internet**
2. **Reinicie o app Flutter**
3. **Verifique os logs no console do Flutter**
4. **Confirme que as regras foram publicadas** (deve aparecer "Rules published successfully")

## 📞 Suporte

Se continuar com problemas, verifique:
- Firebase Console > Firestore Database > Usage (para ver se há erros)
- Logs do app Flutter para mensagens de erro específicas 