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
- Modais e sheets podem ocultar a toolbar nativa quando o conteudo introduzir
  titulo inline e barra de acoes no rodape.
- Em telas padrao, use o padding de pagina do tema: topo 0, laterais e base com
  respiro. O rail autenticado acompanha o topo da area util, sem margem
  superior externa.
- Use o rail icon-only como shell autenticado. Todos os itens precisam de
  tooltip e label de acessibilidade.
- Reserve glass para o shell estrutural. Cards de conteudo usam `subtle` sem
  contorno; rows/listas/tabelas usam `solid`, a unica superficie com linha.
- O app e light-only. Nao adicione toggle de tema nem variante dark por inercia.
