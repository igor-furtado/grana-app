# Interface web-first com shadcn/ui

O novo cliente do GranaApp será construído do zero para navegadores com React, TypeScript, Vite, Redux Toolkit, Tailwind CSS e shadcn/ui sobre Radix. React Router será introduzido quando existirem múltiplas telas e navegação. A primeira fase implementará somente a camada de apresentação, com modelos orientados à tela e dados fake mantidos em memória e restaurados a cada recarga; backend, autenticação e domínio definitivo ficam fora desse escopo.

Do cliente macOS serão preservados como referência apenas o layout das telas, entendido como a posição relativa dos elementos, e os fluxos de navegação. O design system existente — incluindo tokens, paleta, tipografia, componentes e estética — não será portado; o shadcn/ui será a nova base visual para priorizar velocidade de desenvolvimento. Os protótipos HTML existentes permanecem inalterados.
