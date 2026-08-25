import CoreGraphics

/// Escala de spacing semantica para distancias entre elementos. Use estes
/// tokens em `spacing`, `padding`, `EdgeInsets` e gaps de grids.
///
/// **Como escolher**:
/// - `none` (0): ausencia intencional de espaco
/// - `xxs` (4): menor respiro positivo, ajustes densos
/// - `xs` (8): icone + texto, labels proximas e microgrupos
/// - `sm` (12): espaco compacto entre elementos de uma row
/// - `md` (16): padding e gaps padrao de cards e grids
/// - `lg` (20): separacao entre grupos de uma tela
/// - `xl` (24): padding top-level e secoes amplas
/// - `xxl` (32): separacao forte entre blocos majoritarios
/// - `xxxl` (40): respiro maximo de pagina ou estado vazio
///
/// **Quando nao usar**: tamanhos de elementos, larguras de colunas, alturas de
/// cards, bolinhas, barras ou icones. Esses valores pertencem a tokens de size
/// ou constantes especificas.
extension GranaTheme {
    enum Spacing {
        struct Token: Identifiable {
            let name: String
            let value: CGFloat
            let usage: String

            var id: String {
                name
            }

            var displayValue: String {
                "\(Int(value)) pt"
            }
        }

        private static let noneToken = Token(
            name: "none",
            value: 0,
            usage: "Ausencia intencional de espaco"
        )
        private static let xxsToken = Token(
            name: "xxs",
            value: 4,
            usage: "Menor respiro positivo, ajustes densos"
        )
        private static let xsToken = Token(
            name: "xs",
            value: 8,
            usage: "Icone + texto, labels proximas e microgrupos"
        )
        private static let smToken = Token(
            name: "sm",
            value: 12,
            usage: "Espaco compacto entre elementos de uma row"
        )
        private static let mdToken = Token(
            name: "md",
            value: 16,
            usage: "Padding e gaps padrao de cards e grids"
        )
        private static let lgToken = Token(
            name: "lg",
            value: 20,
            usage: "Separacao entre grupos de uma tela"
        )
        private static let xlToken = Token(
            name: "xl",
            value: 24,
            usage: "Padding top-level e secoes amplas"
        )
        private static let xxlToken = Token(
            name: "xxl",
            value: 32,
            usage: "Separacao forte entre blocos majoritarios"
        )
        private static let xxxlToken = Token(
            name: "xxxl",
            value: 40,
            usage: "Respiro maximo de pagina ou estado vazio"
        )

        static let none = noneToken.value
        static let xxs = xxsToken.value
        static let xs = xsToken.value
        static let sm = smToken.value
        static let md = mdToken.value
        static let lg = lgToken.value
        static let xl = xlToken.value
        static let xxl = xxlToken.value
        static let xxxl = xxxlToken.value

        static let tokens = [
            noneToken,
            xxsToken,
            xsToken,
            smToken,
            mdToken,
            lgToken,
            xlToken,
            xxlToken,
            xxxlToken,
        ]
    }
}
