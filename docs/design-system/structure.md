# Structure

This document covers layout, spacing, typography, components, and interaction. The goal is interfaces that are first-class for both pointer and keyboard, never one at the expense of the other. A feature is not done until you can drive it end-to-end with the keyboard alone and end-to-end with the mouse alone.

Color decisions live in `colors.md`. Everything below assumes those tokens.

## Principles

1. **Keyboard parity.** Every action reachable by mouse must be reachable by keyboard, in a tab order that matches reading order. No keyboard-only escape hatches either — anything you can do with a shortcut should also be visible somewhere clickable.
2. **Visible focus, always.** The focused element is the most important thing on the screen for a keyboard user. Never suppress the focus ring without replacing it with something at least as obvious.
3. **One primary action per view.** A view has one main thing the user is here to do. That action is visually loudest, lives in a predictable place, and is the default when the user presses Enter.
4. **Information density follows context.** Dashboards and tools earn density. Onboarding and settings do not. Pick a density per view and hold it.
5. **Motion is a hint, not a feature.** Animation exists to explain a state change. If removing it does not lose meaning, remove it.

## Spacing scale

Use a 4px base. Multiples only — no 5, 7, 13. The scale below covers every gap, padding, and margin in the system.

| Step | Pixels | Typical use                                         |
| ---- | ------ | --------------------------------------------------- |
| 0    | 0      | Flush                                               |
| 1    | 4      | Icon-to-label, dense table padding                  |
| 2    | 8      | Tight stacks, button internal padding               |
| 3    | 12     | Default vertical rhythm in forms                    |
| 4    | 16     | Card padding, default section gap                   |
| 6    | 24     | Major section gap                                   |
| 8    | 32     | Page gutter, between unrelated regions              |
| 12   | 48     | Hero spacing, top-level page padding                |
| 16   | 64     | Empty-state breathing room                          |

## Hit targets

Pointer and keyboard have different needs and the design has to satisfy both at once.

- Minimum interactive size is 32×32px for keyboard-driven dense UI (toolbars, lists), 40×40px for general use, 44×44px for touch.
- Hit areas can extend beyond the visual bounds. A 16px icon button can carry a 40px hit area as long as adjacent targets do not overlap.
- Never rely on hover-only affordances. If an action only appears on hover, it does not exist for keyboard or touch. Show a persistent affordance and let hover refine it.

## Typography

Three families max per app: a UI sans, a content serif or sans, and a monospace. Pick once, document in the app's own readme, do not switch mid-product.

| Role           | Size  | Weight | Line height |
| -------------- | ----- | ------ | ----------- |
| Display        | 32    | 600    | 1.2         |
| H1             | 24    | 600    | 1.25        |
| H2             | 20    | 600    | 1.3         |
| H3             | 16    | 600    | 1.4         |
| Body           | 14    | 400    | 1.5         |
| Body large     | 16    | 400    | 1.5         |
| Caption        | 12    | 400    | 1.4         |
| Code / mono    | 13    | 400    | 1.5         |

Line length tops out at 75 characters for body copy. Past that, eyes lose the next line.

## Layout

- 12-column grid at desktop widths, 8 at tablet, 4 at mobile, 8px gutters at all sizes.
- Reserve a left or top region for primary navigation. Do not move it between views; muscle memory is a feature.
- Breakpoints: 640, 768, 1024, 1280, 1536. Design for the most common width first, then check the others.
- Sticky elements only for global chrome (top bar, sidebar). Do not stick body content.

## Focus and keyboard navigation

The focus model is the single most under-built part of most apps. Treat it as a first-class deliverable.

- Tab moves forward through interactive elements, Shift+Tab moves back. Tab order matches visual reading order — never rely on the DOM's accidental order.
- Arrow keys move within a composite widget (lists, menus, grids, tabs). Tab moves between widgets.
- Enter activates the focused element. Space activates buttons and toggles checkboxes. Esc closes the topmost overlay or cancels the current action.
- `/` focuses the primary search input on any view that has one.
- `?` opens a keyboard shortcut cheat sheet. Every app has one and it lists every shortcut the app defines.
- When a modal opens, focus moves to the modal's primary action or first input. When it closes, focus returns to the element that opened it.
- Skip links sit at the top of every page so a keyboard user can jump past navigation to main content with one tab.

## Components

The following are the canonical patterns. New components should compose from these before adding anything new.

### Buttons

- Three variants: primary (Blue background, Base text), secondary (Surface 0 background, Text foreground), ghost (transparent background, Text foreground).
- Destructive actions use Red as the background color in the primary slot. Never put a destructive action in the same row as a confirm action without separating them with at least 16px and reordering so the safe action is the default.
- Buttons have an icon slot on the left and a label. Icon-only buttons require an accessible label and a tooltip on hover or focus.

### Inputs

- Single-line and multi-line text inputs use Surface 0, Text foreground, Overlay 1 placeholder.
- Label sits above the input, never inside as a placeholder substitute.
- Validation message appears below the input. Error uses Red, success uses Green, helper text uses Subtext 0.
- Focus draws the Lavender ring per `colors.md`, not a colored border, so the field shape stays stable.

### Lists and tables

- Row height is consistent within a view. Pick 32, 40, or 48px once and hold.
- Hovered row uses Surface 1, selected row uses Surface 2. Both can apply at once when a hovered row is also the selection.
- Keyboard selection uses arrow keys; Space toggles selection in a multi-select context; Enter opens the focused row.
- Sortable columns indicate sort with an arrow icon and announce the sort change to screen readers.

### Modals and overlays

- Modals dim the rest of the page with Crust at 60% opacity and trap focus inside.
- Esc closes; clicking outside closes unless the modal has unsaved changes, in which case it asks first.
- Maximum two levels of stacked overlays. If you need a third, the flow is wrong.
- Drawers slide in from one edge and follow the same focus-trap and dismissal rules.

### Navigation

- Primary nav is persistent and shows the user's current location with the Lavender highlight on the active item.
- Breadcrumbs use Subtext 0 for parents and Text for the current page. Truncate from the middle when they overflow.
- Tabs use the Blue underline for the active tab and Subtext 1 for inactive tabs. Arrow keys move between tabs when one is focused.

### Empty, loading, and error states

- Every list, table, and dashboard has a designed empty state. The empty state names the missing data and offers the next action.
- Loading states are skeletons that match the eventual layout, not spinners on top of empty space. Spinners are reserved for actions under 1 second where a skeleton would be visual noise.
- Errors explain what failed in plain language, what the user can do next, and offer a retry. Never surface raw exception text.

## Motion

- Default duration: 150ms for state transitions, 250ms for entrances, 200ms for exits.
- Default easing: ease-out for entrances, ease-in for exits, ease-in-out for in-place transitions.
- Respect `prefers-reduced-motion`. When set, replace movement with cross-fades and drop durations to under 100ms.

## Accessibility floor

Not aspirational, mandatory.

- Color contrast hits WCAG AA: 4.5:1 for body text, 3:1 for large text and UI components against their adjacent surface.
- All interactive elements have an accessible name and a role. Icon-only buttons require a label.
- Form fields have associated labels. Validation errors are announced and tied to the field.
- Nothing depends on color alone. Errors carry an icon, success carries an icon, status carries a label.
- The page is usable at 200% zoom without horizontal scroll on standard viewports.

## What doesn't belong here

- Per-app tokens, per-app component variants, per-app naming conventions. Those live in the app.
- Brand voice and copy guidelines. Those live in a separate writing guide.
- Backend or data shape decisions. Those live with the service that owns them.
