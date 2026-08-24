# Contexto para criar o GranaAI

Este documento preserva o contexto de produto e arquitetura para iniciar o novo
projeto **GranaAI** sem depender do histórico da conversa.

## Prompt sugerido

Use este prompt ao iniciar a construção do novo repositório `grana-ai`:

```text
Voce esta criando o projeto GranaAI.

Contexto:
- GranaApp e o app principal de financas pessoais para macOS.
- GranaApp foi separado de qualquer IA remota: nao chama OpenAI, nao chama
  Edge Functions de categorizacao e nao mantem configuracao de provider/modelo.
- Supabase continua sendo a fonte de verdade do produto e recebe apenas
  transacoes revisadas/categorizadas pelo app.
- A privacidade que estamos protegendo e contra provedores externos de IA.
- GranaAI e um novo projeto separado, dono de tudo relacionado a inteligencia
  de classificacao.

Objetivo do primeiro marco:
- Criar um projeto Swift simples para macOS.
- Ter um nucleo reutilizavel de classificacao.
- Ter um executavel fino que exponha um contrato local via processo.
- A comunicacao inicial deve ser JSON por stdin/stdout.
- O primeiro marco deve provar integracao e contrato, nao qualidade de IA.
- O classificador inicial pode retornar fallback/unknown para todas as
  transacoes, desde que valide request, response, erros e taxonomia.

Decisoes obrigatorias:
- GranaAI nao chama APIs publicas de IA.
- GranaAI nao acessa Supabase no primeiro marco.
- GranaAI nao possui taxonomia propria.
- Toda taxonomia vem do GranaApp em cada request.
- Toda resposta deve referenciar apenas categorias/subcategorias existentes na
  taxonomia recebida.
- Falha do GranaAI nao pode bloquear importacao no GranaApp.
- O contrato deve ser versionado desde o inicio.
- Erros devem ter codigos estaveis.
- Logs nao devem registrar payload financeiro cru, valores, descricoes completas
  ou credenciais.

Roadmap interno:
1. apenas contratos para provar integracao
2. regras deterministicas
3. memoria global
4. classificador classico local
5. LLM local

Fora de escopo agora:
- Escolher runtime/modelo de LLM local.
- Implementar llama.cpp, Core ML, MLX, Ollama ou Apple Intelligence.
- Treinar classificador.
- Implementar memoria global.
- Empacotamento final com installer.
- XPC Service definitivo.
- LaunchAgent sempre ativo.

Preferencia arquitetural:
- Comecar com Swift Package ou projeto Swift simples contendo uma biblioteca
  core e um executavel CLI.
- O CLI e apenas transporte/process I/O.
- A logica de classificacao deve ficar em tipos reutilizaveis para permitir uma
  futura migracao para XPC Service sem reescrever o nucleo.
```

## Integracao futura com GranaApp

O GranaApp ainda sera integrado ao GranaAI. No estado atual, o GranaApp usa
fallback local em **Nao Classificado** durante a importacao e exige revisao
manual antes do commit final.

A integracao futura deve substituir esse fallback local por uma chamada a um
processo local do GranaAI, mantendo estas fronteiras:

- GranaApp conhece apenas o contrato de classificacao.
- GranaApp envia drafts de transacoes e a taxonomia atual.
- GranaAI devolve sugestoes validas dentro da taxonomia recebida.
- GranaApp continua responsavel pela UI, revisao, Supabase e commit final.
- Supabase continua sendo a fonte de verdade dos dados financeiros.
- GranaAI nao escreve no backend e nao decide categorias fora da taxonomia do
  app.
- Se GranaAI falhar, demorar ou retornar resposta invalida, GranaApp continua o
  fluxo com **Nao Classificado** e revisao manual.

O transporte inicial esperado e processo local com JSON por stdin/stdout. XPC
Service e uma evolucao provavel depois que o contrato estiver provado. LaunchAgent
nao e o formato desejado neste momento porque o produto nao precisa de um
servico independente rodando sem o GranaApp.
