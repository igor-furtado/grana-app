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

O GranaApp pode executar um processo local dedicado de inteligência via
contrato explícito em `stdin/stdout`. Esse processo continua fora do app
principal e fora do backend.

O contrato local possui dois fluxos distintos:

- classificação pré-commit: o app envia o lote inteiro de transações
  importadas para classificação inicial antes da revisão manual;
- aprendizado pós-revisão: ao confirmar o lote, o app envia ao processo local
  as classificações finais válidas confirmadas pelo usuário.

O GranaApp não mantém memória local de revisões confirmadas e o backend também
não a persiste. A memória de classificação pertence exclusivamente ao projeto
local de inteligência, que decide como normalizar, armazenar e sobrescrever
essas confirmações.

O backend continua sendo a fonte de verdade do histórico financeiro já
importado, mas não conhece provider, modelo, prompt, cache de IA nem memória
de classificação.

## Consequências

- O GranaApp fica livre de custos e dependências de IA remota.
- O backend não precisa conhecer provider, modelo, prompt, cache de IA,
  correções de categorização nem memória de classificação.
- A revisão manual continua obrigatória antes do commit final.
- O contrato com o processo local precisa validar a taxonomia atual enviada
  pelo app tanto para classificar quanto para aprender.
- Falha no aprendizado local impede a conclusão do commit final da importação.
- A fronteira com o processo local permanece explícita, sem acoplar o app
  principal à implementação interna da inteligência.
