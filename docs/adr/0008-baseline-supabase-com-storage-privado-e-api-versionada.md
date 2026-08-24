# Baseline Supabase com storage privado e API versionada

Status: accepted

Como o projeto Supabase foi recriado do zero após a remoção do modelo offline-first, o novo baseline de migrations não preserva a cadeia histórica nem nomes internos legados. Objetos de produto não vivem no schema `public`: tabelas financeiras, catálogos base, perfil, idempotência e helpers ficam em `app_private`; o app consome apenas contratos versionados em `api.v1_*`.

Essa decisão troca compatibilidade in-place por um bootstrap limpo, mais auditável e alinhado ao app online-only. Dados financeiros são acessados por RPCs transacionais em `api`; categorização inteligente por IA fica fora do GranaApp e será tratada por um processo local separado.
