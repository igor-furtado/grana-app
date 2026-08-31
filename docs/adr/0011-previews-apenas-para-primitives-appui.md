# 0011 - Remover previews de primitives AppUI

- Status: substituido por 0013
- Data: 2026-08-28

## Contexto

Após a introdução de previews em `AppUI.*`, a política do repositório ficou
assimétrica e adicionou custo de manutenção em componentes visuais que não
fazem parte de um fluxo executável completo.

## Decisão

Retornamos à política única do repositório: `#Preview` não é usado em
componentes, primitives nem telas. A validação visual acontece com o app em
execução.

## Consequências

Positivas:

- O código volta a seguir uma regra simples e uniforme.
- Primitives `AppUI.*` deixam de carregar manutenção paralela de preview.

Negativas:

- Inspeção visual isolada fica mais dependente da execução do app.
