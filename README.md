# Grana Web

Nova interface web do Grana, construída do zero para navegadores com React, TypeScript, Vite, Redux Toolkit, Tailwind CSS e shadcn/ui.

Nesta fase, o projeto contém somente a tela de transações. Os dados são fixtures mantidas no estado Redux em memória: criar, editar, excluir e filtrar funcionam durante a sessão, e qualquer alteração desaparece ao recarregar a página.

O aplicativo macOS anterior, o backend Supabase, os documentos arquiteturais e os protótipos HTML originais estão preservados sem alterações em [`legacy/`](./legacy/).

## Desenvolvimento

Requer Node.js 22 ou mais recente e pnpm.

```bash
pnpm install
pnpm dev
```

## Validação

```bash
pnpm typecheck
pnpm lint
pnpm test
pnpm test:e2e
pnpm build
```

Os testes de componente validam filtros e mutações em memória. O teste Playwright cobre o fluxo principal no navegador.
