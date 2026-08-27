# Propagação de saldo credor entre faturas

Status: superseded by ADR-0008

## Contexto

Estornos de cartão podem tornar o total líquido de uma fatura negativo. Esse
saldo não é receita, não é pagamento antecipado e não deve alterar compras já
registradas. O produto precisa preservar a origem do crédito e manter a
auditoria dos ciclos seguintes.

## Decisão

Quando os estornos de uma fatura superam suas compras, o saldo credor excedente
é aplicado explicitamente às faturas seguintes do mesmo cartão de crédito,
atravessando quantos ciclos forem necessários até ser consumido.

O crédito é vinculado entre faturas com seu valor aplicado. Ele não cria
transação fictícia, não edita compras originais e não vira receita.

## Consequências

- `Total da fatura` é sempre calculado a partir de compras, estornos,
  pagamentos e saldos credores aplicados.
- `Saldo credor da fatura` pode quitar uma fatura sem pagamento.
- `Crédito pendente do cartão` existe quando ainda não há fatura posterior
  materializada para receber o excedente.
- O recálculo dessa propagação mora no backend Supabase, junto das regras
  transacionais de fatura.
