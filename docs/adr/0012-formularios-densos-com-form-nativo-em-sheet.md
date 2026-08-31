# 0012 - Fluxos modais principais com modal de workspace proporcional

- Status: aceito
- Data: 2026-08-31

## Contexto

Os fluxos modais principais do GranaApp passaram a divergir entre si. Parte do
app dependia de `sheet` com comportamento nativo quase sem adaptacao, enquanto
outros fluxos exigiam composicao mais ampla, sidebar propria e area de trabalho
proporcional ao tamanho atual da janela.

Essa divergencia criou dois problemas:

- o app perdeu um padrao claro para fluxos modais principais;
- `sheet` deixou de atender bem fluxos multi-etapa e formularios densos que
  precisam acompanhar o resize da janela e preservar proporcao util de
  workspace.

Ao mesmo tempo, a linguagem visual do app ja tinha tokens suficientes para
sustentar um modal inline do proprio app, com backdrop materializado e
superficie interna alinhada ao tema, sem depender de drawers legados nem das
limitacoes geometricas de `sheet`.

## Decisao

Adotamos `modal de workspace` como padrao arquitetural para os fluxos modais
principais do app.

- fluxos modais principais usam apresentacao inline sobre a janela atual, com
  dimensoes proporcionais ao viewport e resize responsivo;
- o `modal de workspace` bloqueia interacao com o shell autenticado, centraliza
  o conteudo, mantem foco modal e fecha por acoes explicitas, com suporte
  opcional a `Esc`;
- `sheet` deixa de ser apresentacao canonica para formularios densos e fica
  restrito a confirmacoes curtas e utilitarios pequenos;
- formularios densos podem continuar usando `Form(.grouped)` quando a semantica
  e o comportamento nativo do container fizerem sentido, mas o contrato de
  apresentacao principal passa a ser o `modal de workspace`;
- glass e backdrop com material passam a ser permitidos nesse contexto modal;
  as superficies internas permanecem alinhadas aos tokens quentes e opacos do
  app;
- drawers legados e outras infraestruturas modais paralelas devem convergir
  para o mesmo padrao comportamental e visual.

O padrao se aplica imediatamente aos fluxos modais principais novos e tambem
estabelece meta explicita de migracao para os fluxos modais principais ja
existentes. Confirmacoes curtas, pickers e utilitarios pequenos permanecem em
`sheet` quando esse comportamento for suficiente.

## Consequencias

Positivas:

- o app volta a ter um padrao unico e reconhecivel para fluxos modais
  principais;
- fluxos densos e multi-etapa passam a responder ao tamanho real da janela sem
  perder protagonismo visual;
- a infraestrutura modal deixa de oscilar entre `sheet`, drawer e composicoes
  ad hoc;
- migracoes futuras podem convergir comportamento e linguagem visual em torno do
  mesmo contrato de modal.

Negativas:

- a equipe passa a ser responsavel por preservar manualmente invariantes que o
  `sheet` entregava de forma nativa, como bloqueio modal, foco e fechamento
  previsivel;
- a migracao exige revisar fluxos existentes e eliminar usos de `sheet` que hoje
  representam modais principais do produto.

Neutras:

- `AppUI.Form` continua sem substituir a composicao semantica de cada tela nem
  absorver regras de negocio especificas de um formulario;
- `Form(.grouped)` continua disponivel como primitive de composicao, nao como
  escolha obrigatoria de apresentacao modal.
