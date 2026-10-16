# Issue tracker: GitHub

Issues e especificações deste repositório ficam no GitHub Issues. Use a CLI `gh` para todas as operações.

## Convenções

- Criar: `gh issue create --title "..." --body "..."`
- Ler: `gh issue view <number> --comments`
- Listar: `gh issue list --state open --json number,title,body,labels,comments`
- Comentar: `gh issue comment <number> --body "..."`
- Adicionar rótulo: `gh issue edit <number> --add-label "..."`
- Remover rótulo: `gh issue edit <number> --remove-label "..."`
- Fechar: `gh issue close <number> --comment "..."`

O repositório deve ser inferido pelo remote Git. A CLI `gh` faz isso automaticamente quando executada neste clone.

## Pull requests como superfície de triagem

**PRs como superfície de solicitações: não.**

Issues e pull requests compartilham a mesma numeração no GitHub. Quando uma referência como `#42` for ambígua, tente
`gh pr view 42` e, se não existir, use `gh issue view 42`.

## Quando uma skill disser “publish to the issue tracker”

Crie uma issue no GitHub.

## Quando uma skill disser “fetch the relevant ticket”

Execute `gh issue view <number> --comments`.

## Wayfinding

- O mapa é uma issue com o rótulo `wayfinder:map`.
- Tickets filhos usam sub-issues do GitHub ou, quando indisponíveis, uma task list no mapa.
- Tickets recebem um dos rótulos `wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling` ou `wayfinder:task`.
- Dependências devem usar o recurso nativo de bloqueios do GitHub. Quando indisponível, use `Blocked by: #<n>`.
- Um ticket é elegível quando está aberto, sem bloqueadores abertos e sem responsável.
- Para assumir um ticket: `gh issue edit <n> --add-assignee @me`.
- Para concluir: comente a resposta, feche a issue e registre a decisão no mapa.
