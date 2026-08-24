# App online-only com Supabase como fonte da verdade

O app passa a operar em modo online-only estrito: sem sessão remota válida e conexão disponível, dados financeiros não são exibidos nem editados. O Supabase Postgres passa a ser a fonte única de verdade para transações, contas, faturas, categorias, instituições, cache de IA e correções, substituindo o banco local, PowerSync, seeds locais e fluxos offline-first; como não há usuários reais, não haverá migração de dados locais.

Leituras simples devem usar `supabase-swift` pela Data API com RLS e grants mínimos quando isso preservar bem o contrato da tela. Escritas e operações com invariantes financeiras, como importação, pagamentos, estornos, projeção de faturas e recálculos cronológicos, devem ser feitas por funções/RPC ou Edge Functions para que o backend mantenha atomicidade e autoridade sobre o domínio.

Telas compostas devem preferir read models estáveis expostos pelo backend, enquanto listas simples e catálogos podem usar leitura direta quando o contrato continuar claro. Tabelas financeiras não devem conceder escrita direta ao app; `INSERT`, `UPDATE` e `DELETE` passam por funções controladas. O app pode manter sessão/token local de autenticação, mas não dados financeiros locais; se a conexão falhar, mostra indisponibilidade sem exibir dados.

Categorias e instituições padrão passam a ser catálogos globais do produto e somente leitura para o usuário. O app não deve depender de IDs conhecidos desses catálogos; deve resolver referências por slug ou código. A importação mantém parsing e preview no app, mas envia payload estruturado para commit atômico no backend.

Funções Postgres RPC serão usadas para regras financeiras atômicas, e Edge Functions para IA, categorização, payloads HTTP ricos e orquestração externa. Quando uma Edge Function precisar alterar dados financeiros, ela deve delegar a mutação a uma função RPC em vez de montar escritas financeiras diretamente.

Deduplicação de importação é uma garantia canônica do backend: a função de commit deve aplicar a regra e o banco deve ter constraint única adequada para impedir duplicatas sob concorrência. Se um lote contiver transações já importadas, o backend deve pular as duplicatas, importar o restante e retornar relatório.

A pseudonimização semântica fica sob autoridade do backend antes de chamar providers externos de IA. Categorias personalizadas ficam fora do MVP. Instituições financeiras são restritas ao catálogo global suportado; se uma instituição não estiver no catálogo, o usuário não pode criar conta para ela até o produto tratar suas particularidades.

Schema, políticas RLS, grants, funções RPC, views/read models e seeds globais devem viver como migrations SQL versionadas no repositório. O schema `public` deve expor apenas contratos necessários ao app; lógica interna e funções sensíveis devem ficar em schemas privados, como `app_private`.

Todas as tabelas financeiras do usuário devem ter propriedade por `user_id` e RLS baseada em `auth.uid()`, mesmo quando a escrita direta estiver bloqueada e as mutações ocorrerem por RPC. Catálogos globais não têm `user_id`, são somente leitura para usuários autenticados e são alterados apenas por migrations/admin.

Telas compostas devem consumir read models expostos como views seguras ou RPCs que retornam DTOs estáveis, em vez de remontar joins e agregações complexas no Swift. Valores monetários continuam representados em centavos inteiros no banco e `Decimal` no Swift. Instantes de transações e auditoria usam `timestamptz`; datas civis de fatura, como fechamento e vencimento, usam `date`.

O backend gera os UUIDs dos registros financeiros persistidos. O app pode enviar IDs temporários ou chaves de idempotência em fluxos como importação, mas não é autoridade dos identificadores finais. As decisões de saldo credor e recálculo cronológico das faturas continuam válidas; sua implementação passa a morar no backend.

Payload estruturado enviado pelo app no commit de importação é tratado como não confiável. O backend revalida conta, categoria, instituição, duplicidade, fatura e estorno antes de persistir. A primeira refatoração não deve introduzir Realtime; telas usam fetch e refresh até existir um caso concreto.

A refatoração deve avançar por fatias verticais, criando o contrato backend de uma área, migrando a feature no app e removendo o equivalente local daquela área. A primeira fatia será catálogos e contas. No Swift, Stores continuam falando com repositories; a implementação dos repositories passa a ser remota, usando Supabase, sem expor Supabase diretamente às Views.

Stores deixam de usar streams `watch()` e passam a ter `load()` e `refresh()` explícitos. Após mutações bem-sucedidas, recarregam os read models afetados. O MVP não usa optimistic UI para mutações financeiras; a UI só muda após confirmação do backend. Durante uma sessão válida, dados financeiros podem existir em memória, mas não podem ser persistidos em `UserDefaults`, arquivos, banco local ou caches em disco.

RPCs e Edge Functions devem retornar códigos de erro de domínio estáveis para o app mapear em PT-BR. Mutações compostas e sujeitas a retry, especialmente importação, devem receber chaves de idempotência geradas pelo app. O desenvolvimento de schema, RLS e RPCs deve usar Supabase CLI/local dev antes de aplicar mudanças em projeto remoto.

No MVP, exclusões financeiras preservam a semântica atual de hard delete, sempre mediadas por RPC transacional. Contas com transações, faturas ou importações não podem ser excluídas; arquivamento ou reversão auditável ficam fora desta refatoração. Faturas continuam materializadas como registros persistidos com snapshots, totais e status recalculados pelo backend.

