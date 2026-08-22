import Foundation

/// Referência local do catálogo global de categorias mantido no Supabase.
///
/// Este arquivo não é fonte de verdade em runtime e não cria categorias. A
/// migration do backend define o catálogo canônico; esta cópia existe para
/// testes de consistência de ícones e contratos de slug usados pela UI.
/// Cada categoria raiz tem N subcategorias.
///
/// Subcategoria sempre herda o `CategoryKind` da raiz — não há mistura de
/// kinds dentro de uma mesma árvore.
///
/// **`slug` é id estável da raiz.** Resolve duas coisas: (1) lookup do ícone
/// via `CategoryIcon.forSlug(_:)` sem depender de IDs do backend,
/// (2) anchor estável pra IA na Fase 4 (few-shot prompting).
///
/// **Invariante:** ao adicionar uma raiz nova aqui, **DEVE** existir uma
/// entrada correspondente em `CategoryIcon+Slug.swift` mapeando o slug pro
/// ícone — caso contrário a UI renderiza sem ícone (silencioso). O teste
/// `CategoryCatalogReferenceConsistencyTests.everyCatalogRootHasIcon` quebra em
/// CI se o mapping ficar faltando.
struct CategoryCatalogReference {
    let slug: String
    let name: String
    let kind: CategoryKind
    let subcategories: [String]
}

