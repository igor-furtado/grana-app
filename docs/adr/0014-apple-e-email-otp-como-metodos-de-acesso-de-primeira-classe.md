# Apple e Email OTP como métodos de acesso de primeira classe

Status: accepted

Em 31 de agosto de 2026, decidimos substituir o foco anterior em magic link por dois métodos de acesso de primeira classe no GranaApp: `Sign in with Apple` e `Email OTP`. O Apple usa o sheet nativo do sistema para seleção de identidade, ambos os métodos podem criar conta nova e recuperar acesso com fallback cruzado, `auth.users.id` permanece como identidade canônica no Supabase, e a vinculação entre métodos nunca é automática: o app sempre pede confirmação explícita do usuário antes de associar um novo método de acesso a uma conta existente.
