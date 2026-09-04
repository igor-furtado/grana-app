# 0012 - Fluxos modais principais com modal de workspace proporcional

Adotamos `modal de workspace` como padrao arquitetural para os fluxos modais
principais do app. Eles usam apresentacao inline sobre a janela atual,
dimensoes proporcionais ao viewport, foco modal e fechamento por acoes
explicitas; `sheet` fica restrito a confirmacoes curtas, pickers e utilitarios
pequenos.
