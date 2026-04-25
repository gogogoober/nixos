# Colors

The palette is Catppuccin Mocha. Every UI surface across our apps pulls from this list — no off-palette hex codes, no ad-hoc tints. If a color you need is not here, you are reaching for the wrong abstraction; pick the closest semantic role and adjust opacity instead.

Legibility wins over consistency. These mappings are guidelines, and individual surfaces may deviate when contrast or hierarchy demands it. Document the deviation in the file where it lives.

## Palette

### Base layer

| Token    | Hex       | Used for                                              |
| -------- | --------- | ----------------------------------------------------- |
| Base     | `#1e1e2e` | Default app background                                |
| Mantle   | `#181825` | Sidebars, secondary panes, anything one level deeper  |
| Crust    | `#11111b` | Title bars, status bars, the deepest chrome           |

### Surfaces

Use surfaces for raised elements that sit on top of the base layer. The number indicates elevation — Surface 0 is closest to the base, Surface 2 is most prominent.

| Token     | Hex       | Used for                                              |
| --------- | --------- | ----------------------------------------------------- |
| Surface 0 | `#313244` | Cards, input fields, low-emphasis containers          |
| Surface 1 | `#45475a` | Hovered surfaces, dividers, table row separators      |
| Surface 2 | `#585b70` | Active/pressed surfaces, selected row backgrounds     |

### Overlays

Overlays sit above surfaces and carry transient or supporting content.

| Token     | Hex       | Used for                                              |
| --------- | --------- | ----------------------------------------------------- |
| Overlay 0 | `#6c7086` | Disabled text, faint borders, scrollbar tracks        |
| Overlay 1 | `#7f849c` | Subtle text, placeholder copy, comment-tier text      |
| Overlay 2 | `#9399b2` | Tooltips, focus ring fallback, selection background   |

### Typography

| Token     | Hex       | Used for                                              |
| --------- | --------- | ----------------------------------------------------- |
| Text      | `#cdd6f4` | Body copy, primary headlines                          |
| Subtext 1 | `#bac2de` | Sub-headlines, secondary labels                       |
| Subtext 0 | `#a6adc8` | Tertiary labels, metadata                             |
| Overlay 1 | `#7f849c` | Subtle/de-emphasized text                             |
| Base      | `#1e1e2e` | Text drawn on top of an accent background             |

### Accents

The accent rotation is the same fourteen colors across every surface. Pick by meaning, not by what looks fresh — meaning is what makes the system learnable.

| Token     | Hex       | Default role                                          |
| --------- | --------- | ----------------------------------------------------- |
| Rosewater | `#f5e0dc` | Cursor, caret, the user's pointer of focus            |
| Flamingo  | `#f2cdcd` | Soft highlight, gentle attention                      |
| Pink      | `#f5c2e7` | Decorative, secondary tags                            |
| Mauve     | `#cba6f7` | Keywords, primary brand accent                        |
| Red       | `#f38ba8` | Errors, destructive actions                           |
| Maroon    | `#eba0ac` | Modified state, edited indicators                     |
| Peach     | `#fab387` | Constants, numeric emphasis                           |
| Yellow    | `#f9e2af` | Warnings, pending states                              |
| Green     | `#a6e3a1` | Success, additions, confirmation                      |
| Teal      | `#94e2d5` | Informational accent, secondary success               |
| Sky       | `#89dceb` | Quiet info, breadcrumbs                               |
| Sapphire  | `#74c7ec` | Secondary links                                       |
| Blue      | `#89b4fa` | Links, primary action, focus ring, selected tabs      |
| Lavender  | `#b4befe` | Highlights, active keyboard focus, selection emphasis |

## Semantic mappings

These are the canonical pairings. A new component should reuse them before introducing anything new.

| Role                       | Color                                |
| -------------------------- | ------------------------------------ |
| Primary action             | Blue                                 |
| Destructive action         | Red                                  |
| Success / confirmation     | Green                                |
| Warning                    | Yellow                               |
| Error                      | Red                                  |
| Info                       | Teal                                 |
| Link                       | Blue                                 |
| Visited link               | Mauve                                |
| Tag, pill, badge           | Blue (default), recolor by category  |
| Selection background       | Overlay 2 at 25% opacity             |
| Cursor / caret             | Rosewater                            |
| Keyboard focus ring        | Lavender at 100%, 2px outer outline  |
| Hover surface (cursor)     | Surface 1                            |
| Active / pressed surface   | Surface 2                            |
| Disabled foreground        | Overlay 0                            |
| Disabled background        | Surface 0 at 50% opacity             |

## Interaction states

Every interactive element must read clearly in five states. Both pointer and keyboard users need to know what is selected, what is hovered, and what is about to happen on activation.

| State            | Treatment                                                                |
| ---------------- | ------------------------------------------------------------------------ |
| Rest             | Surface 0 background, Text foreground                                    |
| Hover (cursor)   | Surface 1 background, no border change, cursor switches to pointer       |
| Focus (keyboard) | Lavender 2px outer outline, 2px offset, never replaces the hover color   |
| Active / pressed | Surface 2 background, foreground unchanged                               |
| Disabled         | Surface 0 at 50%, Overlay 0 foreground, no hover or focus response       |

Hover and focus are independent. A keyboard user tabbing onto a button should see the focus ring; a cursor user mousing over the same button should see the hover background. When both apply, draw both — the ring sits outside the surface so they do not collide.

## Opacity rules

Opacity is a tool for layering, not for inventing new colors. Stick to a small set of stops so values remain memorizable.

| Stop | Use                                              |
| ---- | ------------------------------------------------ |
| 100% | Default                                          |
| 75%  | De-emphasized but still active                   |
| 50%  | Disabled foreground or background                |
| 25%  | Selection background, soft highlight overlays    |
| 10%  | Hover tint over an accent (e.g. Blue at 10%)     |

## Do and don't

- **Do** assign one accent per semantic role and reuse it everywhere that role appears.
- **Do** rely on Surface 1 and Surface 2 for hover and active states rather than tinting accents.
- **Do** put the focus ring outside the element so it never fights with the hover color.
- **Don't** mix accents within a single component to add visual interest. Pick one and let typography carry the rest.
- **Don't** use Text on an accent background. Use Base — the palette is built so accents are bright enough that dark text on top is readable.
- **Don't** invent new hex values for hover, active, or disabled. Reach for an existing surface or an opacity stop.
