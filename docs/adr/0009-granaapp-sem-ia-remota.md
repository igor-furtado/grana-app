# GranaApp sem IA remota

Status: accepted

## Contexto

O uso de APIs públicas de IA para categorizar transações criou dois problemas
de produto: custo operacional e exposição de dados financeiros a provedores
externos. O requisito atual é que inteligência de categorização rode localmente
no macOS em um projeto/processo separado do app principal.

## Decisão

O GranaApp não chama provedores externos de IA, não chama Edge Functions de
categorização e não mantém runtime config de provider/modelo.

No estado atual, o contrato de classificação dentro do GranaApp é mínimo:
transações importadas recebem fallback local em **Não Classificado** e seguem
para revisão manual antes do commit. O backend recebe apenas as transações
revisadas/categorizadas pelo app e continua sendo a fonte de verdade.

O projeto local de inteligência será tratado separadamente. Ele poderá evoluir
de contrato simples para regras determinísticas, memória global, classificador
clássico e LLM local, mas essa evolução não pertence ao GranaApp enquanto o
novo projeto não existir.

## Consequências

- O GranaApp fica livre de custos e dependências de IA remota.
- O backend não precisa conhecer provider, modelo, prompt, cache de IA ou
  correções de categorização.
- A importação continua possível com revisão manual.
- A fronteira futura com o processo local deve ser desenhada como contrato
  explícito, sem acoplar o app principal à implementação interna da
  inteligência.
