# Finanças

Este contexto organiza a contabilidade financeira de usuários a partir de contas, transações e categorias. O produto apoia
análise e organização; não movimenta dinheiro nem substitui instituições financeiras.

## Identidade e propriedade

**Usuário**:
Pessoa ou organização cuja vida financeira é organizada pelo produto. Contabilidades que não devem se misturar pertencem
a usuários distintos.
_Evite_: Perfil, titular da conta

**Contabilidade**:
Conjunto isolado de contas, transações e classificações financeiras pertencente a um usuário.
_Evite_: Conta, perfil, titularidade

## Estrutura financeira

**Instituição financeira**:
Organização na qual uma ou mais contas são mantidas, como banco ou corretora.
_Evite_: Banco, quando o conceito também puder representar uma corretora

**Conta**:
Local financeiro no qual existe dinheiro ou dívida do usuário. Toda transação pertence a exatamente uma conta.
_Evite_: Banco, instituição financeira, carteira

**Dado financeiro sensível**:
Dado capaz de identificar, distinguir ou expor uma conta, transação ou posição financeira do usuário.
_Evite_: Credencial, quando o dado não autentica acesso

## Transações

**Transação**:
Movimento financeiro ocorrido em uma conta, classificado como receita, despesa ou transferência.
_Evite_: Lançamento, movimentação, operação

**Valor da transação**:
Magnitude monetária positiva de uma transação. A classificação como receita, despesa ou transferência determina seu efeito
financeiro.
_Evite_: Valor assinado, saldo

**Receita**:
Transação que representa ganho ou entrada de dinheiro reconhecida na análise financeira.
_Evite_: Crédito, depósito, recebimento

**Despesa**:
Transação que representa consumo, compra ou saída de dinheiro reconhecida na análise financeira.
_Evite_: Débito, gasto

**Transferência**:
Transação que representa movimentação de valor sem compor receitas ou despesas.
_Evite_: Receita, despesa

## Classificação

**Categoria**:
Classificação principal usada para organizar uma transação.
_Evite_: Tag, grupo
