// COMO USAR:
// 1. Copie este arquivo para `Config.swift` (mesma pasta).
// 2. `Config.swift` está no `.gitignore` — nada do que está aqui vaza pro git.
// 3. Preencha os placeholders do Supabase:
//      - Em `supabaseAnonKey`, copie a publishable key do projeto atual
//        (`sb_publishable_...`) em Settings > API Keys.
//
// Por que `Config.example.swift` versus `.env`:
// Sem dependência extra, type-safe, e o compilador avisa se você usar uma
// chave que não existe.
//
// O bloco abaixo fica em `#if false` pra que Xcode (synchronized folders)
// não compile este arquivo junto com `Config.swift`. Copie o conteúdo
// removendo as guardas.

#if false
    import Foundation

    enum Config {
        static let supabaseURL = "https://YOUR_PROJECT.supabase.co"
        static let supabaseAnonKey = "YOUR_PUBLISHABLE_KEY"
    }
#endif
