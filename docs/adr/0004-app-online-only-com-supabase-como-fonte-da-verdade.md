# App online-only com Supabase como fonte da verdade

O GranaApp opera em modo online-only estrito. Sem sessão remota válida ou sem
conseguir validar a disponibilidade do backend, o app não exibe nem edita dados
financeiros. Supabase Auth pode manter sessão/token local; dados financeiros só
ficam no Supabase ou em memória durante uma sessão válida.

O Supabase Postgres é a fonte única de verdade para contas, transações, faturas,
categorias, instituições, lotes de importação, perfil e idempotência. O app usa
`supabase-swift` contra o schema `api`, com DTOs Swift manuais e contratos
versionados `v1`.

O fluxo de app permanece `SwiftUI View -> @Observable Store -> Repository ->
Supabase backend`. Views não chamam Supabase diretamente; stores coordenam
estado e repositories concentram Data API, RPCs, DTOs e mapeamento de erros.

Parsing e preview de OFX/CSV ficam no GranaApp. Cada `STMTRS` OFX gera um
`ImportBatch`; múltiplos extratos são enviados como payload estruturado para
commit atômico no backend.

Cada linha real importada pode gerar no máximo uma transação persistida. Quando
a linha representa uma parcela, o app e o backend preservam os metadados de
parcelamento e podem derivar a competência daquela parcela a partir da data de
origem, mas não criam transações para parcelas ausentes do arquivo.

O payload de importação é tratado como não confiável. O backend revalida conta,
categoria, instituição, duplicidade, fatura e estorno antes de persistir.
Deduplicação é garantia canônica do backend por função e constraint única; o
commit pula duplicatas e retorna relatório.
