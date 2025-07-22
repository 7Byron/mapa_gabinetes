# 🔍 Verificar Dados no Firestore

## 🚨 Problema Identificado

O erro `TypeError: Instance of 'IdentityMap<String, dynamic>': type 'IdentityMap<String, dynamic>' is not a subtype of type 'Map<String, String>'` foi corrigido, mas agora precisamos verificar se os dados estão realmente sendo salvos.

## ✅ Correções Aplicadas

### 1. **Erro de Tipo Corrigido**
- ✅ Criado `Map<String, dynamic>` explícito para feriados
- ✅ Corrigido casting de tipos no sort
- ✅ Melhorado tratamento de dados

### 2. **Horários Inicializados Corretamente**
- ✅ Horários começam vazios por padrão
- ✅ Dados são carregados do Firestore ao abrir a tela
- ✅ Recarrega dados quando a tela volta a ser exibida

## 🛠️ Como Verificar se os Dados Estão Salvos

### Passo 1: Verificar no Firebase Console
1. Vá para [Firebase Console](https://console.firebase.google.com)
2. Selecione o projeto `mapa-gabinetes-hlcamadora`
3. Vá para **Firestore Database**
4. Verifique as coleções:

#### **Coleção `horarios_clinica`:**
- Deve ter 7 documentos (um para cada dia da semana)
- Cada documento deve ter:
  - `diaSemana`: número de 1 a 7
  - `horaAbertura`: string (ex: "08:00")
  - `horaFecho`: string (ex: "20:00")

#### **Coleção `feriados`:**
- Deve ter documentos apenas para feriados reais
- Cada documento deve ter:
  - `data`: string no formato ISO (ex: "2025-08-15T00:00:00.000Z")
  - `descricao`: string (ex: "Feriado Nacional")

### Passo 2: Configurar Horários da Clínica
1. No app, vá para **"Configuração Horário da Clínica"**
2. Configure os horários para cada dia:
   - **Segunda a Sexta**: 08:00 - 20:00
   - **Sábado**: 08:00 - 13:00
   - **Domingo**: deixe vazio (clínica fechada)
3. Clique em **"Salvar"**
4. Verifique se aparece "Alterações gravadas com sucesso!"

### Passo 3: Adicionar Feriados (Se Necessário)
1. Na mesma tela, clique no ícone verde (+) ao lado de "Encerrado e/ou Feriados"
2. Selecione a data do feriado
3. Digite uma descrição (opcional)
4. Clique em "Confirmar"
5. Verifique se aparece "Feriado adicionado com sucesso!"

### Passo 4: Verificar no App Principal
1. Volte para a tela principal (Mapa de Gabinetes)
2. Selecione uma data que não seja feriado
3. Verifique se a clínica aparece como aberta
4. Selecione um domingo ou feriado
5. Verifique se a clínica aparece como fechada

## 🔍 Debug e Logs

### Logs para Verificar:
- `Carregando dados da clínica do Firestore...` - Início do carregamento
- `Horários encontrados: X` - Quantos horários foram carregados
- `Horário carregado para dia X: YY:YY - ZZ:ZZ` - Horários específicos
- `Feriados encontrados: X` - Quantos feriados foram carregados
- `Gravando alterações no Firestore...` - Início do salvamento
- `Horário salvo para dia X: YY:YY - ZZ:ZZ` - Horários salvos
- `Feriado salvo no Firestore com ID: XXX` - Feriado salvo

## 🎯 Resultado Esperado

Após configurar corretamente:
- ✅ Horários aparecem preenchidos na tela de configuração
- ✅ Feriados aparecem listados na tela de configuração
- ✅ Clínica aparece aberta nos dias úteis
- ✅ Clínica aparece fechada em domingos e feriados
- ✅ Dados persistem após fechar e abrir o app

## 🆘 Se Ainda Tiver Problemas

### Verificar se os Dados Estão no Firestore:
1. **Abra o Firebase Console**
2. **Vá para Firestore Database**
3. **Verifique se as coleções existem**
4. **Verifique se os documentos têm os campos corretos**

### Se os Dados Não Estão Salvos:
1. **Verifique a conexão à internet**
2. **Confirme que as regras do Firebase permitem escrita**
3. **Verifique os logs do app para erros**
4. **Tente salvar novamente**

### Se os Dados Estão mas o App Não Carrega:
1. **Verifique os logs de carregamento**
2. **Confirme que as regras do Firebase permitem leitura**
3. **Reinicie o app**
4. **Verifique se há erros de parsing de dados**

## 📞 Suporte Adicional

Se continuar com problemas:
1. Verifique os logs detalhados no console
2. Confirme que os dados estão no Firestore Console
3. Teste com dados simples primeiro
4. Verifique se há erros de rede ou permissões 