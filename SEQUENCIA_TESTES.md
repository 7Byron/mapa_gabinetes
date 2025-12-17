# 📋 Sequência de Testes - Alocação de Médicos

## 🎯 Objetivo dos Testes
Testar o sistema completo de alocação e realocação de médicos em séries infinitas.

---

## ✅ TESTE 1: Alocar Cartão Desalocado

**O que fazer:**
1. Abra o app no Chrome (F5)
2. Navegue para **10/12/2025**
3. Veja a seção "Médicos Disponíveis" (topo da tela)
4. **Arraste** um cartão (ex: Teste1) para um gabinete vazio (ex: Gabinete 101)
5. **Solte** o cartão
6. Aguarde completar

**O que verificar:**
- ✅ Cartão desapareceu de "Médicos Disponíveis"
- ✅ Cartão apareceu no gabinete 101
- ✅ Sem "piscar" excessivo

---

## ✅ TESTE 2: Realocar Toda a Série

**O que fazer:**
1. Com o cartão já alocado (TESTE 1)
2. **Arraste** o cartão do Gabinete 101 para o Gabinete 102
3. Quando aparecer o diálogo: **Escolha "Toda a série"**
4. Aguarde completar

**O que verificar:**
- ✅ Cartão apareceu imediatamente no Gabinete 102
- ✅ Sem "piscar" durante a operação
- ✅ Operação completou sem erros

---

## ✅ TESTE 3: Verificar Série Após Realocação

**O que fazer:**
1. Após TESTE 2, navegue para **17/12/2025**
2. Verifique se o cartão está no Gabinete 102
3. Navegue para **24/12/2025**
4. Verifique se o cartão ainda está no Gabinete 102

**O que verificar:**
- ✅ Cartão aparece no Gabinete 102 em todas as datas futuras
- ✅ Cartão NÃO aparece mais no Gabinete 101

---

## ✅ TESTE 4: Realocar Apenas Um Cartão (Criar Exceção)

**O que fazer:**
1. Navegue para **17/12/2025**
2. **Arraste** o cartão do Gabinete 102 para o Gabinete 103
3. Quando aparecer o diálogo: **Escolha "Apenas este dia"**
4. Aguarde completar

**O que verificar:**
- ✅ Cartão apareceu imediatamente no Gabinete 103
- ✅ Sem "piscar" durante a operação
- ✅ Operação completou sem erros

---

## ✅ TESTE 5: Verificar Exceção

**O que fazer:**
1. Navegue para **10/12/2025** (antes da exceção)
   - Verifique: cartão deve estar no Gabinete 102
2. Navegue para **17/12/2025** (data da exceção)
   - Verifique: cartão deve estar no Gabinete 103
3. Navegue para **24/12/2025** (depois da exceção)
   - Verifique: cartão deve estar no Gabinete 102 (ou 103, dependendo da lógica)

**O que verificar:**
- ✅ Datas anteriores: Gabinete 102
- ✅ Data da exceção: Gabinete 103
- ✅ Datas futuras: comportamento correto

---

## ✅ TESTE 6: Múltiplas Realocações (Stress Test)

**O que fazer:**
1. Aloque 3 cartões diferentes em gabinetes diferentes
2. Realoque cada um para outros gabinetes
3. Alternar entre "Toda a série" e "Apenas este dia"

**O que verificar:**
- ✅ Sem "piscar" excessivo
- ✅ Todas as operações completam
- ✅ Cartões aparecem nos lugares corretos

---

## 🔍 Como Verificar os Logs

### No Console do Chrome (F12):
1. Pressione **F12** no Chrome
2. Vá para a aba **"Console"**
3. Você verá logs como:
   ```
   📊 [LOG-DEBUG] {"id":"log_...","location":"...","message":"..."}
   🔍 [LOG] gabinetes_section.dart:293 | Alocação encontrada | H:H1
   🟢 [DRAG-ACCEPT] Cartão solto: médico=...
   ```

### Logs que você deve ver:
- `🟢 [DRAG-ACCEPT]` - Quando arrasta um cartão
- `📊 [LOG-DEBUG]` - Logs em formato JSON
- `🔍 [LOG]` - Logs formatados
- `🟢 [OTIMISTA]` - Atualização otimista
- `🔵 [REALOCAÇÃO]` - Operações de realocação

---

## 📊 Verificação dos Logs

Após executar os testes, verifique no console:
1. **TESTE 1:** Deve aparecer `[LOG-DEBUG]` com `"message":"Alocação inicial - ANTES"`
2. **TESTE 2:** Deve aparecer `"message":"Escolha: Toda a série"`
3. **TESTE 4:** Deve aparecer `"message":"Escolha: Apenas este dia"`

---

## ⚠️ Problemas Comuns

Se não ver logs:
- Verifique se o console do Chrome está aberto (F12)
- Verifique se há erros no console (vermelho)
- Recarregue a página (Ctrl+R ou Cmd+R)

Se os logs não aparecem:
- Os logs estão sendo emitidos via `debugPrint()`
- Devem aparecer no console do Chrome automaticamente
- O modo Debug do Cursor pode capturá-los também

