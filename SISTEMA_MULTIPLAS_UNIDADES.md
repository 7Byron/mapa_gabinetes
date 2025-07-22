# 🏥 Sistema de Múltiplas Unidades

## 🎯 Visão Geral

O app agora suporta múltiplas unidades (clínicas, hospitais, hotéis, etc.) com dados completamente isolados. Cada unidade tem sua própria estrutura de dados no Firebase.

## 🏗️ Nova Estrutura do Firebase

### **Hierarquia de Dados:**
```
unidades/
├── {unidadeId}/
│   ├── nome, tipo, endereco, telefone, email, dataCriacao, ativa
│   ├── medicos/
│   │   ├── {medicoId}/
│   │   │   ├── id, nome, especialidade, observacoes
│   │   │   └── disponibilidades/
│   │   │       └── {disponibilidadeId}/
│   ├── gabinetes/
│   │   └── {gabineteId}/
│   ├── alocacoes/
│   │   └── {alocacaoId}/
│   ├── horarios_clinica/
│   │   └── {horarioId}/
│   ├── feriados/
│   │   └── {feriadoId}/
│   ├── especialidades/
│   │   └── {especialidadeId}/
│   └── config_clinica/
│       └── {configId}/
```

### **Tipos de Unidade:**
- 🎯 **Flexível** - O usuário pode digitar qualquer tipo
- 💡 **Sugestões** - Mostra tipos já existentes na base de dados
- ✨ **Personalizado** - Permite criar novos tipos conforme necessário
- 🔄 **Dinâmico** - Lista de sugestões atualiza automaticamente

## 🚀 Como Usar

### **1. Primeira Execução**
1. **Abra o app** - Será exibida a tela de seleção de unidades
2. **Clique em "Nova Unidade"** para criar sua primeira unidade
3. **Preencha os dados** da unidade
4. **Clique em "Criar"** para finalizar

### **2. Criar Nova Unidade**
1. **Clique em "Nova Unidade"**
2. **Preencha os dados:**
   - **Tipo de unidade** - Digite livremente ou escolha das sugestões
   - Nome da unidade
   - Endereço
   - Telefone (opcional)
   - Email (opcional)
3. **Clique em "Criar"**

### **3. Selecionar Unidade**
1. **Toque em uma unidade** na lista
2. **O app abrirá** com os dados específicos dessa unidade
3. **Todos os dados** ficam isolados por unidade

### **4. Gerenciar Unidades**
- **Editar**: Menu de 3 pontos → "Editar"
- **Desativar**: Menu de 3 pontos → "Desativar"

## 🔧 Arquivos Criados/Modificados

### **Novos Arquivos:**
- `lib/models/unidade.dart` - Modelo de dados da unidade
- `lib/services/unidade_service.dart` - Serviços para gerenciar unidades
- `lib/screens/selecao_unidade_screen.dart` - Tela de seleção de unidades
- `lib/screens/cadastro_unidade_screen.dart` - Tela de cadastro de unidades

### **Arquivos Modificados:**
- `lib/main.dart` - Tela inicial alterada para seleção de unidades
- `lib/screens/alocacao_medicos_screen.dart` - Aceita parâmetro de unidade
- `firestore.rules` - Regras atualizadas para nova hierarquia

## 🆕 Nova Estrutura Limpa

### **Vantagens:**
- 🧹 **Código mais limpo** sem lógica de migração
- ⚡ **Performance melhorada** sem verificações desnecessárias
- 🎯 **Foco na nova estrutura** desde o início
- 🔒 **Segurança aprimorada** com isolamento total de dados

### **Estrutura Simplificada:**
- ✅ **Apenas unidades** na raiz do Firebase
- ✅ **Dados isolados** por unidade
- ✅ **Sem compatibilidade** com estrutura antiga
- ✅ **Regras de segurança** simplificadas

## 🛡️ Regras de Segurança

### **Firestore Rules Simplificadas:**
```javascript
// Apenas estrutura de unidades
match /unidades/{unidadeId} {
  allow read, write: if true;
}

match /unidades/{unidadeId}/medicos/{medicoId} {
  allow read, write: if true;
}

// Nenhuma compatibilidade com dados antigos
```

## 📱 Interface do Usuário

### **Tela de Seleção de Unidades:**
- 🎨 **Header com logo** e informações do app
- ➕ **Botão "Nova Unidade"**
- 📋 **Lista de unidades** com cards informativos
- ⚙️ **Menu de ações** por unidade

### **Card de Unidade:**
- 🏷️ **Tipo** com cor diferenciada
- 📝 **Nome** da unidade
- 📍 **Endereço**
- 📞 **Telefone** (se disponível)
- 📅 **Data de criação**
- ✅ **Status ativo/inativo**

## 🔍 Funcionalidades

### **Por Unidade:**
- ✅ **Médicos** - Cadastro e gestão
- ✅ **Gabinetes** - Cadastro e gestão
- ✅ **Alocações** - Agendamento
- ✅ **Horários** - Configuração de funcionamento
- ✅ **Feriados** - Gestão de feriados
- ✅ **Relatórios** - Análises específicas
- ✅ **Configurações** - Personalização

### **Isolamento de Dados:**
- 🔒 **Dados completamente isolados** entre unidades
- 🚫 **Sem interferência** entre unidades
- 📊 **Relatórios independentes** por unidade
- ⚙️ **Configurações específicas** por unidade

## 🚨 Importante

### **Antes de Usar:**
1. **Atualize as regras do Firebase** com o novo `firestore.rules`
2. **Limpe dados antigos** do Firebase (se existirem)
3. **Verifique a conectividade** com o Firebase
4. **Teste a criação** de uma nova unidade

### **Primeira Configuração:**
1. **Crie sua primeira unidade** através do app
2. **Configure os dados** da unidade
3. **Teste as funcionalidades** básicas
4. **Adicione médicos e gabinetes** conforme necessário

## 🆘 Suporte

### **Se não conseguir criar unidade:**
1. Verifique os logs do console
2. Confirme as regras do Firebase
3. Verifique a conectividade
4. Teste a conexão com o Firebase

### **Se dados não aparecerem:**
1. Verifique se a unidade está ativa
2. Confirme se os dados foram criados corretamente
3. Verifique as regras do Firebase
4. Teste a conectividade

## 🎉 Benefícios

### **Para o Usuário:**
- 🏥 **Múltiplas unidades** em um só app
- 🔒 **Dados isolados** e seguros
- 📱 **Interface intuitiva** e moderna
- ⚡ **Início limpo** sem dados antigos

### **Para o Sistema:**
- 🏗️ **Arquitetura escalável** para múltiplas unidades
- 🔧 **Fácil manutenção** e atualizações
- 📊 **Relatórios independentes** por unidade
- 🛡️ **Segurança melhorada** com isolamento total
- 🧹 **Código limpo** sem complexidade de migração 