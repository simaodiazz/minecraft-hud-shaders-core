# Hud Resourcepack

A custom HUD rendering system built on Minecraft's vanilla text rendering
pipeline (`rendertype_text` core shaders). It hijacks the boss bar title as a
rendering surface: a glyph (mapped to a Private Use Area codepoint via a
resource pack font provider) is detected in the vertex shader by its vertex
color and repositioned to an arbitrary point on screen, instead of rendering
in place as normal text.

It's fully **responsive**: position is computed from the real framebuffer
size (`getScreenSize()`, derived from `ProjMat`) every frame, so it adapts to
window resizing and any GUI Scale automatically.

## What changed from the previous design

- Dropped the fixed `Element[]` array entirely (no more `size`, `margin`,
  `bar`, or a hardcoded list of elements compiled into the shader).
- Dropped the R/G/B base-4 index scheme. The vertex color no longer *selects*
  an element — it *is* the position, decoded live every frame.
- HUD detection moved to the **Alpha channel** (`HUD_ALPHA_MARKER`) instead
  of requiring R/G/B to fall in a narrow low range — the old scheme collided
  with plain black text (`#000000`).
- Added a fixed vertical baseline correction (`offset.y += screen.y * 0.5`)
  to cancel the boss bar's default near-the-top anchor, so `location`
  reflects the *whole* screen instead of being relative to that baseline.

## Color encoding

| Channel | Meaning |
|---|---|
| R | X position (raw byte, 0–255) |
| G | Y position (raw byte, 0–255) |
| B | unused, free for future use |
| A | must equal `HUD_ALPHA_MARKER`, or the vertex renders as normal text |

Each raw byte is scaled by `LOCATION_STEP` (currently `2`), giving a logical
range of `0`–`510` per axis. `LOCATION_CENTER = 256` (raw `128`) is the
middle of the screen; `0` is the left/top edge, `510` the right/bottom edge.

```
location = (R, G) * LOCATION_STEP
```

**Testing caveat:** a plain text component's `"color"` field is RGB-only —
there's no way to set Alpha through it. Set `HUD_ALPHA_MARKER = 255`
temporarily to test manually via `/bossbar set ... color:"#RRGGBB"`; this
matches *any* opaque text, so it must be reverted to a value like `254`
before the plugin drives it for real.

## Fine-tuning constant

`Y_FINE_TUNE_PIXELS` compensates a small residual vertical offset (glyph
baseline / `ceil()` rounding in `getScreenSize()`). It's recalibrated
empirically whenever the baseline correction above changes — not derived
from the projection math.