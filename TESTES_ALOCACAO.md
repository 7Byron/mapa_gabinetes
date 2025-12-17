# Sequência de Testes - Alocação de Médicos

## Objetivo
Testar o sistema completo de alocação e realocação de médicos, incluindo:
- Alocação de cartões desalocados
- Realocação de toda a série
- Realocação de apenas um cartão específico

## Pré-requisitos
1. App rodando em modo debug no Chrome (F5)
2. Data selecionada: **10/12/2025** (ou data onde estão os cartões Teste1, Teste2, Teste3)
3. Modo Debug do Cursor ativo para capturar logs

---

## TESTE 1: Alocar Cartão Desalocado

**Objetivo:** Alocar um cartão que está na seção "Médicos Disponíveis" em um gabinete.

**Passos:**
1. Verifique que há cartões na seção "Médicos Disponíveis" (topo da tela)
2. Identifique um cartão (ex: Teste1, Teste2 ou Teste3)
3. **Arraste** o cartão da seção "Médicos Disponíveis" para um gabinete vazio (ex: Gabinete 101)
4. **Solte** o cartão no gabinete
5. **Aguarde** a operação completar (pode aparecer barra de progresso)
6. **Verifique:**
   - O cartão desapareceu da seção "Médicos Disponíveis"?
   - O cartão apareceu no gabinete de destino?
   - Não há "piscar" ou flickering excessivo?

**Resultado esperado:** Cartão alocado com sucesso no gabinete escolhido.

---

## TESTE 2: Realocar Toda a Série

**Objetivo:** Mover um cartão que faz parte de uma série para outro gabinete, afetando todas as datas futuras.

**Pré-condição:** Deve haver um cartão já alocado que faz parte de uma série (ex: Teste1, Teste2 ou Teste3 que trabalha todas as quartas-feiras).

**Passos:**
1. **Navegue** para a data **10/12/2025** (ou data onde está o cartão)
2. **Identifique** um cartão já alocado em um gabinete (ex: Teste1 no Gabinete 101)
3. **Arraste** o cartão do gabinete atual para um **gabinete diferente** (ex: Gabinete 102)
4. **Solte** o cartão no novo gabinete
5. Quando aparecer o diálogo perguntando:
   - **Escolha: "Toda a série"**
6. **Aguarde** a operação completar
7. **Verifique:**
   - O cartão apareceu imediatamente no novo gabinete?
   - Não houve "piscar" durante a operação?
   - A operação completou sem erros?

**Resultado esperado:** Cartão movido e toda a série atualizada para o novo gabinete.

---

## TESTE 3: Verificar Série Após Realocação Completa

**Objetivo:** Verificar se a realocação de toda a série afetou outras datas.

**Passos:**
1. Após o TESTE 2, **navegue** para outra data da série (ex: 17/12/2025, 24/12/2025)
2. **Verifique:**
   - O cartão aparece no **novo gabinete** (ex: 102) nessas datas?
   - O cartão **não** aparece mais no gabinete antigo (ex: 101)?

**Resultado esperado:** Todas as datas futuras da série mostram o cartão no novo gabinete.

---

## TESTE 4: Realocar Apenas Um Cartão (Criar Exceção)

**Objetivo:** Mover apenas um cartão específico de uma série, criando uma exceção a partir de uma data.

**Pré-condição:** Deve haver um cartão já alocado que faz parte de uma série.

**Passos:**
1. **Navegue** para uma data **futura** (ex: **17/12/2025**)
2. **Identifique** um cartão já alocado em um gabinete (ex: Teste1 no Gabinete 102)
3. **Arraste** o cartão do gabinete atual para um **gabinete diferente** (ex: Gabinete 103)
4. **Solte** o cartão no novo gabinete
5. Quando aparecer o diálogo perguntando:
   - **Escolha: "Apenas este dia"**
6. **Aguarde** a operação completar
7. **Verifique:**
   - O cartão apareceu imediatamente no novo gabinete?
   - Não houve "piscar" durante a operação?
   - A operação completou sem erros?

**Resultado esperado:** Apenas este cartão específico foi movido, criando uma exceção.

---

## TESTE 5: Verificar Exceção Após Realocação de Um Dia

**Objetivo:** Verificar se a exceção foi criada corretamente e não afetou outras datas.

**Passos:**
1. Após o TESTE 4, **navegue** para a data **anterior** à exceção (ex: 10/12/2025)
2. **Verifique:**
   - O cartão ainda está no gabinete **original** (ex: 102)?
3. **Navegue** para a data da **exceção** (ex: 17/12/2025)
4. **Verifique:**
   - O cartão está no **novo gabinete** (ex: 103)?
5. **Navegue** para uma data **futura** à exceção (ex: 24/12/2025)
6. **Verifique:**
   - O cartão está no gabinete **original** (ex: 102) ou no novo (ex: 103)?
   - Qual comportamento está correto baseado na sua lógica de negócio?

**Resultado esperado:** 
- Datas anteriores: cartão no gabinete original
- Data da exceção: cartão no novo gabinete
- Datas futuras: depende da lógica (se exceção afeta apenas um dia ou a partir daquele dia)

---

## TESTE 6: Realocação Múltipla (Stress Test)

**Objetivo:** Testar múltiplas realocações em sequência para verificar estabilidade.

**Passos:**
1. **Aloque** 3 cartões diferentes em gabinetes diferentes
2. **Realoque** cada um deles para outros gabinetes (escolha "Toda a série" ou "Apenas este dia" alternadamente)
3. **Verifique:**
   - Não há "piscar" excessivo?
   - Todas as operações completam sem erros?
   - Os cartões aparecem nos lugares corretos?

**Resultado esperado:** Sistema estável mesmo com múltiplas operações.

---

## Checklist de Verificação

Após cada teste, verifique:
- [ ] Cartão aparece/disapparece corretamente
- [ ] Não há "piscar" ou flickering excessivo
- [ ] Operações completam sem erros
- [ ] Logs estão sendo capturados (verificar console do Chrome F12)
- [ ] Performance aceitável (sem travamentos)

---

## Logs e Debug

Durante os testes:
- **Console do Chrome (F12):** Verá logs com prefixos como `🟢`, `🔵`, `⚠️`, `❌`
- **Arquivo de log:** `.cursor/debug.log` será criado automaticamente
- **Modo Debug do Cursor:** Capturará dados de runtime para análise

---

## Próximos Passos

Após completar os testes, os logs serão analisados para:
1. Identificar problemas de performance
2. Verificar se atualizações otimistas estão funcionando
3. Confirmar se exceções estão sendo criadas corretamente
4. Detectar problemas de cache ou sincronização

