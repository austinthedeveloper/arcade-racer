# Content templates

Templates for adding a car, an element (roadside prop, traffic vehicle, road-spanning piece,
power-up art) or a whole stage without rework. Each has two halves: an image-generation
template for the art and a Claude prompt that wires the art into the game.

| Adding | 1. Art template | 2. Claude prompt |
|---|---|---|
| Player car | `assets/prompts/templates/car.md` | `docs/templates/new-car.md` |
| Roadside props, traffic, spans, power-ups | `assets/prompts/templates/element.md` | `docs/templates/new-element.md` |
| Stage | `assets/prompts/templates/stage.md` | `docs/templates/new-stage.md` |

## Flow

1. **Fill the art template.** Replace the `{{placeholders}}`; leave the fixed STYLE-A and
   negative blocks alone (they match `assets/prompts/00-style-guide.md`).
2. **Generate.** Hero or composite first; give approved art to the generator as the
   reference image for the rest. Check each result against the template's layout rules
   (frame count and order, magenta background, gaps, camera angle): the slicing tools exit
   on a wrong count rather than guess.
3. **Drop the files in** `assets/concept/<cars|roadside|traffic|backgrounds|powerups>/` under
   the exact names the template gives (`_A_v1`, `_A_v2` for a reroll).
4. **Paste the Claude prompt** into Claude Code with the brackets filled (ids, names,
   stats, object lists). It edits the tool specs and game code, runs the sprite tools,
   extends the tests, handles the golden traces and screenshots, and commits on a
   `feature/CLD-...` branch for Austin to merge.

Keep a filled copy of each art prompt next to the others in `assets/prompts/` so rerolls
start from what was generated.

## What changes the golden traces

| Change | Traces |
|---|---|
| New car | All change (its rival driver joins the pool). Regenerate, say why. |
| Roadside props, span art, power-up art | Unchanged; a change means a car hits something new. |
| Traffic in a list or a stage's specials | Change for the stages whose traffic changes. |
| New stage | One new trace; existing ones unchanged. |
