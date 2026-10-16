# ROADMAP.md — Fases de desenvolvimento

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

## Fase 7 — Chat local sobre suas finanças

**Objetivo:** conversar com IA sobre seus dados financeiros.

Essa fase pertence à fronteira GranaApp + projeto/processo local de inteligência
descrita em `docs/adr/0006-granaapp-sem-ia-remota.md`. O GranaApp não deve
chamar provedor externo de IA.

**Entregáveis:**
- Tela de chat (Mac)
- Tool use: IA local tem ferramentas autorizadas pra consultar o banco (`getTransactions`, `getCategoryTotal`, `getHoldings`)
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

- **Atalhos de teclado no menu bar** — hoje `⌘1..⌘9` funcionam globalmente via `.keyboardShortcut(_:)` nos `SidebarRow` Buttons (ver `ContentView.swift`), mas não aparecem no menu "View" porque `selection` é `@State` local da `ContentView`. Pra exibi-los em "View → Switch to Dashboard ⌘1" (padrão Apple), refatorar `selection` pra um `@Observable` compartilhado (ex: `NavigationCoordinator`) e adicionar `Commands { CommandMenu("View") { ... } }` em `GranaAppApp.swift`. Ganho: descobribilidade (Help → Search anuncia os atalhos), uniformidade com apps nativos. Custo: lift de estado + 1 enum scene com 9 botões.
- **Sidebar nativa via `List(selection:)`** — sidebar custom (ver `ContentView.sidebar`) usa `Button + onMoveCommand` em vez de `List` por causa do override visual de seleção (que vinha do `AccentColor` global). VoiceOver perde "row N of M" e drag-to-reorder gratuito. Vale revisitar quando o AccentColor virar pasta separada de "accent de seleção da sidebar" (`SidebarSelectionColor` no asset catalog) — aí dá pra voltar pro `List` nativo sem comprometer o look.
- **Atalhos extras** — `⌘N` (nova transação), `⌘F` (busca em transações), `⌘⇧I` (importar), `⌘,` (preferências/Avançado). Pareados com o item de menu bar acima.

---
