# Vue 3 com Pinia e shadcn-vue

## Status

Aceita em 2026-10-16.

## Contexto

A primeira versão web da interface foi criada com React, Redux Toolkit e shadcn/ui. Para facilitar o acompanhamento arquitetural e manter template, comportamento e composição visual próximos, foi escolhida a organização por Single-File Components do Vue 3.

Não existe uma biblioteca oficial de componentes mantida pelo time do Vue. PrimeVue é mais abrangente, mas mantém componentes e decisões de tema como dependência. Nuxt UI privilegia o ecossistema Nuxt. Vuetify adota Material Design. Essas opções são maduras, porém se alinham menos à propriedade local do código e à direção visual já escolhida.

## Decisão

O cliente web usa Vue 3, TypeScript e Vite. Pinia mantém somente o estado compartilhado da feature; estado transitório de apresentação permanece nos componentes Vue. Tailwind CSS compõe o layout e os estilos. shadcn-vue, no preset Reka Nova, adiciona ao repositório os componentes visuais construídos sobre Reka UI.

Tabelas que precisem de comportamento interativo usam TanStack Table como motor headless. O shadcn-vue continua responsável pela composição visual, enquanto filtros, ordenação e modelos derivados de linhas permanecem como estado local da tela.

Os dados continuam sendo fixtures em memória. Não há backend, autenticação, persistência, roteamento nem domínio definitivo nesta fase.

## Consequências

- Single-File Components tornam explícita a unidade de cada parte da interface.
- A store Pinia é descartada ao recarregar e poderá receber um adapter de backend futuramente.
- Os componentes shadcn-vue pertencem ao projeto e podem ser adaptados sem esperar por uma API externa da biblioteca.
- Acessibilidade de diálogos e seletores depende das primitives Reka UI e dos testes de interação.
- A decisão substitui, para o novo cliente web, a stack React registrada no ADR legado `0017-interface-web-first-com-shadcn-ui.md`.
