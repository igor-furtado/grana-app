---
status: superseded by ADR-0004
---

# IDs estáveis para catálogos locais semeados

## Contexto histórico

Esta decisão pertencia ao modelo local-first, no qual categorias e instituições
padrão eram seeds locais do app e registros sincronizados precisavam apontar
para IDs estáveis entre instalações.

## Estado atual

O GranaApp não usa mais catálogos locais como fonte de verdade. Categorias e
instituições são catálogos globais do produto no Supabase, versionados por
migrations e expostos ao app por contratos `api.v1_*`.

O app não deve depender de UUIDs conhecidos para catálogos globais. Sempre que
precisar resolver uma categoria ou instituição por contrato de produto, deve
usar `slug` de categoria ou `code` de instituição.

## Consequência

Esta ADR permanece apenas como registro histórico. A decisão vigente está em
`docs/adr/0004-app-online-only-com-supabase-como-fonte-da-verdade.md`.
