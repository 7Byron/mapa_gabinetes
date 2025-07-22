# Instruções para Configurar Regras de Segurança do Firebase

## Problema Atual
O seu projeto Firebase `mapa-gabinetes-hlcamadora` está com as regras de segurança expiradas há 12 dias. O Firebase bloqueou o acesso porque estava em modo de teste (Test Mode) que deixa o banco completamente aberto.

## Solução

### 1. Aceder ao Firebase Console
1. Vá para [https://console.firebase.google.com](https://console.firebase.google.com)
2. Selecione o projeto `mapa-gabinetes-hlcamadora`

### 2. Configurar Regras de Segurança
1. No menu lateral, clique em **"Firestore Database"**
2. Clique no separador **"Rules"** (Regras)
3. Substitua o conteúdo atual pelas regras do arquivo `firestore.rules` que criámos

### 3. Regras Aplicadas
As regras que criámos permitem:
- ✅ **Leitura e escrita** em todas as coleções principais do seu app
- ✅ **Acesso sem autenticação** (como pretendido)
- ✅ **Proteção básica** contra acesso a coleções não autorizadas
- ✅ **Subcoleções** de disponibilidades dos médicos

### 4. Coleções Cobertas
- `medicos` - dados dos médicos
- `medicos/{id}/disponibilidades` - disponibilidades de cada médico
- `gabinetes` - dados dos gabinetes
- `alocacoes` - alocações de médicos aos gabinetes
- `horarios_clinica` - horários de funcionamento
- `feriados` - lista de feriados
- `especialidades` - especialidades médicas
- `config_clinica` - configurações da clínica

### 5. Segurança
⚠️ **Importante**: Estas regras permitem acesso total sem autenticação. Se quiser mais segurança no futuro, pode:
- Implementar autenticação Firebase
- Adicionar validações de dados
- Limitar operações por tipo (apenas leitura, etc.)

### 6. Testar
Após aplicar as regras:
1. Aguarde alguns minutos para propagação
2. Teste o seu app Flutter
3. Verifique se consegue ler e escrever dados

### 7. Monitorização
- No Firebase Console, vá a **"Firestore Database" > "Usage"**
- Monitore o uso e custos
- Verifique se há tentativas de acesso não autorizadas

## Próximos Passos Recomendados
1. Aplique as regras imediatamente
2. Teste todas as funcionalidades do app
3. Considere implementar autenticação se necessário
4. Configure alertas de uso no Firebase Console

## Suporte
Se tiver problemas após aplicar as regras, contacte o suporte Firebase ou verifique os logs no console. 