// `nonisolated`: usado por testes e mappers sem depender do MainActor global.
nonisolated enum CategoryCatalogReferenceData {
    static let categories: [CategoryCatalogReference] = [
        // MARK: - Receitas

        CategoryCatalogReference(slug: "renda-e-pagamentos", name: "Renda e Pagamentos", kind: .income, subcategories: [
            "Salário",
            "Freelance",
            "13º Salário",
            "Férias",
            "PLR",
            "Juros de Investimentos",
            "Dividendos",
            "Restituição de IR",
            "Cashback",
            "Reembolso",
        ]),

        // MARK: - Despesas

        CategoryCatalogReference(slug: "compras", name: "Compras", kind: .expense, subcategories: [
            "Roupas e Calçados",
            "Acessórios e Joias",
            "Presentes",
            "Artigos Esportivos",
            "Hobbies e Coleções",
        ]),

        CategoryCatalogReference(slug: "cuidados-pessoais", name: "Cuidados Pessoais", kind: .expense, subcategories: [
            "Barbearia",
            "Massagem",
            "Cosméticos e Higiene",
        ]),

        CategoryCatalogReference(slug: "mobilidade", name: "Mobilidade", kind: .expense, subcategories: [
            "Uber e 99",
            "Táxi",
            "Transporte Público",
            "Pedágio",
        ]),

        CategoryCatalogReference(slug: "moto", name: "Moto", kind: .expense, subcategories: [
            "Combustível",
            "Manutenção e Mecânica",
            "Estacionamento",
            "Licenciamento",
            "Multas de Trânsito",
            "Seguro Moto",
            "Equipamentos e Acessórios",
        ]),

        CategoryCatalogReference(slug: "viagem", name: "Viagem", kind: .expense, subcategories: [
            "Passagens Aéreas",
            "Hospedagem",
            "Pacotes de Viagem",
            "Bagagem",
            "Seguro Viagem",
            "Passeios e Atrações",
            "Câmbio",
        ]),

        CategoryCatalogReference(
            slug: "entretenimento",
            name: "Entretenimento",
            kind: .expense,
            subcategories: [
                "Cinema",
                "Teatro",
                "Parques e Diversões",
                "Loterias",
            ]
        ),

        CategoryCatalogReference(
            slug: "festas",
            name: "Festas",
            kind: .expense,
            subcategories: [
                "Bares",
                "Baladas e Boates",
                "Festas e Eventos",
                "Shows e Festivais",
            ]
        ),

        CategoryCatalogReference(
            slug: "danca",
            name: "Dança",
            kind: .expense,
            subcategories: [
                "Escola de Dança",
                "Bailes",
                "Workshops",
                "Congressos",
            ]
        ),

        CategoryCatalogReference(slug: "trabalho", name: "Trabalho", kind: .expense, subcategories: [
            "Hardware",
            "Conferências e Eventos Tech",
        ]),

        CategoryCatalogReference(slug: "educacao", name: "Educação", kind: .expense, subcategories: [
            "Mensalidades",
            "Cursos",
            "Certificações",
            "Livros",
            "Material Escolar",
        ]),

        CategoryCatalogReference(
            slug: "alimentacao",
            name: "Alimentação",
            kind: .expense,
            subcategories: [
                "Supermercados",
                "Mercearias",
                "Açougues",
                "Padarias",
                "Restaurantes",
                "Lanchonetes",
                "Delivery de Comida",
                "Cafeterias",
                "Feira e Hortifrúti",
            ]
        ),

        CategoryCatalogReference(slug: "moradia", name: "Moradia", kind: .expense, subcategories: [
            "Aluguel",
            "Entrada e Encargos",
            "Condomínio",
            "Energia Elétrica",
            "Água",
            "Gás",
            "IPTU",
            "Financiamento Imobiliário",
            "Reforma",
            "Móveis",
            "Decoração",
            "Eletrônicos",
            "Utensílios Domésticos",
            "Ferramentas",
        ]),

        CategoryCatalogReference(slug: "streaming-e-apps", name: "Streaming e Apps", kind: .expense, subcategories: [
            "Streaming de Vídeo",
            "Streaming de Música",
            "IA e Produtividade",
            "Apps e Softwares",
            "Jogos",
        ]),

        CategoryCatalogReference(slug: "conectividade", name: "Conectividade", kind: .expense, subcategories: [
            "Internet Banda Larga",
            "Celular",
        ]),

        CategoryCatalogReference(slug: "exercicios", name: "Exercícios", kind: .expense, subcategories: [
            "Academia",
            "Personal Trainer",
            "Crossfit",
            "Pilates",
        ]),

        CategoryCatalogReference(
            slug: "servicos-profissionais",
            name: "Serviços Profissionais",
            kind: .expense,
            subcategories: [
                "Contabilidade",
                "Jurídico e Advocacia",
                "Consultoria",
                "Limpeza Doméstica",
            ]
        ),

        CategoryCatalogReference(slug: "saude", name: "Saúde", kind: .expense, subcategories: [
            "Plano de Saúde",
            "Consultas Médicas",
            "Consultas Dentárias",
            "Nutricionista",
            "Psicoterapia",
            "Fisioterapia",
            "Farmácias e Medicamentos",
            "Exames",
            "Vacinas",
            "Cirurgias",
            "Emergências Médicas",
            "Óculos e Lentes",
            "Aparelhos Ortodônticos",
            "Suplementos",
        ]),

        CategoryCatalogReference(
            slug: "investimentos",
            name: "Investimentos",
            kind: .expense,
            subcategories: [
                "Poupança",
                "CDB",
                "Tesouro Direto",
                "LCI/LCA",
                "Fundos de Investimento",
                "Ações Bolsa",
                "FIIs",
                "ETFs",
                "Previdência Privada",
                "Criptomoedas",
            ]
        ),

        CategoryCatalogReference(slug: "impostos", name: "Impostos", kind: .expense, subcategories: [
            "Imposto de Renda",
            "DAS",
            "INSS Autônomo",
            "ISS",
            "ITBI",
            "Taxas Cartoriais",
            "Taxas Bancárias",
            "IOF",
        ]),

        CategoryCatalogReference(slug: "saques", name: "Saques", kind: .expense, subcategories: [
            "Saque em Agência",
            "Taxa de Saque",
        ]),

        CategoryCatalogReference(slug: "nao-classificado", name: "Não Classificado", kind: .expense, subcategories: [
            "Pendente de Revisão",
        ]),

        // MARK: - Transferências

        CategoryCatalogReference(slug: "transferencias", name: "Transferências", kind: .transfer, subcategories: [
            "PIX Enviado",
            "PIX Recebido",
            "TED Enviada",
            "TED Recebida",
            "Transferência entre Contas",
            "Transferência Internacional",
            "Depósito em Conta",
        ]),
    ]
}
