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

The vertex color is not a color at all in the usual sense — **the color IS
the position**. Two of its channels are read back as raw numbers and turned
directly into screen coordinates; see the demo at the bottom.

## What changed since the last version

- HUD detection moved from the **Alpha channel** to the **Blue channel**
  (`HUD_MARKER_VALUE`, currently `253`). Alpha turned out to be a dead end:
  `TextColor` in the Adventure API (what the plugin actually uses to color
  boss bar text) is RGB-only — there's no way to write Alpha from server
  code, only by hand-crafting raw `/bossbar` JSON for manual tests. Blue is
  fully controllable from the plugin.
- Added a fixed vertical baseline correction (`offset.y += screen.y * 0.5`)
  to cancel the boss bar's default near-the-top anchor, so `location =
  (256,256)` now lands on the true screen center instead of near the top.
- `Y_FINE_TUNE_PIXELS` was recalibrated (now `18.5`) to match the residual
  offset left over *after* that baseline correction — the old value was
  tuned for a different (larger) residual and no longer applies.
- The plugin must explicitly disable the text shadow
  (`ShadowColor.shadowColor(0)`). Without it, the shadow pass (always 1/4
  the brightness of the main color) renders as an untouched "ghost" copy at
  the boss bar's default position, since its dimmed Blue value never
  matches `HUD_MARKER_VALUE` on purpose.
- Multi-character strings (e.g. a placeholder like `"127"`) are **not**
  rendered as plain text. Vanilla's automatic kerning/advance between
  characters isn't controlled by this system and was observed to be
  inconsistent between resolutions. Each character is instead built as its
  own independently-positioned element (its own encoded color), the same
  way a single badge is — see `buildNumberComponent` on the plugin side.

## Color encoding

| Channel | Meaning |
|---|---|
| R | X position (raw byte, 0–255) |
| G | Y position (raw byte, 0–255) |
| B | must equal `HUD_MARKER_VALUE`, or the vertex renders as normal text |
| A | unused (can't be controlled from the plugin anyway) |

Each raw byte is scaled by `LOCATION_STEP` (currently `2`), giving a logical
range of `0`–`510` per axis. `LOCATION_CENTER = 256` (raw `128`) is the
middle of the screen; `0` is the left/top edge, `510` the right/bottom edge.

```
location = (R, G) * LOCATION_STEP
```

### Examples (with `HUD_MARKER_VALUE = 253` → hex suffix `FD`)

| Position | R | G | Hex |
|---|---|---|---|
| Center | 128 | 128 | `#8080FD` |
| Top-left corner | 0 | 0 | `#0000FD` |
| Bottom-right corner | 255 | 255 | `#FFFFFD` |
| Top-right corner | 255 | 0 | `#FF00FD` |
| Bottom-left corner | 0 | 255 | `#00FFFD` |
| Slightly left of center | 108 | 128 | `#6C80FD` |

**Testing caveat:** a plain text component's `"color"` field is RGB-only —
there's no way to set Alpha through it either, which is moot now since the
marker lives in Blue. For quick manual tests via
`/bossbar set ... color:"#RRGGBB"`, just use the hex values above directly.

## Fine-tuning constant

`Y_FINE_TUNE_PIXELS` compensates a small residual vertical offset (glyph
baseline / `ceil()` rounding in `getScreenSize()`). It's recalibrated
empirically whenever the baseline correction above changes — not derived
from the projection math.

## Demo

[demo/Position.mp4](demo/Position.mp4) — shows the direct relationship
between the encoded vertex color and where the element lands on screen: as
the color's R/G values change, the position moves accordingly, live.