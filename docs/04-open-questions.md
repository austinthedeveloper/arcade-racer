# Open Questions

Decisions that change the direction of the docs or the art. Defaults in **bold** are what the docs assume until decided.

| # | Question | Default assumed | Affects |
|---|---|---|---|
| 1 | Art style: high-color pixel art, hi-res pre-rendered CG sprites, or painted/illustrated? | **Pixel art at 640x360** | Resolution, sprite sizes, production pipeline, every prompt |
| 2 | Renderer: classic pseudo-3D segment renderer, or a 3D scene with flat sprite billboards? | **Classic pseudo-3D** | Whole rendering and physics approach |
| 3 | Which wheel and pedals do you own (brand/model)? | Unknown | First wheel profile, testing |
| 4 | Target platforms: macOS only, or also Windows / Linux / Steam Deck? | **macOS + Windows** | Wheel testing, force feedback work |
| 5 | Setting: fictional country coast-to-coast, or a world tour of fictional places? | **Fictional country** | Stage list, map screen |
| 6 | Working title | **SUNDOWN RUN** (placeholder) | Logo prompts |
| 7 | Car production: pre-render from simple 3D models then clean up, or hand-draw every frame? | **Pre-render + cleanup** | Car pipeline, tools |
| 8 | Is force feedback a must-have for 1.0 or a nice-to-have? | **Nice-to-have (post-MVP)** | Need for a GDExtension |
| 9 | Split-screen 2-player: wanted? | **Stretch goal** | Renderer architecture (two viewports) |
| 10 | Which image generator are you using? | Unknown | Prompt syntax (negative prompts, aspect flags) |
