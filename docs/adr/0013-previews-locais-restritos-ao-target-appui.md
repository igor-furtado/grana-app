# 0013 - Previews locais restritos ao target AppUI

- Status: aceito
- Data: 2026-08-31

## Contexto

O target `AppUI` agora isola primitives visuais e sua base de tema sem tipos de
dominio. Esse modulo compila sozinho e serve como fronteira arquitetural leve
para inspecao visual isolada.

## Decisao

`#Preview` e permitido apenas dentro do target `AppUI`.

Fora de `AppUI`, a politica continua a mesma: features, telas e componentes do
app sao validados com o `GranaApp` em execucao.

## Consequencias

Positivas:

- A fronteira do modulo fica testavel visualmente sem puxar o app inteiro.
- O repositorio evita espalhar previews por codigo de feature e fluxo.

Negativas:

- A regra deixa de ser global e passa a depender do target do arquivo.
