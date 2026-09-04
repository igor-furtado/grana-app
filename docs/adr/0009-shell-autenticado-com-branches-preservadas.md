# Shell autenticado com branches preservadas por seção

O shell autenticado mantém uma branch de navegação por seção, montando cada uma sob demanda e preservando seu `NavigationPath`, `@State` de tela e snapshots já carregados em memória ao trocar de item no rail. Aceitamos o custo moderado de memória porque a UX esperada é a de navegação com estado por seção, e exceções de telas realmente pesadas devem ser tratadas localmente em vez de desmontar o app inteiro a cada troca de seção.
