# 0011 - Features sem previews locais

Features, telas e componentes do app principal não usam `#Preview`, porque
dependem de domínio, navegação, clients e estado remoto demais para previews
isolados serem uma fonte confiável de validação. A inspeção desses fluxos
acontece com o `GranaApp` em execução.
