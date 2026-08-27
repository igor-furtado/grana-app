# Finanças Pessoais

Este contexto organiza a vida financeira de uma única pessoa a partir de contas, movimentações, categorias e faturas. O produto apoia análise e organização; não movimenta dinheiro nem substitui bancos ou corretoras.

## Identidade e propriedade

**Usuário**:
Pessoa cuja vida financeira é organizada pelo produto. No contexto atual, cada usuário possui um histórico financeiro isolado dos demais.
_Evite_: Household, perfil compartilhado, titular secundário

**Sessão**:
Estado de autenticação remota que permite ao app identificar um usuário e acessar seus dados financeiros. Pode estar ausente ou válida; sem sessão remota válida, o app não exibe dados financeiros.
_Evite_: Conta, perfil

## Estrutura financeira

**Instituição financeira**:
Organização na qual uma ou mais contas do usuário são mantidas, como banco ou corretora.
_Evite_: Banco, quando o conceito também puder representar uma corretora

**Instituição financeira suportada**:
Instituição financeira reconhecida pelo produto para criação de contas. Quando uma instituição não é suportada, o usuário não cria conta para ela até que o produto trate suas particularidades.
_Evite_: Outra instituição, banco genérico

**Conta**:
Local financeiro no qual existe dinheiro ou dívida do usuário. Toda transação pertence a exatamente uma conta.
_Evite_: Banco, instituição, carteira

**Conta corrente**:
Conta que representa dinheiro disponível em uma instituição financeira.
_Evite_: Conta bancária, quando for necessário distingui-la de outros tipos de conta

**Cartão de crédito**:
Conta que representa compras a crédito e a dívida associada a elas. Suas compras são organizadas em faturas.
No modelo persistente atual, permanece sob o agregado central de conta com detalhes específicos de cartão. Na arquitetura
do app, porém, a vertical de Cartões é autônoma e não depende da feature de contas bancárias.
Mantém datas padrão atuais de fechamento e vencimento para criação automática de novas faturas.
_Evite_: Cartão, conta-cartão, conta corrente

**Datas padrão do cartão**:
Fechamento e vencimento atuais do cartão de crédito usados para criar novas faturas automaticamente. Não representam necessariamente as datas históricas das faturas antigas.
_Evite_: Datas da fatura, quando estiver falando da configuração atual do cartão

**Saldo inicial**:
Valor da conta no ponto anterior ao primeiro histórico acompanhado pelo produto.
_Evite_: Saldo atual, patrimônio

## Movimentações

**Transação**:
Movimento financeiro ocorrido em uma conta, classificado como receita, despesa ou transferência. Seu valor é sempre expresso como magnitude positiva; a classificação determina seu efeito financeiro.
_Evite_: Lançamento, movimentação, operação

**Receita**:
Transação que representa ganho ou entrada de dinheiro reconhecida na análise financeira.
_Evite_: Crédito, depósito, recebimento

**Despesa**:
Transação que representa consumo, compra ou saída de dinheiro reconhecida na análise financeira.
_Evite_: Débito, gasto

**Transferência**:
Transação que representa movimentação de valor sem compor receitas ou despesas. Quando ocorre entre contas próprias acompanhadas, distingue uma conta de origem e uma conta de destino.
_Evite_: Receita, despesa

**Conta de destino**:
Conta própria que recebe o valor de uma transferência.
_Evite_: Favorecido, contraparte

## Classificação

**Categoria**:
Classificação principal de uma transação, pertencente a um único tipo: receita, despesa ou transferência.
_Evite_: Tag, grupo

**Categoria padrão**:
Categoria disponibilizada pelo produto para todos os usuários. No MVP, usuários classificam transações apenas com categorias padrão.
_Evite_: Categoria personalizada

**Subcategoria**:
Classificação específica subordinada a uma categoria e do mesmo tipo dela.
_Evite_: Categoria filha, tag

**Não Classificado**:
Categoria de despesa usada quando a classificação definitiva ainda requer revisão.
_Evite_: Outros, desconhecido

## Cartão e faturas

**Fatura**:
Ciclo de compras de um cartão de crédito, identificado por suas próprias datas de fechamento e vencimento. Reúne as transações de cartão que pertencem ao intervalo encerrado por sua data de fechamento.
_Evite_: Extrato, boleto, invoice

**Mês da fatura**:
Mês civil usado para nomear a fatura na interface, determinado pela data de vencimento da fatura.
_Evite_: Mês de fechamento, quando estiver nomeando a fatura

**Período da fatura**:
Intervalo de compras coberto por uma fatura, começando no dia seguinte ao fechamento da fatura anterior do mesmo cartão e terminando de forma inclusiva na data de fechamento da própria fatura.
_Evite_: Período do cartão, quando estiver falando de uma fatura específica

