# ROADMAP.md — Fases de desenvolvimento

## Direção ativa da refatoração

O roadmap registra fases e contexto histórico do produto. A direção ativa da
refatoração de dados é a decisão aceita em
`docs/adr/0007-app-online-only-com-supabase-como-fonte-da-verdade.md`,
executada pelo plano em `docs/online-only-supabase-refactor-plan.md`.

Este arquivo não substitui a ADR nem o plano operacional. Referências antigas
ao modelo local-first/PowerSync nas fases já concluídas devem ser lidas como
contexto histórico do MVP, não como estado futuro desejado.

## Fase 0 — Fundação (setup do projeto) ✅

## Fase 1 — Schema local do MVP e CRUD de transações (manual) ✅

## Fase 2 — Dashboard básico ✅

## Fase 3 — Importação de planilhas (XLSX e CSV) e extratos OFX ✅

## Fase 4 — Integração Claude API: categorização automática ✅

## Fase 4.5 — Cartões de Crédito ✅

## Fase 4.6 — Refator estrutural de `Account` ✅

## Fase 4.7 — Faturas (Statements) de cartão ✅

## Fase 5 — Refatoração online-only com Supabase (direção ativa)

**Objetivo:** migrar o app para modo online-only estrito, com Supabase Postgres
como fonte única de verdade para dados financeiros.

**Referências canônicas:**
- ADR: `docs/adr/0007-app-online-only-com-supabase-como-fonte-da-verdade.md`
- Plano operacional: `docs/online-only-supabase-refactor-plan.md`

**Escopo executivo desta fase:**
- Migrar contas, transações, faturas, dashboard e importação para contratos
  remotos no backend.
- Remover PowerSync, `watch()`, schema local, seeds financeiras locais e
  persistência financeira em disco.
- Manter apenas sessão/token de autenticação local; dados financeiros ficam
  só no backend e em memória durante sessão válida.

**Critérios finais de aceite da refatoração:**
- O app compila sem PowerSync.
- Não há persistência local de dados financeiros.
- Supabase é a fonte única de verdade.
- Contas, transações, faturas, dashboard e importação usam o backend.

---

## Fase 6 — Investimentos: Holdings e Quotes

**Objetivo:** registrar carteira de investimentos e ver patrimônio.

**Entregáveis:**
- Tabelas e models: `assets`, `holdings`, `quotes`
- Cadastro manual de operações de compra/venda
- Cálculo de preço médio
- Integração BRAPI: buscar cotações sob demanda (URLSession)
- Card "Patrimônio investido" no dashboard
- Gráfico de evolução do patrimônio (Swift Charts line)
- Tela "Carteira" listando holdings com valor atual e variação

**Sem isto, não avança:** ver patrimônio total atualizado e variação do dia.

---

## Fase 7 — Claude Chat sobre suas finanças

**Objetivo:** conversar com IA sobre seus dados financeiros.

**Entregáveis:**
- Tela de chat (Mac)
- Tool use: IA tem ferramentas pra consultar o banco (`getTransactions`, `getCategoryTotal`, `getHoldings`)
- Sistema de prompt com contexto do usuário (período corrente, taxonomia, padrões)
- Histórico de conversas salvo no backend online-only
- Streaming de resposta
- Citação de transações específicas nas respostas (clicáveis)

**Sem isto, não avança:** perguntar "quanto gastei com restaurante esse mês comparado ao anterior?" e receber resposta correta com transações citadas.

---

## Fase 8+ — Features avançadas (a decidir conforme uso)

Possibilidades, sem ordem definida:
- Atalhos Siri pra adicionar gasto por voz
- Open Finance (quando viável tecnicamente)
- **Menu "Patrimônio"** — tela dedicada agregando net worth (saldos + investimentos da Fase 6 + ativos manuais tipo imóvel/veículo). Conteúdo: gráfico de linha de evolução do patrimônio líquido (rolling 12 meses / YTD / desde início), composição por classe, variação mês a mês.
- **Metas e orçamentos** — orçamento por categoria com gráfico de barra de progresso "gastei X de Y", alerta quando >80%, suporte a metas de poupança (ex: "guardar R$ 10k pra viagem até dez/2026").
- Relatórios fiscais (informe de rendimentos, ganho de capital)
- Notificações push (gasto incomum, vencimento)
- Backup/export pra planilha
- Multi-moeda
- Modo "preview de futuro" (projeções)

