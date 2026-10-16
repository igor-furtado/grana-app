# Domain Docs

Como as skills de engenharia devem consumir a documentação de domínio deste repositório.

## Antes de explorar

- Leia `CONTEXT.md` na raiz, quando existir.
- Leia os ADRs relevantes em `docs/adr/`.

Se algum desses arquivos não existir, prossiga silenciosamente. A skill de modelagem de domínio cria e atualiza essa
documentação quando decisões ou termos forem definidos.

## Estrutura

Este é um repositório single-context:

```text
/
├── CONTEXT.md
├── docs/
│   ├── adr/
│   └── agents/
└── src/
```

## Vocabulário

Ao nomear conceitos em issues, testes, propostas ou código, use os termos definidos em `CONTEXT.md`.

Se o conceito necessário não estiver no glossário, verifique se ele realmente pertence ao domínio. Caso represente uma
lacuna legítima, encaminhe sua definição para a skill de modelagem de domínio.

## Conflitos com ADRs

Se uma proposta contradizer um ADR existente, indique o conflito explicitamente. Não substitua silenciosamente uma decisão
registrada.
