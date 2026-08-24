# GranaApp Design System

Fonte canonica da linguagem visual do GranaApp. Os prototipos de referencia sao
`GranaApp/Prototypes/DashboardDesignSystemPrototype.html`,
`GranaApp/Prototypes/ContentUnavailablePrototype.html` e, para navegacao,
`GranaApp/Prototypes/NavigationMenuPrototype.html`.

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

Use glass forte em shell, login, estados vazios e cards principais. Glass e
material nativo com overlay quente, borda `line` e sombra ampla. Quando o macOS
reduzir transparencia ou aumentar contraste, glass deve degradar para superficie
quente mais solida com borda mais evidente.

Listas densas, tabelas, formularios e rows repetidas usam `paper`/`paperSolid`
semi-opaco sem blur pesado. O objetivo e manter leitura e performance.

## Navegacao

No estado autenticado, use rail lateral compacto icon-only. Todas as secoes
atuais continuam acessiveis. Dashboard, Transacoes, Cartoes, Contas e Importar
ficam no topo; Design System, Categorias, Instituicoes e Perfil ficam no
rodape. Cada item deve ter tooltip e label de acessibilidade.

Nao desenhe controles falsos de janela macOS dentro do conteudo do app real.
Mantenha toolbars nativas das telas nesta fase.

## Tipografia

Use SF Pro via SwiftUI system fonts. Numeros financeiros usam digitos
monoespacados. Evite serif, fontes decorativas e letter spacing negativo.
Titulos em cards e paineis devem ser compactos; hero-scale type fica restrito a
login e estados vazios.

## Aplicacao Inicial

A primeira fase cobre `GranaTheme`, light-only global, rail customizado,
`LoginView`, `EmptyStateView`, `MetricCard` e containers do dashboard. Telas
densas existentes devem receber apenas ajustes minimos de fundo/superficie ate
que sejam redesenhadas explicitamente.
