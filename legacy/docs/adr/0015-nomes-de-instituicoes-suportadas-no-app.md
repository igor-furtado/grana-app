# Nomes de instituições suportadas no app

Instituições financeiras suportadas formam um catálogo fechado no MVP. O
Supabase mantém a identidade e as capacidades da instituição, como `id`, `code`
e `kind`, enquanto o GranaApp decide o nome exibido a partir de
`InstitutionKind.displayName`; isso evita duplicar texto de apresentação entre
backend e frontend e torna mudanças de nome uma decisão de release do app.
