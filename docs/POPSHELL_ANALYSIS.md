# Pop-Shell Source Code Analysis

## Repository Structure

Source: `https://github.com/pop-os/shell` (~384KB TypeScript)

### Key Source Files

| File | Lines | Responsibility |
|---|---|---|
| `src/forest.ts` | ~925 | Forest: core tree data structure, all fork trees per monitor/workspace |
| `src/fork.ts` | ~374 | Fork: binary node splitting screen space into left/right children |
| `src/node.ts` | ~247 | Node: algebraic data type (Fork, Window, Stack) |
| `src/auto_tiler.ts` | ~760 | AutoTiler: orchestrator for attach/detach/tile operations |
| `src/tiling.ts` | ~950 | Tiler: keyboard-driven window management mode |
| `src/stack.ts` | ~726 | Stack: grouped/tabbed windows with visual tab bar |
| `src/ecs.ts` | ~284 | Entity Component System: generational IDs, Storage<T>, World |
| `src/arena.ts` | ~43 | Arena: hop-slot allocator for stacks/tabs |
| `src/geom.ts` | ~108 | Geometry: distance, nearest_side, shortest_side |
| `src/focus.ts` | ~78 | FocusSelector: directional window focus |
| `src/keybindings.ts` | ~86 | Keybinding registration with GNOME Shell |
| `src/extension.ts` | ~1000+ | Ext class: main entry point, GNOME Shell integration |
| `src/movement.ts` | ~45 | Movement flags: grow/shrink + direction |
| `src/rectangle.ts` | ~107 | Rectangle: geometry with x,y,width,height |

## Tiling Algorithm Details

### Binary Tree Structure

```
Forest
  └── toplevel: Map<string, [Entity, [monitor, workspace]]>
        └── Fork (root)
              ├── left: Node (Fork | Window | Stack)
              └── right: Node? (Fork | Window | Stack)
```

### Fork.measure() — The Core Layout Function

1. If not toplevel, compute ratio from current dimensions
2. If right child exists:
   - Calculate split point from `lengthLeft`
   - Snap to 32px grid (with dead zone ±32px around 50%)
   - Compute left region: `[area.x, area.y, len - gapInnerHalf, area.height]`
   - Compute right region: `[area.x + len + gapInnerHalf, area.y, total - len - gapInnerHalf, area.height]`
   - Recursively measure both children
3. If only left child: give it the entire area

### Window Attachment Flow

```
attachWindow(onto, new, placeBy):
  1. Search all forks for one containing `onto`
  2. If onto is left child:
     a. If right exists: create sub-fork(left=old_left, right=new), replace left
     b. If no right: new becomes right, ratio = 50%
  3. If onto is in stack: add new to that stack
  4. If onto is right child: similar to (2) but on right side
  5. Apply placement (cursor position or keyboard source)
```

### Window Detachment Flow

```
detach(fork, window):
  1. If window is left child:
     a. If has parent and right exists: promote right to parent
     b. If no parent but right exists: compress tree
     c. If no right: delete fork entirely
  2. If window is in stack: remove from stack, collapse if last
  3. Similar logic for right branch
  4. Rebalance orientation after detachment
```

### Stacking Details

- `NodeStack` in tree: `{kind: 3, idx: number, entities: Entity[], rect: Rect}`
- `Stack` container: manages visual tab bar (St.BoxLayout)
- Tab bar height: `24 * DPI` pixels
- Active tab: user's hint color; Inactive: `#9B8E8A`
- Only active window visible (others hidden via Clutter actor)
- Move left/right within stack: reorder or detach at edges
- Move up/down: always detach from stack

### Resize Algorithm

```
resize(fork, window, movement, crect):
  1. Walk tree upward from window's fork
  2. Find ancestor fork whose split direction aligns with resize direction
  3. Adjust that fork's ratio based on new dimensions
  4. Clamped to minimum 256px on each side
```

### Smart Gaps

- When a single window fills a workspace, outer gaps are removed
- `fork.smartGapped = true` when fork is toplevel and has no right child
- Toggled back when second window is attached

## GNOME Shell Integration Points

These are the main GNOME-specific APIs used by pop-shell:

1. **Meta.Window** — window object with frame_rect, monitor, workspace
2. **Mutter compositor** — actor show/hide for stack visibility
3. **GObject signals** — window-created, destroyed, focus-changed
4. **GNOME Shell keybindings** — wm.addKeybinding()
5. **St widgets** — St.BoxLayout for tab bar, St.Button for tabs
6. **Clutter actors** — overlay, visual feedback
7. **GSettings** — user preferences storage

Each of these has a macOS equivalent (see ARCHITECTURE.md).
