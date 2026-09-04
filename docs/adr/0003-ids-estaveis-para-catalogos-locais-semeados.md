# Catálogos globais resolvidos por slug e código

Categorias e instituições padrão são catálogos globais do produto no Supabase,
versionados por migrations e expostos ao app por contratos `api.v1_*`. O
GranaApp não depende de UUIDs conhecidos para esses catálogos; sempre que
precisa resolver uma categoria ou instituição por contrato de produto, usa
`slug` de categoria ou `code` de instituição.
