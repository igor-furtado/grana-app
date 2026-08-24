# Design System Agent Guide

Leia `docs/design-system.md` antes de alterar UI SwiftUI no GranaApp.

- Use `GranaTheme` para tokens visuais. Nao espalhe hex codes nem recrie glass
  localmente.
- Mantenha a fase atual restrita a linguagem visual. Nao importe metricas,
  abas, textos ou modelos dos prototipos sem pedido explicito.
- Preserve toolbars nativas das telas ate uma etapa de redesenho dedicada.
- Use o rail icon-only como shell autenticado. Todos os itens precisam de
  tooltip e label de acessibilidade.
- Reserve glass para o shell estrutural. Cards de conteudo usam `subtle` sem
  contorno; rows/listas/tabelas usam `solid`, a unica superficie com linha.
- O app e light-only. Nao adicione toggle de tema nem variante dark por inercia.
