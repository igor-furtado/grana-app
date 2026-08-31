# GranaApp Design System

## Direcao

O tema e light-only, quente e analitico. A UI deve parecer um painel financeiro
macOS com superfícies translúcidas, tinta escura esverdeada e acento teal. A
mudanca atual e somente de linguagem visual: nao introduza metricas, abas ou
conceitos novos dos prototipos sem contrato de produto e dados.

## Paleta

- `background`: base quente `#f4f0e8`, aplicada como gradiente claro entre
  `#f8f3e8` e `#edf4ef`.
- `ink`: texto principal `#17231f`.
- `muted`: `ink` com opacidade para texto secundario.
- `line`: borda sutil derivada de `ink`.
- `paper`: superficie quente translúcida, proxima de `#fffcf5`.
- `paperSolid`: superficie quente solida `#fffaf0`.
- `teal`: cor de marca e interacao `#117a68`.
- `tealDeep`: estado ativo/pressionado `#0c5f53`.
- `brandGradient`: gradiente `ink` -> `teal`, com `tealDeep` no estado
  pressionado.
- `green`: receita, sucesso financeiro e sinais positivos `#147c56`.
- `red`: despesa, risco e destrutivo `#c9413a`.
- `amber`/`gold`: atencao, destaque analitico e apoio visual.

Preserve a separacao semantica entre marca/interacao e significado financeiro:
teal nao substitui automaticamente receita, despesa ou transferencia.

## Superficies

Use glass no shell estrutural, como o rail autenticado, e tambem no backdrop de
`modal de workspace`. Glass e material nativo recebem overlay quente, sem
contorno aparente e com sombra ampla para separar o chrome ou o plano modal da
tela base.

Cards de conteudo usam superficie `subtle`: preenchimento quente sem blur,
sem borda externa e com sombra baixa para separar grupos analiticos.

Listas densas, tabelas, formularios e rows repetidas usam `solid`: preenchimento
quente solido, sombra baixa e linha `line`. `solid` e a unica superficie base
com contorno de linha aparente.

`Modal de workspace` e o padrao para fluxos modais principais do app. Ele
ocupa area proporcional ao viewport atual, acompanha resize da janela, bloqueia
interacao com o shell, centraliza o conteudo e preserva foco modal. A camada
externa pode usar material; a superficie interna do modal continua seguindo os
tokens quentes do app.

Quando uma feature precisar de primitive visual reutilizavel, use `AppUI.*` como
fachada oficial. `AppUI.Table` encapsula o shell visual padrao das tabelas do
app sobre `SwiftUI.Table`; `AppUI.TextField`, `AppUI.Toggle`, `AppUI.DatePicker`, `AppUI.CurrencyField` e
`AppUI.Selector` concentram os controles de entrada e selecao.

Estado de selecao, ordenacao, filtros e qualquer `load()`/`refresh()` continua
na tela ou store; `AppUI.Table` nao possui estado de dados. `Section`,
agrupamentos semanticos e composicao de formularios continuam na tela chamadora;
os controles `AppUI.*` centralizam o shell visual e, quando cabivel,
`label`, texto de apoio e erro local.

## Navegacao

No estado autenticado, use rail lateral compacto icon-only. Todas as secoes
atuais continuam acessiveis. Dashboard, Transacoes, Cartoes, Contas e Importar
ficam no topo; Design System, Categorias, Instituicoes e Perfil ficam no
rodape. Cada item deve ter tooltip e label de acessibilidade.

Nao desenhe controles falsos de janela macOS dentro do conteudo do app real.
Feature screens podem ocultar a window toolbar nativa quando tiverem header
visual proprio integrado ao tema. Nesses casos, o header inline substitui o
titulo e as acoes primarias da tela, e o primeiro bloco util passa a ser esse
header. `Modal de workspace` e `sheet` tambem podem ocultar a toolbar nativa. O
rail lateral continua alinhado ao topo da area util, sem margem superior
externa, mantendo respiro interno proprio.

`Sheet` deixa de ser o padrao modal principal e fica restrito a confirmacoes
curtas, pickers e utilitarios pequenos.

## Tipografia

Use SF Pro via SwiftUI system fonts. Numeros financeiros usam digitos
monoespacados. Evite serif, fontes decorativas e letter spacing negativo.
Titulos em cards e paineis devem ser compactos;

Texto no app usa exclusivamente tokens em `GranaTheme.Typography`. Views e
componentes nao escolhem tamanho ou peso diretamente com `.font(.system(...))`,
`.font(.title2)`, `.font(.caption)` ou variantes equivalentes. Quando uma
ênfase for necessária, use um token de ênfase (`bodyEmphasis`,
`calloutEmphasis`, `subheadlineEmphasis`, `footnoteEmphasis`,
`caption1Emphasis`, `caption2Emphasis`) em vez de aplicar `.weight(...)` na
view.

Valores financeiros usam a escala `money*` de `GranaTheme.Typography`, sempre
com digitos monoespacados. Use `moneyTitle1`,
`moneyTitle2`, `moneyTitle3`, `moneyHeadline`, `moneyBody`, `moneyCallout`,
`moneySubheadline`, `moneyFootnote`, `moneyCaption1` e `moneyCaption2` conforme
a hierarquia visual. Nao use `money*` para datas, contagens, percentuais ou
codigos tecnicos.

Codigos, slugs, IDs e nomes tecnicos usam `GranaTheme.Typography.code`.
SF Symbols e outros icones nao fazem parte da escala textual; seus tamanhos vêm
de `GranaTheme.IconSize` ou de componentes dedicados como `AppIcon`,
`InstitutionIcon` e `CategoryBadge`.

## Spacing

Distancias entre elementos usam exclusivamente tokens em `GranaTheme.Spacing`.
Isso inclui `spacing`, `padding`, `EdgeInsets` e gaps de grids. Views e
componentes nao usam numeros diretos para respiro, salvo
`GranaTheme.Spacing.none` para ausencia intencional de espaco.

Escala de spacing:

| Token | Valor | Uso |
|---|---:|---|
| `none` | 0 pt | Ausencia intencional de espaco |
| `xxs` | 4 pt | Menor respiro positivo, ajustes densos |
| `xs` | 8 pt | Icone + texto, labels proximas e microgrupos |
| `sm` | 12 pt | Espaco compacto entre elementos de uma row |
| `md` | 16 pt | Padding e gaps padrao de cards e grids |
| `lg` | 20 pt | Separacao entre grupos de uma tela |
| `xl` | 24 pt | Padding top-level e secoes amplas |
| `xxl` | 32 pt | Separacao forte entre blocos majoritarios |
| `xxxl` | 40 pt | Respiro maximo de pagina ou estado vazio |

Quando um spacing existente nao cair exatamente na escala, escolha o token mais
proximo; em empate, arredonde para cima. Qualquer distancia positiva menor que
`xxs` vira `xxs`.

Dimensoes visuais nao sao spacing. Larguras, alturas, tamanhos de icone,
bolinhas, barras, colunas e alturas minimas permanecem como constantes
especificas ou tokens de `Size` quando essa escala existir.

## Aplicacao Inicial

A primeira fase cobre `GranaTheme`, light-only global, rail customizado,
`LoginView`, `EmptyStateView`, `MetricCard`, containers do dashboard e a
convergencia dos fluxos modais principais para `modal de workspace`. Confirmacoes
curtas e utilitarios pequenos podem continuar em `sheet`.
