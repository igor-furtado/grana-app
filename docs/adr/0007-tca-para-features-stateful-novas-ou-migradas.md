# TCA para features stateful novas ou migradas

Status: accepted

## Contexto

O repositório passou a conviver com dois estilos de gerenciamento de estado.
Parte das telas usa stores `@Observable` acopladas ao `AppContainer`; outra
parte, como Transações, já usa TCA com reducers, dependencies e clients
explícitos.

Esse convívio ficou especialmente custoso em fluxos multi-etapa. Importações,
por exemplo, concentrou histórico, wizard, parsing, deduplicação,
classificação pré-commit, commit final e invalidação cruzada em um único store.
O resultado foi alto acoplamento com `AppContainer`, coordenação espalhada em
views SwiftUI e fronteiras de efeito implícitas.

## Decisão

Features stateful novas ou migradas do GranaApp devem preferir TCA quando
possuírem coordenação multi-etapa, apresentação de subfluxos, efeitos remotos
ou necessidade relevante de composição e teste.

Essa direção implica:

- reducer com `State` e `Action` explícitos;
- efeitos modelados por dependencies em `DependencyValues`;
- clients dedicados como fronteira entre reducer e repositories/serviços;
- subfeatures explícitas quando houver passos complexos ou formatos distintos;
- views SwiftUI sem lógica de orquestração de fluxo;
- `AppContainer` restrito ao composition root e à construção de `liveValue`
  dos clients.

`@Observable` continua aceitável para estado local simples, desde que não
reintroduza coordenação complexa ou acoplamento arquitetural que a feature já
exija modelar melhor.

## Consequências

- Fluxos complexos ficam mais previsíveis, componíveis e testáveis.
- O custo inicial de modelagem aumenta, porque reducers, actions e clients
  exigem mais estrutura do que um store monolítico.
- A fronteira de efeitos fica explícita e revisável, o que reduz dependência
  acidental de `AppContainer`.
- Migrações futuras podem seguir um padrão único para histórico, wizard,
  diálogos, sheets e efeitos assíncronos.
- Features simples e locais não precisam ser forçadas para TCA sem necessidade
  real; a decisão continua guiada pela complexidade do fluxo.
