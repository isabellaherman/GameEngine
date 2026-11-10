# GameEngine · Bend

Primeiro protótipo de uma engine 3D em Bend 2.0.40: ray tracing de uma esfera
analítica, num editor de cena nativo (viewport de 512 × 512). A câmera começa pausada.
O movimento de órbita só é ativado ao apertar Espaço.

## Executar

```sh
make run          # compilar e abrir; usa Metal no Mac
make cpu          # mesma cena na CPU, para comparação
make check        # verificar os arquivos Bend
make test         # testes geométricos e amostras da imagem em GPU e CPU
```

Também funciona com `bend main.bend -o build/esfera` depois de `mkdir -p build`.
Mantenha `build/esfera.gpu` ao lado de `build/esfera`: ele contém o programa Metal.

No VS Code: **Terminal → Run Task** oferece as mesmas ações. **Cmd+Shift+B** compila.
Pré-requisitos no Mac: Bend no PATH, Xcode/Clang 19+ e o compilador Metal.

## Controles

- **Botão PLAY/PAUSE** ou **Espaço:** retomar ou pausar a órbita.
- **Botão RESET** ou **R:** voltar ao ângulo inicial.
- **Esc** ou fechar a janela: sair.

## Arquivos

| Arquivo | Responsabilidade |
| --- | --- |
| `main.bend` | Estado, eventos, tempo e janela |
| `engine/vec3.bend` | Operações com vetores 3D |
| `engine/camera.bend` | Câmera em perspectiva e raios por pixel |
| `engine/sphere.bend` | Interseção analítica raio–esfera |
| `engine/renderer.bend` | Materiais, luz, sombras e piso: a cor de cada pixel da viewport |
| `engine/editor.bend` | Editor de cena: junta viewport e UI numa imagem paralela (GPU) |
| `engine/ui.bend` | Adaptador mínimo do Bend-UI: toolbar, outline, inspector e botões |
| `engine/font.bend` | Fonte bitmap 5×7 (A–Z, 0–9, `.`, `-`) e os rótulos do editor |
| `test.bend` | Casos geométricos e comparação de pixels com a referência |

## Renderização

Cada pixel lança um raio da câmera. Uma equação quadrática encontra a superfície
da esfera, sem malha poligonal. A iluminação combina luz ambiente, difusa,
brilho especular e luz nas bordas; o piso recebe sombra da esfera e névoa.
A cor é convertida para RGB com uma correção gamma aproximada.

`renderer.frame` chama `tiles!` para executar na GPU. A imagem se divide em
16.384 tarefas de 4 × 4 pixels, formando uma `Image` de `Pix` e `Qua`.
`App.run` apresenta cada quadro e processa os eventos. O movimento usa o tempo
entre quadros, limitado a 100 ms para evitar saltos após uma pausa do processo.

É um protótipo: cena de uma esfera de raio 1 na origem e um plano fixo em y=-1,05,
câmera a 4,2 unidades no eixo horizontal, resolução fixa e um raio por pixel.
A composição pressupõe a esfera acima desse plano. Ainda não há antialiasing,
carregamento de modelos, editor de cenas ou física. Os testes verificam casos
concretos; não constituem uma prova formal de correção da renderização.

## Editor de cena (Bend-UI, experimental)

Janela de 1024 × 552:
- **Toolbar:** PLAY/PAUSE e RESET.
- **SCENE (esquerda):** os objetos que a cena realmente tem. São Camera, Light, Sphere e Floor; um clique seleciona o objeto.
- **Viewport 3D:** 512 × 512, no centro.
- **INSPECTOR (direita):** mostra os valores do objeto selecionado. Eles são lidos das próprias definições da engine (`C.distance`, `C.height`, `R.light`, `S.unit`, `R.floor_y`). O ângulo da câmera é atualizado ao vivo. Por enquanto é só leitura.

`engine/ui.bend` importa `../Bend-UI/TOKENS.bend` e usa os tokens do tema escuro:
cores, `control_md`, `side_width`, `side_padding`, `btn_padding_x`, `btn_radius`,
`border_width`, espaçamentos e `btn_hover_brightness`. Os estilos seguem
`.toolbar`, `.side`, `.side__label`, `.btn--primary`, `.btn` e `.btn--ghost` do `ui.css`. As
cores `#rrggbb` são convertidas uma vez na CPU (`U.palette()`). A UI e a cena
são calculadas pixel a pixel no mesmo kernel da GPU. O texto usa a fonte bitmap
5×7 em 2×. Ainda não há edição de valores, focus ring, Tab, ícones ou animações.
O Bend-UI precisa estar em `../Bend-UI`.

Referências: [guia do Bend](https://github.com/bendlang/bend/blob/main/guide/GUIDE.md)
e `bend guide shaders`.