**Data de fechamento**:
Data civil própria da fatura que encerra seu período de compras no fuso do usuário. Alterar essa data pode realocar transações entre faturas do mesmo cartão.
_Evite_: Data de corte

**Data de vencimento**:
Data própria da fatura prevista para quitação. Alterar essa data muda o vencimento registrado para aquela fatura, sem por si só definir o período de compras.
_Evite_: Data de pagamento

**Realocação de transações**:
Mudança automática de vínculo de transações entre faturas do mesmo cartão após alteração de data de fechamento. A realocação preserva as transações originais e recalcula os totais das faturas afetadas.
_Evite_: Reimportação, quando as transações já existem no produto

**Pagamento de fatura**:
Aplicação de uma transferência a uma ou mais faturas, com cada aplicação vinculada à fatura que o pagamento quitou. Quando uma correção posterior muda o total da fatura, o vínculo do pagamento permanece auditável e qualquer diferença deve ficar visível para ajuste pelo usuário.
_Evite_: Compra, despesa, baixa

**Pagamento excedente**:
Diferença visível quando os pagamentos vinculados a uma fatura superam o total a quitar depois de uma correção de datas, transações ou valores.
_Evite_: Saldo credor, quando o excedente veio de pagamento vinculado

**Diferença pendente**:
Diferença visível quando o total a quitar de uma fatura supera os pagamentos vinculados depois de uma correção de datas, transações ou valores.
_Evite_: Atraso, quando a divergência ainda é uma pendência de reconciliação

**Estorno de cartão**:
Reversão total ou parcial de uma compra específica, lançada no ciclo da data do estorno. Uma compra pode receber vários estornos, cuja soma não pode superar seu valor original.
_Evite_: Receita, pagamento, compra negativa

**Fatura em formação**:
Fatura cujo ciclo de compras ainda não alcançou a data de fechamento. Pode receber novas compras e estornos mesmo quando seu saldo restante estiver integralmente coberto.
_Evite_: Fatura aberta, fatura futura

**Fatura fechada**:
Fatura cujo ciclo de compras alcançou a data de fechamento e não recebe novos lançamentos ordinários.
_Evite_: Fatura paga, fatura quitada

**Fatura paga**:
Fatura fechada cujo total foi integralmente coberto por pagamentos.
_Evite_: Fatura quitada, quando a cobertura não depender exclusivamente de pagamento

**Fatura quitada**:
Fatura fechada cujo total não apresenta diferença pendente.
_Evite_: Fatura paga, quando não houver pagamento

**Data de quitação**:
Momento em que pagamentos e saldos credores passaram a cobrir integralmente o total de uma fatura.
_Evite_: Data de pagamento, quando a quitação não depender exclusivamente de pagamento

**Total da fatura**:
Valor líquido a quitar em um ciclo, resultante das compras menos os estornos vinculados à fatura. Os componentes permanecem distinguíveis para auditoria.
_Evite_: Soma das compras, saldo restante

**Saldo credor da fatura**:
Crédito visível quando os estornos vinculados a uma fatura superam suas compras. Não é propagado automaticamente para faturas seguintes no MVP.
_Evite_: Pagamento antecipado, receita, desconto

## Importação e classificação

**Extrato**:
Registro emitido por uma instituição financeira com as transações de uma conta em determinado período.
_Evite_: Fatura, histórico do produto

**Importação**:
Entrada de transações provenientes de um arquivo financeiro para revisão e incorporação ao histórico.
_Evite_: Sincronização, integração bancária

**Lote de importação**:
Conjunto de transações incorporadas a partir de um mesmo extrato de conta, tratado como uma unidade reversível.
_Evite_: Arquivo, upload

**Classificação pré-commit**:
Classificação inicial aplicada às transações importadas antes de sua incorporação definitiva. Ela serve como ponto de
partida para revisão manual, mas não representa ainda a decisão final do usuário.
_Evite_: Categorização automática, categorização por IA remota

**Classificação confirmada**:
Classificação final de uma transação importada após revisão do usuário e confirmação do lote de importação.
_Evite_: Sugestão, rascunho, palpite

**Feedback de classificação**:
Envio das classificações confirmadas pelo usuário ao classificador local para influenciar classificações futuras.
_Evite_: Persistência no backend, revisão parcial, cache do app

**Memória de classificação**:
Conjunto de classificações confirmadas usado pelo classificador local para influenciar classificações futuras. Essa
memória pertence exclusivamente ao GranaAI e não integra o histórico financeiro persistido do produto.
_Evite_: Histórico financeiro do produto, cache do app, dado do backend
