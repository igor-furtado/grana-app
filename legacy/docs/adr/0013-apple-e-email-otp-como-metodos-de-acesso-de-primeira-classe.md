# 0013 - Apple e Email OTP como métodos de acesso de primeira classe

O GranaApp trata `Sign in with Apple` e `Email OTP` como métodos de acesso de primeira classe. O Apple usa o sheet nativo do sistema para seleção de identidade, ambos os métodos podem criar conta nova e recuperar acesso com fallback cruzado, `auth.users.id` permanece como identidade canônica no Supabase, e a vinculação entre métodos nunca é automática: o app sempre pede confirmação explícita do usuário antes de associar um novo método de acesso a uma conta existente.