A superfície chamada pelo app deve ser exposta em um schema dedicado, como `api`, com tabelas e helpers internos fora dele. Catálogos globais simples podem ser expostos para `SELECT`; tabelas financeiras base não devem ser expostas diretamente e devem ser lidas por read models ou RPCs. Edge Functions chamadas pelo app exigem JWT de usuário; endpoints públicos são exceções explícitas. Edge Functions devem preferir operar no contexto do usuário/RLS e usar secret/service role apenas quando houver motivo claro e escopo limitado.

DTOs Swift de requests e responses serão manuais no MVP. Contratos de RPCs e Edge Functions devem nascer versionados como `v1`, mesmo durante desenvolvimento, para separar a superfície consumida pelo app de experimentos.

Quando o app não conseguir validar sessão ou buscar dados por falha de rede, deve mostrar uma tela global de indisponibilidade com ação de tentar novamente e sem navegação para áreas financeiras. Token inválido ou sessão expirada sem refresh possível volta para login; falha de rede ou timeout não faz logout automático.

A ação avançada de apagar banco local deixa de existir. A nova versão deve limpar arquivos antigos `grana_app.sqlite`, `-wal` e `-shm` no primeiro boot pós-refatoração para remover resíduos financeiros em disco. `Config.swift` deve manter apenas configuração Supabase necessária ao app online, removendo URLs e credenciais de PowerSync.

A refatoração só é concluída quando `PowerSync` sair do projeto Xcode, imports, testes e resolução de pacotes, e quando não houver referências funcionais a SQLite, `watch()` ou schema local. Arquivos com papel de repository podem continuar existindo com implementação remota, mas sem SQL local ou PowerSync. Seeds locais e `AppSchema` deixam de ser fonte de verdade; catálogos globais passam a ser migrations Supabase. Conversores de dinheiro podem permanecer para `Decimal` no Swift e centavos inteiros nos DTOs remotos, sem acoplamento a banco local.

O app principal não terá modo demo offline com dados financeiros falsos. Mocks podem existir apenas em testes ou ferramentas de desenvolvimento fora do fluxo real.

O login por magic link do Supabase permanece no escopo da refatoração. No primeiro acesso de um usuário, o backend deve criar um perfil/configuração mínima do produto, separado dos catálogos globais. Moeda deve ser persistida nos registros onde fizer parte do domínio financeiro, mas o MVP valida apenas BRL.

O catálogo global de instituições deve declarar as capacidades suportadas pelo produto, incluindo tipos de conta e formatos de importação disponíveis para cada instituição. A criação de contas continua separando `Conta corrente` e `Cartão de crédito`, com detalhes e validações próprias. Pagamento de fatura continua sendo uma transferência vinculada a uma ou mais faturas; estorno de cartão continua sendo uma transação vinculada à compra original, não uma receita.

`Lote de importação` continua sendo entidade persistida no backend para permitir desfazer importação e produzir relatórios. O payload estruturado enviado pelo app no commit de importação deve referenciar categorias por slug e entidades do usuário por IDs persistidos do backend, nunca por IDs locais ou temporários. Listas grandes, como transações e importações, devem ser paginadas no backend desde o início. Dashboard deve consumir agregações prontas por período e filtros explícitos de datas, sem buscar todo o histórico para somar no Swift.

O plano executável da refatoração vive em `docs/online-only-supabase-refactor-plan.md`, e `AGENTS.md` deve orientar novos agentes pela direção aceita nesta ADR. A migração deve começar pela criação da base Supabase e pela fatia de catálogos e contas. PowerSync pode coexistir temporariamente apenas para fatias ainda não migradas; não haverá feature flag para alternar local/remoto. Cada fatia deve terminar compilando, e a refatoração completa exige app sem PowerSync, sem persistência financeira local e com contas, transações, faturas, dashboard e importação usando o backend.

Os schemas serão `api` para a superfície consumida pelo app e `app_private` para tabelas base, helpers e lógica interna. Tabelas financeiras base ficam em `app_private`; o app acessa dados financeiros por views/RPCs em `api`. Catálogos globais também ficam em `app_private` e são expostos por views em `api`, para manter contrato estável mesmo quando a estrutura interna mudar.

O perfil mínimo do usuário deve ser criado por RPC idempotente `api.v1_ensure_profile()` chamada no primeiro boot autenticado. O perfil persiste o timezone padrão do usuário, e requests de dashboard/agregação podem enviar override de timezone quando necessário.

Listas grandes usam paginação por cursor. A ordenação canônica da lista de transações é `occurred_at desc, created_at desc, id desc` para garantir ordem total e cursor estável. Erros de RPCs e Edge Functions seguem o formato `{ code, message?, details? }`; apenas `code` é contrato estável para UI. Chaves de idempotência são UUIDs gerados pelo app e armazenados por usuário e operação no backend, com resposta reaproveitável para retries.

Testes backend, scripts SQL e verificações formais de backend não são requisito desta refatoração. A garantia automatizada fica na camada Swift remota, com clients fake para DTOs, mapeamento de erros e comportamento dos Stores; mudanças backend dependem de revisão de código/contrato e validação pelo fluxo do app.

Essa decisão aceita explicitamente maior risco de bugs em RLS, grants, RPCs financeiras, constraints e recálculo de faturas escaparem para uso manual. Como compensação, migrations que alterem RLS, grants, RPCs financeiras ou schema financeiro devem ser pequenas, revisáveis e passar por revisão humana cuidadosa. A superfície de dados financeiros deve permanecer conservadora: tabelas base fora do schema `api`, grants mínimos e read models/RPCs estreitos. Cada mudança backend deve ter plano de rollback manual descrito no trabalho correspondente. A decisão de não testar backend deve ser reavaliada antes de usuários reais.
