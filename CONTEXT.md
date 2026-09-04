# Finanças Pessoais

Este contexto organiza a vida financeira de uma única pessoa a partir de contas, movimentações, categorias e faturas. O produto apoia análise e organização; não movimenta dinheiro nem substitui bancos ou corretoras.

## Identidade e propriedade

**Usuário**:
Pessoa cuja vida financeira é organizada pelo produto. No contexto atual, cada usuário possui um histórico financeiro isolado dos demais.
_Evite_: Household, perfil compartilhado, titular secundário

**Sessão**:
Estado de autenticação remota que permite ao app identificar um usuário e acessar seus dados financeiros. Pode estar ausente ou válida; sem sessão remota válida, o app não exibe dados financeiros.
_Evite_: Conta, perfil

**Método de acesso**:
Forma de autenticação remota aceita pelo produto para criar conta nova ou recuperar acesso, como Sign in with Apple e Email OTP. Um método de acesso não define a identidade canônica do usuário.
_Evite_: Usuário, conta, provedor

**Vinculação de acesso**:
Decisão explícita do usuário de associar um novo método de acesso a uma conta existente. A vinculação não acontece automaticamente apenas por coincidência ou semelhança entre atributos de login.
_Evite_: Merge automático, dedução de identidade

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
Movimento financeiro ocorrido em uma conta, classificado como receita, despesa ou transferência. Seu valor é sempre expresso como magnitude positiva; a classificação determina seu efeito financeiro. Toda transação carrega data de competência e data de origem.
_Evite_: Lançamento, movimentação, operação

**Tipo de compra**:
Classificação estrutural de uma compra de cartão usada para auditoria e deduplicação. Pode ser à vista ou parcelada.
_Evite_: Texto bruto do banco, modalidade informal

**Índice da parcela**:
Posição ordinal de uma compra parcelada dentro da sua série, contada a partir de 1. Não se aplica a compras à vista.
_Evite_: Número solto da parcela, quando faltar a noção de ordem na série

**Quantidade total de parcelas**:
Total de parcelas previsto para uma compra parcelada. Não se aplica a compras à vista.
_Evite_: Última parcela, duração, quando o sentido for o total contratado

**Data de competência**:
Data principal de uma transação para efeitos de filtros, dashboards, ordenação e vínculo com faturas. Em compras parceladas importadas, representa a competência da parcela informada pela linha de origem, somando à data de origem a quantidade de meses equivalente ao índice da parcela menos um.
_Evite_: Data real, quando estiver distinguindo da data informada pela fonte

**Data de origem**:
Data usada para identificar duplicações de transações e, quando a transação vem de uma fonte externa, preserva a data informada pela origem para auditoria. Em compras parceladas importadas, serve como base para determinar a data de competência da parcela informada.
_Evite_: Data principal, data de competência

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

**Crédito em fatura**:
Transação positiva lançada no cartão de crédito que reduz o total a quitar da fatura do próprio ciclo. Pode representar saldo, bônus, presente, ajuste ou outro crédito informado pela instituição, sem vínculo obrigatório com outra transação.
_Evite_: Estorno vinculado, pagamento, compra negativa

**Fatura em formação**:
Fatura cujo ciclo de compras ainda não alcançou a data de fechamento. Pode receber novas compras e créditos mesmo quando seu saldo restante estiver integralmente coberto.
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
Valor líquido a quitar em um ciclo, resultante das compras menos os créditos da própria fatura. Os componentes permanecem distinguíveis para auditoria.
_Evite_: Soma das compras, saldo restante

**Saldo da fatura**:
Crédito visível quando os créditos de uma fatura superam suas compras. Não é propagado automaticamente para faturas seguintes no MVP.
_Evite_: Pagamento antecipado, receita, desconto

## Importação e classificação

**Extrato**:
Registro emitido por uma instituição financeira com as transações de uma conta em determinado período.
_Evite_: Fatura, histórico do produto

**Importação**:
Entrada de transações provenientes de um arquivo financeiro para revisão e incorporação ao histórico. Cada linha real importada pode gerar no máximo uma transação no histórico.
_Evite_: Sincronização, integração bancária

**Linha importada**:
Registro individual lido de um arquivo financeiro. Mesmo quando representa uma parcela de compra, não autoriza o produto a criar transações para parcelas ausentes do arquivo.
_Evite_: Série parcelada, quando estiver falando da evidência importada

**Triagem**:
Primeira etapa do wizard de importação, imediatamente após a leitura do arquivo, em que o usuário distingue transações já importadas, transações que não serão importadas e transações prontas para importação, podendo selecionar ou desmarcar apenas as elegíveis.
_Evite_: Revisão, quando estiver falando da etapa final pós-classificação

**Classificação**:
Etapa intermediária do wizard de importação em que o classificador local produz classificações iniciais para as transações elegíveis antes da revisão final do usuário.
_Evite_: Triagem, revisão manual

**Revisão**:
Etapa final do wizard de importação em que o usuário revisa as classificações propostas, com foco primeiro nas transações não classificadas automaticamente e nas demais que exigem mais atenção.
_Evite_: Triagem, quando estiver falando da conferência inicial do arquivo

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
