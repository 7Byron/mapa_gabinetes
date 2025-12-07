# Guia de Testes - Sistema de Séries Infinitas

## Pré-requisitos
- App rodando
- Acesso à tela de "Editar Médico" ou "Novo Médico"
- Firestore Console aberto (opcional, para verificar dados)

---

## Teste 1: Criar Série Semanal

### Objetivo
Verificar se criar uma série semanal funciona corretamente.

### Passos
1. Abrir "Editar Médico" ou criar um novo médico
2. No calendário, clicar em uma **terça-feira** (ex: 07/01/2026)
3. Escolher **"Semanal"**
4. Verificar mensagem: "Série Semanal criada com sucesso!"
5. Verificar na seção "Séries de Recorrência":
   - Deve aparecer: "Semanal (Terça) - 07/01/2026"
   - Status: "Série infinita"
6. Verificar cartões gerados:
   - Deve aparecer cartões para todas as terças-feiras do ano atual
7. **Salvar o médico**

### Verificações no Firestore (opcional)
- Navegar para: `unidades/{unidadeId}/ocupantes/{medicoId}/series/`
- Deve haver **1 documento** com:
  - `tipo: "Semanal"`
  - `dataInicio: "2026-01-07T00:00:00Z"`
  - `dataFim: null`
  - `ativo: true`

### Resultado Esperado
✅ Série criada com sucesso
✅ Cartões gerados para o ano atual
✅ Apenas 1 documento no Firestore (não 52+)

---

## Teste 2: Múltiplas Séries Simultâneas

### Objetivo
Verificar se um médico pode ter múltiplas séries ao mesmo tempo.

### Passos
1. No mesmo médico do Teste 1
2. No calendário, clicar em uma **quinta-feira** (ex: 09/01/2026)
3. Escolher **"Semanal"**
4. Verificar mensagem: "Série Semanal criada com sucesso!"
5. Verificar na seção "Séries de Recorrência":
   - Deve aparecer **2 séries**:
     - "Semanal (Terça) - 07/01/2026"
     - "Semanal (Quinta) - 09/01/2026"
6. Verificar cartões gerados:
   - Deve aparecer cartões para terças E quintas-feiras
7. **Salvar o médico**

### Verificações no Firestore (opcional)
- Deve haver **2 documentos** na coleção `series/`

### Resultado Esperado
✅ Duas séries criadas simultaneamente
✅ Ambas geram cartões independentemente
✅ 2 documentos no Firestore (não 104+)

---

## Teste 3: Criar Exceção (Férias)

### Objetivo
Verificar se é possível cancelar um período de uma série (ex: férias).

### Passos
1. No mesmo médico com séries criadas
2. Na seção "Séries de Recorrência", encontrar a série "Semanal (Terça)"
3. Clicar no botão **laranja** (ícone de bloqueio) ao lado da série
4. No diálogo:
   - Marcar checkbox: **"Cancelar período (ex: férias)"**
   - Selecionar data inicial: **15/07/2026**
   - Selecionar data final: **31/07/2026**
   - Clicar em **"Confirmar"**
5. Verificar mensagem: "Exceção criada: 15/07/2026 a 31/07/2026"
6. Verificar cartões:
   - As terças-feiras de 15/07, 22/07 e 29/07 **não devem aparecer**
   - Outras terças-feiras continuam aparecendo
7. **Salvar o médico**

### Verificações no Firestore (opcional)
- Navegar para: `unidades/{unidadeId}/ocupantes/{medicoId}/excecoes/2026/registos/`
- Deve haver **3 documentos** (uma exceção para cada terça-feira cancelada)
- Cada exceção deve ter:
  - `serieId: "{id_da_serie}"`
  - `cancelada: true`
  - `data: "{data_cancelada}"`

### Resultado Esperado
✅ Exceções criadas para o período
✅ Cartões cancelados não aparecem
✅ Histórico anterior mantido

---

## Teste 4: Encerrar Série (Médico deixou unidade)

### Objetivo
Verificar se é possível encerrar uma série a partir de uma data, mantendo histórico.

### Passos
1. No mesmo médico
2. Na seção "Séries de Recorrência", encontrar a série "Semanal (Quinta)"
3. Clicar no botão **vermelho** (ícone de stop) ao lado da série
4. No diálogo:
   - Selecionar data de encerramento: **31/12/2026**
   - Clicar em **"Confirmar"**
5. Verificar mensagem: "Série encerrada a partir de 31/12/2026"
6. Verificar na lista de séries:
   - Status mudou para: "Até 30/12/2026"
7. Navegar no calendário para **2027**:
   - Cartões de quintas-feiras em 2027 **não devem aparecer**
   - Cartões de quintas-feiras até 30/12/2026 **devem continuar aparecendo**
8. **Salvar o médico**

### Verificações no Firestore (opcional)
- A série deve ter:
  - `dataFim: "2026-12-30T00:00:00Z"` (dia anterior à data selecionada)

### Resultado Esperado
✅ Série encerrada corretamente
✅ Histórico anterior mantido
✅ Cartões futuros não são gerados

---

## Teste 5: Transformar Série (Mudar frequência)

### Objetivo
Verificar se é possível transformar uma série (ex: de semanal para quinzenal).

### Passos
1. No mesmo médico
2. Na seção "Séries de Recorrência", encontrar a série "Semanal (Terça)"
3. Clicar no botão **azul** (ícone de setas horizontais) ao lado da série
4. No diálogo:
   - **Passo 1**: Selecionar data de encerramento: **14/01/2026**
   - **Passo 2**: Escolher novo tipo: **"Quinzenal"**
   - **Passo 3**: Selecionar data de início da nova série: **15/01/2026** (primeira quarta-feira)
   - Clicar em **"Confirmar"**
