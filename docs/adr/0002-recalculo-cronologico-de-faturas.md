# Recálculo cronológico de faturas

Status: superseded by ADR-0008

## Contexto

Correções retroativas em compras, estornos ou pagamentos podem mudar faturas
posteriores do mesmo cartão. O app precisa permitir correções históricas sem
gerar estados diferentes conforme a ordem de edição do usuário.

## Decisão

Alterações que afetam um cartão reprocessam, em ordem cronológica e numa única
transação de banco, as faturas, os saldos credores e os pagamentos do cartão
afetado.

Saldos credores são consumidos antes dos pagamentos. Cada pagamento só cobre
dívidas já existentes em sua data. Uma alteração é rejeitada se deixar parte da
transferência de pagamento sem aplicação.

## Consequências

- O resultado é determinístico para qualquer correção histórica.
- Faturas continuam materializadas com snapshots de fechamento e vencimento.
- O backend Supabase é a autoridade do recálculo; o GranaApp apenas envia a
  mutação e recarrega os read models afetados.
