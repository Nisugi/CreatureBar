# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CreatureBar is a visual status display for the Gemstone IV MUD, built as a Lich script using Ruby and GTK3. It provides real-time creature tracking with injury visualization, HP bars, and status effects for hunting/combat scenarios.

## Architecture

### Core Components

**Main Script** ([scripts/creaturebar.lic](scripts/creaturebar.lic))
- GTK3-based windowed interface for displaying creature panels
- Multi-creature support with configurable layout (horizontal/vertical grid)
- Family-aware silhouette system with per-creature-type configurations
- LRU caching for pixbufs (max 15 families) to manage memory
- Panel pooling for efficient widget reuse

**Calibration Tool** ([scripts/calibrate_creaturebar.lic](scripts/calibrate_creaturebar.lic))
- Visual coordinate calibrator for positioning wound markers on silhouettes
- Generates per-family YAML configs with body part coordinates, scaling, and display settings

### Configuration System

**Three-tier configuration:**

1. **Global config** ([data/creature_bar/config.yaml](data/creature_bar/config.yaml))
   - Window position, size, behavior (transparency, always-on-top)
   - Color scheme (HP, status, borders, backgrounds)
   - Layout settings (mode, max columns/rows, max creatures shown)
   - Status effects array (name, symbol, color)
   - Wound marker opacity

2. **Silhouette configs** ([data/creature_bar/silhouette_configs/](data/creature_bar/silhouette_configs/))
   - Per-family settings: `{family}.yaml` (e.g., `valravn.yaml`, `default.yaml`)
   - Each contains: scale, panel dimensions, marker size, body part coordinates
   - Display overrides: name_display, hp_bar, status (optional, falls back to global)
   - Body parts mapping: `{part_name}: [x, y]` coordinates at scale=1.0

3. **Silhouette images** ([data/creature_bar/silhouettes/](data/creature_bar/silhouettes/))
   - PNG files for creature silhouettes: `{family}.png` or `{noun}.png`
   - Rank wound markers: `Rank1.png`, `Rank2.png`, `Rank3.png`

**Family resolution priority:**
1. Check for noun-specific config/image (e.g., `valravn.png`)
2. Fall back to family from `creature.template.family` (e.g., `bird.png`)
3. Ultimate fallback to `default.png`

### Data Flow

1. **Update loop** (250ms default): `start_update_timer` → `update_display`
2. **Target detection**: Queries `GameObj.targets` and `Creature[id]` from Lich
3. **Panel management**:
   - Creates/pools panels per creature family
   - Updates content: name, border (current target), HP bar, wounds, status
   - Only triggers GTK redraws when data changes (optimization)
4. **Wound overlays**: Positioned using family config coordinates, scaled by `scale` factor
5. **HP bar drawing**: Cairo-based rounded rectangles with color-coded ranges

### Key Design Patterns

**Family-aware panel pooling:**
- Panels are expensive to create (GTK widgets, signal handlers, pixbuf loading)
- Pool maintains panels by family to enable exact reuse
- Pool limit: `max_shown * 2 + 1` to prevent unbounded growth
- FIFO strategy per family

**Coordinate scaling:**
- Body part coords stored at scale=1.0 in YAML
- Runtime: `scaled_x = coords[0] * scale`, applied when placing wound overlays
- Calibrator saves normalized coords, main script scales for display

**Change detection optimization:**
- Panel widgets track last values: `last_name`, `last_status_key`, `hp_fraction`, etc.
- Only update GTK widgets when values differ (avoids redundant Pango parsing, redraws)

**CSS-based theming:**
- Global CSS provider for window background, borders, fonts
- Per-panel markup for name/status (size, weight, color) to override CSS when needed
- Current target border uses CSS class `.current_target`

## Development Workflow

### Running the Script

The script is designed to run inside the Lich scripting environment for Gemstone IV:

```ruby
# Start the bar
;creaturebar

# Open settings dialog on start
;creaturebar config
```

### Creating/Calibrating New Silhouettes

1. Add `{family}.png` to [data/creature_bar/silhouettes/](data/creature_bar/silhouettes/)
2. Run `;calibrate_creaturebar` in Lich
3. Select the family from dropdown
4. Click on silhouette to position each body part marker
5. Adjust panel dimensions, marker size, scale in the UI
6. Save to generate [data/creature_bar/silhouette_configs/{family}.yaml](data/creature_bar/silhouette_configs/)
7. Reload CreatureBar to test

### Configuration Editing

**Via UI:** Right-click CreatureBar window → Settings
- Layout tab: grid mode, max columns/rows, max creatures shown
- HP Colors, Status Colors, Window Colors tabs
- Behavior tab: update interval, transparency, decorations, wound opacity

**Via YAML:** Edit [data/creature_bar/config.yaml](data/creature_bar/config.yaml) directly, then right-click → Reload Configuration

### Adding New Body Parts

1. Update `BODY_PARTS` constant in [scripts/calibrate_creaturebar.lic](scripts/calibrate_creaturebar.lic)
2. Re-calibrate affected silhouettes
3. Main script reads body parts dynamically from YAML (no code changes needed)

### Adding New Status Effects

1. Via UI: Settings → Status Colors tab → Add Status
2. Via YAML: Add to `status_effects` array in config.yaml:
   ```yaml
   status_effects:
     - name: stunned
       symbol: S
       color: '#FFD700'
   ```

## Important Implementation Details

**GTK threading:**
- All GTK calls must be wrapped in `Gtk.queue { ... }`
- Update timer runs in background thread, queues GTK updates

**Signal handler cleanup:**
- HP bar draw signals stored in `panel[:draw_signal_id]`
- Must disconnect via `signal_handler_disconnect` when destroying panels

**Window resizing:**
- Horizontal mode: width calculated from panel widths, only height saved
- Vertical mode: both width and height saved
- `resize_window_for_panels` auto-sizes based on grid and panel dimensions

**Config migration:**
- `load_config` handles deprecated keys (old status color format, per-global body_parts)
- Removes obsolete settings automatically on load

**Lich integration dependencies:**
- `GameObj.targets`: Live target list from game XML
- `Creature[id]`: Creature data module (HP, wounds, status, template)
- `XMLData.current_target_id`: Current target for border highlighting
- `do_client(cmd)`: Send commands to game client
- `Frontend.refocus_callback`: Return focus to game window after click

## Debugging

Enable debug output:
```ruby
$creature_bar_debug = true
```

This logs:
- Family resolution (noun → family → default)
- Silhouette config loading
- Panel creation/pooling
- Wound overlay positioning
- Border toggle logic
