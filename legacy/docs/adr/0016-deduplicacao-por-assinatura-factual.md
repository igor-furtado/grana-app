# Deduplicação por assinatura factual

O GranaApp deduplica importações perguntando se já existe hoje uma transação com os mesmos fatos financeiros, não se a mesma linha de origem já foi importada antes. A assinatura factual é gerada pelo app como `dedup_key`, um hash SHA-256 versionado de uma representação canônica dos campos conta, valor, descrição literal, tipo de compra, parcela e data de origem; categoria, subcategoria, notas, data de competência e identificadores externos da fonte não participam da identidade.

Essa decisão substitui a deduplicação canônica baseada em `external_id`/`FITID` descrita no ADR 0004 para o fluxo de importação. Em importações, duplicatas factuais são puladas automaticamente e reportadas no resultado; em fluxos manuais, uma duplicata factual pode ser permitida mediante confirmação explícita do usuário.

## Consequências

- `transactions.id` continua sendo o identificador interno gerado pelo backend.
- A assinatura factual deve ser enviada pelo GranaApp ao backend na importação e em edições que alterem campos participantes da identidade.
- Editar a descrição, valor ou metadados de compra muda a assinatura factual; editar notas, categoria, subcategoria ou data de competência não muda.
- A descrição participa literalmente da assinatura factual: diferenças de caixa, espaços, quebras de linha ou pontuação representam transações diferentes.
- A representação canônica é um JSON ordenado e versionado que preserva literalmente os valores de domínio; campos nulos são marcados explicitamente e não se confundem com strings vazias ou zero.
- O backend valida que a assinatura enviada corresponde aos fatos recebidos, mas não substitui a chave enviada pelo app.
- A versão da assinatura faz parte do material hasheado desde `v1`, permitindo evolução futura da regra sem ambiguidade.
- `external_id`/`FITID` deixa de ser necessário para deduplicação ou rastreabilidade; a rastreabilidade de importação fica apoiada na assinatura factual e no lote de importação.
