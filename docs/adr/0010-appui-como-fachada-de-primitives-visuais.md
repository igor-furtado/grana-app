# 0010 - AppUI como fachada de primitives visuais

- Status: aceito
- Data: 2026-08-28

## Contexto

Os controles de entrada e tabela do GranaApp cresceram de forma distribuida em
views e componentes sem uma entrada canonica unica. Havia mistura de
`TextField`, `Toggle`, `Picker`, `DatePicker`, um campo monetario dedicado e um
wrapper de tabela dedicado, o que espalhava o ponto de
mudanca para evolucoes visuais futuras.

Como a direcao imediata e centralizar antes de padronizar o design final de
cada controle, precisavamos de uma fachada unica que permitisse migracao ampla
sem exigir redesenho completo nesta mesma etapa.

## Decisao

Adotamos `AppUI` como fachada oficial para primitives visuais reutilizaveis do
app.

- `AppUI` existe como namespace em arquivo agregador.
- Os tipos concretos continuam em `GranaApp/Shared/Components/`.
- O consumo do app deve preferir `AppUI.*` em vez de `SwiftUI.*` direto para
  controles reutilizaveis.
- `AppUI.Table` e o nome canonico para tabelas.
- `AppUI.TextField`, `AppUI.Toggle`, `AppUI.DatePicker`,
  `AppUI.CurrencyField` e `AppUI.Selector` passam a ser a entrada oficial dos
  controles migrados nesta fase.
- `Section` e a composicao semantica maior dos formularios continuam nas views;
  os componentes `AppUI.*` concentram o shell visual e, quando couber,
  `label`, ajuda e erro local.

## Consequencias

Positivas:

- Existe um ponto unico de mudanca para evolucao visual dos controles.
- O app reduz drift entre telas antes mesmo da padronizacao completa de design.
- Migracoes futuras podem acontecer por primitive, sem refatorar o app inteiro
  outra vez.

Negativas:

- A primeira fase introduz wrappers ainda proximos dos controles nativos, antes
  de um contrato visual final estabilizado.

Neutras:

- Nem todo agrupamento de formulario vira componente agora; a estrutura maior
  continua responsabilidade da tela.
