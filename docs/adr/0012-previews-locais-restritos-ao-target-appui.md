# 0012 - Previews locais restritos ao target AppUI

O target `AppUI` agora isola primitives visuais e sua base de tema sem tipos de
dominio. Esse modulo compila sozinho e serve como fronteira arquitetural leve
para inspecao visual isolada.

`#Preview` e permitido apenas dentro do target `AppUI`.

Fora de `AppUI`, a politica continua a mesma: features, telas e componentes do
app sao validados com o `GranaApp` em execucao.
