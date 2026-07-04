# Hud Resourcepack

A custom HUD rendering system built on top of Minecraft's vanilla text
rendering pipeline (`rendertype_text` core shaders). It hijacks the boss bar
title as a rendering surface: individual glyphs (mapped to Private Use Area
Unicode codepoints via a resource pack font provider) are detected in the
vertex shader by their vertex color and repositioned to an arbitrary point on
screen, instead of being rendered in place as normal text. This makes it
possible to draw fixed badge/icon elements anywhere on the HUD without
touching Java-side GUI rendering code at all.

## How an element is identified

Each glyph's vertex color is used as an identifier instead of an actual
color. The R, G, and B channels are each treated as a base-4 digit
(0–3), giving up to **64 addressable elements** per shader
(`HUD_CHANNEL_MAX = 3`, `HUD_CHANNEL_BASE = HUD_CHANNEL_MAX + 1`):

```
hudIndex = R * 16 + G * 4 + B
```

Colors outside the 0–3 range per channel are ignored by the HUD system and
rendered as normal text/UI, so this never intercepts legitimate text colors.

| Element example | R | G | B | Hex color | hudIndex |
|---|---|---|---|---|---|
| badge 0 | 0 | 0 | 0 | `#000000` | 0 |
| badge 1 | 0 | 0 | 1 | `#000001` | 1 |
| badge 4 | 0 | 1 | 0 | `#000100` | 4 |

The alpha channel is not part of the identifier; keep it at full opacity
(255) so the glyph itself renders visibly.

## The `Element` struct

```glsl
struct Element {
    vec2 size;      // rendered size of the glyph, in GUI-scaled pixels
    vec2 location;  // anchor position on screen
    vec2 margin;    // inward padding from the screen edge, in pixels
    int bar;        // stacking row, for elements sharing a bossbar slot
};
```

All numeric fields are `float`/`vec2` (not integers), on purpose — every
range below is a **soft convention**, not a hard clamp. Nothing in the shader
enforces these bounds, so values outside the stated range are valid and are
useful for fine adjustments (nudging an element a couple of pixels past an
edge, slightly overshooting 100 to bleed off-screen intentionally, etc).

### `size`

Must match the **actual rendered size** of the glyph as scaled by the font
provider (`height` value in the resource pack's font JSON, combined with the
source image's aspect ratio) — **not** the raw pixel dimensions of the
source PNG file, unless the font JSON's `height` happens to equal the PNG's
real height (in which case they're the same number). Getting this wrong
doesn't matter for square glyphs (it just scales uniformly), but it distorts
positioning as soon as width and height differ.

### `location`

Percentage-based anchor position, conceptually 0–100 per axis, but expressed
in two different conventions per axis:

- **X**: `0` = left edge, `100` = right edge, straightforward 0–100 range.
- **Y**: centered convention — `-50` = top edge, `0` = vertical middle,
  `50` = bottom edge. This got flipped/re-derived a few times during
  development, so it's intentionally documented distinctly from X.

Since these are floats, values like `-55` or `105` are legal and will place
the element slightly past the corresponding edge — handy for allowing a
badge to bleed off-screen or compensate for another element's margin.

### `margin`

Extra padding, in pixels (GUI-scaled), always pushed inward from whichever
edge the element is anchored to. `vec2(0, 0)` means flush to the computed
anchor point with no extra offset.

### `bar`

Which stacked boss bar "row" the element lives in, used to avoid overlapping
elements that share the same screen region. Row height is controlled by
`BAR_ROW_HEIGHT` in the vertex shader. There is no hardcoded engine limit on
how many boss bars can stack — test up to however many concurrent elements
your use case actually needs.

## Fine-tuning constant

`Y_FINE_TUNE_PIXELS` (in `utils.glsl`) compensates a small residual
downward offset observed empirically in-game (likely glyph
baseline/padding, or rounding in `getScreenSize()`'s `ceil()`). It isn't
derived from the projection math — recalibrate it by eye if the rendering
pipeline changes.