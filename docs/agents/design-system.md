# Design System Agent Guide

Leia `docs/design-system.md` antes de alterar UI SwiftUI no GranaApp.

- Use `GranaTheme` para tokens visuais. Nao espalhe hex codes nem recrie glass
  localmente.
- Use `GranaTheme.Typography` para toda tipografia textual em SwiftUI. Views e
  componentes nao definem tamanho/peso localmente com `.font(.system(...))`,
  `.font(.title2)`, `.font(.caption)` nem `.weight(...)`; escolha um token
  textual, de enfase, `money*` ou `code`.
- Reserve `money*` para valores financeiros. Datas, contagens, percentuais e
  codigos tecnicos usam tokens textuais ou `code`.
- SF Symbols e icones ficam fora de `Typography`: use `GranaTheme.IconSize` ou
  componentes dedicados.
- Use `GranaTheme.Spacing` para distancias entre elementos: `spacing`,
  `padding`, `EdgeInsets` e gaps de grids. Use `GranaTheme.Spacing.none` para
  ausencia intencional de espaco, e nao converta dimensoes visuais como
  larguras, alturas, bolinhas, barras ou colunas; esses valores pertencem a
  tokens de size ou constantes especificas.
- Se um spacing existente nao existir na escala, use o token mais proximo; em
  empate, arredonde para cima. Qualquer distancia positiva menor que `xxs` vira
  `xxs`.
- Mantenha a fase atual restrita a linguagem visual. Nao importe metricas,
  abas, textos ou modelos dos prototipos sem pedido explicito.
- Feature screens podem ocultar a window toolbar nativa quando tiverem header
  proprio alinhado ao tema. Nesses casos, o header inline assume titulo e acoes
  primarias da tela.
- Use o rail icon-only como shell autenticado. Todos os itens precisam de
  tooltip e label de acessibilidade.
- Reserve glass para o shell estrutural. Cards de conteudo usam `subtle` sem
  contorno; rows/listas/tabelas usam `solid`, a unica superficie com linha.
- Use `.sheet` nativo do SwiftUI como padrao unico de apresentacao modal. Aceite
  o scrim nativo do sistema; nao recrie overlay bloqueante para controlar a
  opacidade do fundo.
- Varie apenas a classe de tamanho da sheet: `compact` para confirmacoes e
  utilitarios pequenos, `medium` para formularios e edicoes moderadas, e `large`
  para fluxos principais ou multi-etapa. Use `AppUI.Modal.SheetSize` para as
  dimensoes padrao.
- Conteudo interno de sheet sempre segue `ZStack { GranaBackground();
  AppUI.Form.Shell { AppUI.Form.Header; conteudo/Form; erro opcional;
  AppUI.Form.Actions } }`, com toolbar oculta. Nao crie card, surface, scrim ou
  container proprio dentro da sheet.
- Sheets compactas usam largura fixa (`AppUI.Modal.SheetSize.compactWidth`) e
  altura intrinseca com `.presentationSizing(.fitted)`. Nao defina altura fixa
  para confirmacoes compactas.
- Em confirmacoes compactas, mensagens curtas ficam em `Header.subtitle`;
  mensagens de impacto adicionais podem aparecer como texto no corpo, sem icone
  decorativo. Acoes ficam no rodape: cancelar primeiro, confirmar depois.
- Quando uma tela precisar de fundacao visual reutilizavel, prefira `AppUI.*`
  em vez de instanciar `SwiftUI` direto. Isso inclui `AppUI.Table`,
  `AppUI.TextField`, `AppUI.Toggle`, `AppUI.DatePicker`,
  `AppUI.CurrencyField` e `AppUI.Selector`. Use `AppUI.Layout.*` para shells
  estruturais recorrentes, como o header inline das feature screens.
- Use `AppUI.Skeleton` para carregamentos de conteudo financeiro ou telas
  densas. A fundacao deve expor somente primitivas visuais, como `Line`, `Block`
  e `Circle`; skeletons compostos ficam nas features.
- O skeleton aparece no menor escopo que possui `isLoading` proprio. Se apenas
  a feature pai carrega, o skeleton cobre o conteudo da feature pai. Se uma
  subfeature ou bloco TCA carrega, o skeleton cobre somente essa area. Para
  loading granular, extraia estado/reducer granular em vez de inferir escopo na
  view.
- Prefira skeleton contextual enxuto: preserve a hierarquia e o formato da tela
  real com poucos placeholders. Nao replique cada dado futuro nem use skeleton
  generico centralizado quando a feature conhece melhor o layout.
- Reserve `ProgressView` para tarefas pequenas, controles inline, progresso
  real ou fluxos sem estrutura de conteudo suficiente para skeleton contextual.
- `AppUI.Table` e o ponto de entrada para tabelas.
  O wrapper concentra o shell visual; estado de dados, selecao, ordenacao,
  filtros e refresh continuam fora dele.
- Campos `AppUI.*` podem concentrar `label`, texto de apoio e erro local,
  mas nao substituem `Section` nem o agrupamento semantico maior da tela.
- `#Preview` so e permitido no target `AppUI`.
  Primitives e base visual extraidas podem ter preview local; features, telas e
  qualquer codigo fora de `AppUI` continuam validados com o app em execucao.
- O app e light-only. Nao adicione toggle de tema nem variante dark por inercia.
