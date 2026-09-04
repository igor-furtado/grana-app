# 0010 - AppUI como fachada de primitives visuais

Adotamos `AppUI` como fachada oficial para primitives visuais reutilizaveis do
app. O consumo do app deve preferir `AppUI.*` para controles reutilizaveis,
mantendo os tipos concretos em `GranaApp/Shared/Components/` e a composicao
semantica maior nas views.
