# PowerSync

Artefatos versionados da integração de sync do app com Supabase.

## O que está neste diretório

- `sync-streams.yaml`: configuração canônica de download do PowerSync.

## Como aplicar no ambiente remoto

1. Rode as migrations do diretório `supabase/migrations/`.
2. No Supabase SQL Editor, crie o usuário de replicação do PowerSync com uma senha forte fora do Git:

```sql
create role powersync_role
with replication bypassrls login password '<senha-forte>';

grant select on all tables in schema public to powersync_role;
alter default privileges in schema public grant select on tables to powersync_role;
```

3. No PowerSync Dashboard:
   - conecte a instância ao Postgres do Supabase usando `powersync_role`
   - habilite Supabase Auth
   - cole o conteúdo de `sync-streams.yaml` na tela de Sync Streams
   - valide e faça deploy

## Observações

- RLS no Supabase continua sendo a regra autoritativa de segurança para uploads.
- A Sync Stream só controla o download inicial e os updates remotos enviados a cada cliente.
- `categories` e `institutions` não entram no stream porque permanecem catálogos locais semeados com IDs estáveis.