5. Verificar mensagem: "Série transformada: Semanal encerrada em 14/01/2026, nova série Quinzenal iniciada em 15/01/2026"
6. Verificar na lista de séries:
   - Série antiga: "Semanal (Terça) - 07/01/2026" → "Até 13/01/2026"
   - Nova série: "Quinzenal (Quarta) - 15/01/2026" → "Série infinita"
7. Verificar cartões:
   - Terças-feiras até 13/01: aparecem
   - Terças-feiras a partir de 14/01: não aparecem
   - Quartas-feiras quinzenais a partir de 15/01: aparecem
8. **Salvar o médico**

### Resultado Esperado
✅ Série antiga encerrada
✅ Nova série criada
✅ Transição suave entre séries

---

## Teste 6: Encerrar Todas as Séries

### Objetivo
Verificar se é possível encerrar todas as séries de uma vez.

### Passos
1. No mesmo médico (deve ter pelo menos 2 séries ativas)
2. Na seção "Séries de Recorrência", clicar no botão **"Encerrar séries a partir de..."**
3. No diálogo:
   - Selecionar data: **31/12/2026**
   - Clicar em **"Confirmar"**
4. Verificar mensagem: "X série(s) encerrada(s) a partir de 31/12/2026"
5. Verificar na lista de séries:
   - Todas as séries devem mostrar: "Até 30/12/2026"
6. **Salvar o médico**

### Resultado Esperado
✅ Todas as séries encerradas simultaneamente
✅ Histórico anterior mantido

---

## Teste 7: Verificar Geração Dinâmica na Tela de Alocação

### Objetivo
Verificar se os cartões são gerados dinamicamente na tela principal de alocação.

### Passos
1. Salvar todas as alterações do médico
2. Voltar para a tela principal de **"Alocação de Médicos"**
3. Navegar para uma **terça-feira** (ex: 14/01/2026)
4. Verificar:
   - O médico deve aparecer na lista "Médicos Disponíveis"
   - Deve mostrar os horários configurados
5. Navegar para uma **quinta-feira** (ex: 16/01/2026)
6. Verificar:
   - O médico também deve aparecer (se a série de quintas ainda estiver ativa)
7. Navegar para uma data **após o encerramento** (ex: 05/01/2027)
8. Verificar:
   - O médico **não deve aparecer** se todas as séries foram encerradas

### Resultado Esperado
✅ Cartões gerados dinamicamente
✅ Aparecem nas datas corretas
✅ Não aparecem em datas futuras após encerramento

---

## Teste 8: Criar Série Mensal

### Objetivo
Verificar se séries mensais funcionam corretamente.

### Passos
1. Criar um novo médico ou usar um existente
2. No calendário, clicar em uma data (ex: primeira terça-feira de janeiro - 07/01/2026)
3. Escolher **"Mensal"**
4. Verificar:
   - Série criada: "Mensal (Terça) - 07/01/2026"
   - Cartões gerados para a primeira terça-feira de cada mês do ano
5. **Salvar o médico**

### Resultado Esperado
✅ Série mensal criada
✅ Cartões gerados para cada mês
✅ Apenas 1 documento no Firestore (não 12+)

---

## Teste 9: Criar Série Consecutiva

### Objetivo
Verificar se séries consecutivas funcionam.

### Passos
1. No calendário, clicar em uma data
2. Escolher **"Consecutivo"**
3. No diálogo, escolher número de dias (ex: 5)
4. Verificar:
   - Série criada: "Consecutivo"
   - Cartões gerados para os 5 dias consecutivos
5. **Salvar o médico**

### Resultado Esperado
✅ Série consecutiva criada
✅ Cartões gerados para os dias consecutivos

---

## Teste 10: Editar Horários de uma Série

### Objetivo
Verificar se é possível editar horários dos cartões gerados de uma série.

### Passos
1. Com uma série criada, verificar os cartões gerados
2. Clicar em um cartão para editar horários
3. Definir horário de início e fim (ex: 10:00 - 14:00)
4. Quando perguntar "Aplicar horário a toda a série?", escolher **"Sim"**
5. Verificar:
   - Todos os cartões da série devem ter os mesmos horários
6. **Salvar o médico**

### Resultado Esperado
✅ Horários aplicados a toda a série
✅ Cartões futuros também terão os mesmos horários

---

## Checklist Final

Após todos os testes, verificar:

- [ ] Séries são criadas corretamente
- [ ] Múltiplas séries funcionam simultaneamente
- [ ] Exceções cancelam períodos corretamente
- [ ] Encerrar séries mantém histórico
- [ ] Transformar séries funciona
- [ ] Cartões são gerados dinamicamente na tela de alocação
- [ ] Apenas 1 documento por série no Firestore (não múltiplos cartões)
- [ ] Histórico anterior é preservado
- [ ] Cartões futuros não são gerados após encerramento

---

## Problemas Conhecidos / Limitações

1. **Horários**: Ao editar horários de um cartão gerado de uma série, ainda não atualiza automaticamente a série. Precisa editar manualmente ou usar "Aplicar a toda a série".

2. **Visualização**: Cartões gerados dinamicamente podem não mostrar claramente que pertencem a uma série (mas isso é intencional para manter compatibilidade).

---

## Dicas de Debug

- Verificar logs no console: procure por `✅ Séries carregadas:` e `✅ Disponibilidades geradas de séries:`
- Verificar Firestore Console para ver documentos criados
- Limpar cache se necessário: reiniciar o app