---

## Gráficos diferenciadores mapeados (a decidir)

Catálogo de visualizações vistas em apps concorrentes (Mint, YNAB, Monarch, Copilot, Empower) que ficaram **fora do MVP do dashboard**. Decidir caso a caso se valem implementar — ordem é por relação esforço/impacto, do mais barato pro mais caro.

- **Sparklines embutidas nos 4 cards** — mini-gráficos de 30/90 dias dentro de cada card. Reaproveita queries existentes, alto ganho visual, esforço baixo (LineMark sem eixos, frame pequeno). Estilo Copilot/Monarch.
- **Spending pace** — duas linhas no mesmo plano: ritmo de gasto ideal acumulado (pontilhada) vs. ritmo real (sólida). Resposta direta pra "estou no ritmo do mês?". Visual assinatura do Copilot Money.
- **Comparação YoY sobreposta** — duas linhas no mesmo eixo "mês do ano", uma do ano corrente outra do anterior. Empower e Copilot usam. Precisa de 13+ meses de histórico pra fazer sentido.
- **Burn-down do orçamento mensal** — linha do saldo restante do orçamento descendo até o fim do mês. Pareia bem com a feature "Metas e orçamentos" do Fase 8+.
- **Heatmap calendário (estilo GitHub contributions)** — grid dia × semana com cor = intensidade do gasto. Identifica padrão semanal (ex: "sextas custam o dobro"). Médio esforço em Swift Charts via `RectangleMark`.
- **Treemap de categorias** — retângulos aninhados, peso = total gasto. Útil quando taxonomia cresce (subcategorias com peso). Sem `TreemapMark` nativo — exige layout manual via `GeometryReader`.
- **Sankey de fluxo de caixa** — fluxo "fontes de renda → categorias de gasto + poupança". Feature "hero" do Monarch Money, gera marketing instagramável. Caro em Swift Charts (sem `SankeyMark`; precisa Canvas customizado), mas é o gráfico mais diferenciador do catálogo.

---

## Polimento HIG (pós-MVP)

Itens de conformidade com Apple Human Interface Guidelines mapeados durante o desenvolvimento mas não bloqueantes pro MVP single-user. Implementar conforme o app for ganhando tração e o atrito justificar o investimento.

- **Atalhos de teclado no menu bar** — hoje `⌘1..⌘9` funcionam globalmente via `.keyboardShortcut(_:)` nos `SidebarRow` Buttons (ver `ContentView.swift`), mas não aparecem no menu "View" porque `selection` é `@State` local da `ContentView`. Pra exibi-los em "View → Switch to Dashboard ⌘1" (padrão Apple), refatorar `selection` pra um `@Observable` compartilhado (ex: `NavigationCoordinator`) e adicionar `Commands { CommandMenu("View") { ... } }` em `GranaAiApp.swift`. Ganho: descobribilidade (Help → Search anuncia os atalhos), uniformidade com apps nativos. Custo: lift de estado + 1 enum scene com 9 botões.
- **Sidebar nativa via `List(selection:)`** — sidebar custom (ver `ContentView.sidebar`) usa `Button + onMoveCommand` em vez de `List` por causa do override visual de seleção (que vinha do `AccentColor` global). VoiceOver perde "row N of M" e drag-to-reorder gratuito. Vale revisitar quando o AccentColor virar pasta separada de "accent de seleção da sidebar" (`SidebarSelectionColor` no asset catalog) — aí dá pra voltar pro `List` nativo sem comprometer o look.
- **Atalhos extras** — `⌘N` (nova transação), `⌘F` (busca em transações), `⌘⇧I` (importar), `⌘,` (preferências/Avançado). Pareados com o item de menu bar acima.

---
