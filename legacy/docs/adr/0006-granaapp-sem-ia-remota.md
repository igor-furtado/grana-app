# GranaApp sem IA remota

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
