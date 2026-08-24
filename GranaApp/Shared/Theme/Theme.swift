import SwiftUI

/// Aliases semânticos pra estados de UI (sucesso, erro, warning).
///
/// **Tokens base do design system:** `GranaTheme` concentra a paleta visual,
/// surfaces e estilos compartilhados. O asset catalog ainda fornece
/// `Color.accentColor`, `Color.surface`, `Color.income`, `Color.expense` e
/// `Color.transfer` para pontos que precisam desses recursos gerados pelo
/// Xcode.
///
/// Pra neutros (ícones, strokes, fills sutis, background da sidebar), use os
/// tokens do `GranaTheme` para manter o app em tema claro e preservar contraste.
///
/// **Como adicionar uma cor visual:** prefira `GranaTheme`. Crie
/// `<Nome>.colorset/Contents.json` em `Resources/Assets.xcassets/` apenas
/// quando a cor precisar de acessor gerado pelo Xcode.
///
/// **Estados de UI vs cores de domínio.** Os aliases abaixo (`success`,
/// `danger`, `warning`) apontam para a paleta semântica do `GranaTheme`.
/// Ficam desacopladas das cores de **domínio**
/// (`income`/`expense`/`transfer`) que carregam significado financeiro
/// específico e podem ter tons custom de marca.
///
/// Constrained a `ShapeStyle where Self == Color` pra funcionarem com a
/// sintaxe abreviada `.foregroundStyle(.danger)` em qualquer API que aceite
/// `ShapeStyle`.
extension ShapeStyle where Self == Color {
    /// Sucesso/confirmação.
    static var success: Color {
        GranaTheme.Palette.green
    }

    /// Erro/destrutivo.
    static var danger: Color {
        GranaTheme.Palette.red
    }

    /// Atenção não-crítica. Usado pra estados de revisão, valores suspeitos e
    /// duplicatas detectadas.
    static var warning: Color {
        GranaTheme.Palette.amber
    }
}
