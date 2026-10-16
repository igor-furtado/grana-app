# TCA para features stateful novas ou migradas

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
