# 0012 - Formularios densos com Form nativo em sheet

- Status: aceito
- Data: 2026-08-29

## Contexto

Os formularios principais do GranaApp passaram a divergir entre si. Algumas
telas usavam `Form(.grouped)` com pouca adaptacao visual, enquanto
`TransactionFormView` evoluiu para um drawer proprio com shell e composicao
customizados.

Essa divergencia criou dois problemas:

- o app perdeu um padrao claro para formularios densos;
- a vertical de transacoes passou a depender de uma infraestrutura de drawer que
  nao representava mais a direcao visual escolhida para o produto.

Ao mesmo tempo, a linguagem visual do app ja tinha tokens suficientes para
ajustar formularios nativos sem abandonar o comportamento padrao do macOS.

## Decisao

Adotamos o seguinte padrao para formularios densos do app:

- formularios densos usam `Form(.grouped)` como base de comportamento nativo;
- a apresentacao canonica desses formularios passa a ser `sheet`;
- o drawer de transacoes e sua infraestrutura associada deixam de ser usados;
- `AppUI.Form` passa a concentrar apenas a casca estrutural compartilhada dos
  formularios, como shell, header, footer de acoes, headers/footers de secao e
  mensagem de erro.

O padrao se aplica aos formularios principais e seus parentes proximos de mesma
familia visual, incluindo formularios de contas, cartoes, transacoes, edicao de
datas de fatura, login e modais curtos de confirmacao.

## Consequencias

Positivas:

- o app volta a ter um padrao unico e reconhecivel para formularios;
- os formularios preservam navegacao e comportamento nativos do macOS;
- a vertical de transacoes deixa de depender de uma infraestrutura de drawer
  paralela;
- evolucoes futuras da casca de formularios passam a ter um ponto unico em
  `AppUI.Form`.

Negativas:

- formularios mais complexos, especialmente o de transacoes, perdem parte da
  liberdade de layout do shell totalmente customizado;
- a migracao exige reorganizar views existentes e remover infraestrutura
  associada ao drawer.

Neutras:

- `AppUI.Form` nao substitui a composicao semantica de cada tela nem absorve
  regras de negocio especificas de um formulario.
