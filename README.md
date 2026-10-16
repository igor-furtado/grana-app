# Grana Web

Nova interface web do Grana, construída do zero para navegadores com Vue 3, TypeScript, Vite, Pinia, Tailwind CSS e shadcn-vue sobre Reka UI. A tabela interativa usa TanStack Table para filtragem e ordenação.

Nesta fase, o projeto contém somente a tela de transações. Os dados são fixtures mantidas no estado Pinia em memória: criar, editar, excluir, filtrar e ordenar funcionam durante a sessão, e qualquer alteração desaparece ao recarregar a página.

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
