# Faturas com datas próprias editáveis

Status: accepted

Faturas de cartão passam a ser registros com datas próprias de fechamento e vencimento, editáveis pelo usuário para reconciliar o histórico do produto com o banco. As datas padrão atuais do cartão são usadas apenas para criar novas faturas automaticamente; depois que uma fatura existe, suas datas não devem ser sobrescritas por recálculos automáticos.

Ao alterar a data de fechamento de uma fatura, o backend realoca compras e créditos entre faturas do mesmo cartão usando a data civil da transação no fuso do usuário, com fechamento inclusivo. Pagamentos de fatura permanecem vinculados à fatura onde foram registrados, mesmo que a realocação gere pagamento excedente ou diferença pendente; essas diferenças ficam visíveis para ajuste pelo usuário.

Essa decisão substitui o modelo anterior em que faturas eram reconstruídas destrutivamente a partir das datas do cartão e em que saldos credores eram propagados automaticamente entre faturas. Totais, saldos, pagamentos excedentes e diferenças pendentes devem ser tratados como leitura calculada a partir de faturas, transações, créditos e pagamentos vinculados, não como motivo para redistribuir pagamentos ou créditos silenciosamente.
