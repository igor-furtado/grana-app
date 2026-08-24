# Design System Agent Guide

Leia `docs/design-system.md` antes de alterar UI SwiftUI no GranaApp.

- Use `GranaTheme` para tokens visuais. Nao espalhe hex codes nem recrie glass
  localmente.
- Mantenha a fase atual restrita a linguagem visual. Nao importe metricas,
  abas, textos ou modelos dos prototipos sem pedido explicito.
- Preserve toolbars nativas das telas. Nao crie header visual proprio em telas
  padrao quando a toolbar nativa ja carrega titulo/acoes.
- Em telas padrao, use o padding de pagina do tema: topo 0, laterais e base com
  respiro. O rail autenticado acompanha o topo da area util, sem margem superior
  externa.
- Use o rail icon-only como shell autenticado. Todos os itens precisam de
  tooltip e label de acessibilidade.
- Reserve glass para o shell estrutural. Cards de conteudo usam `subtle` sem
  contorno; rows/listas/tabelas usam `solid`, a unica superficie com linha.
- O app e light-only. Nao adicione toggle de tema nem variante dark por inercia.
