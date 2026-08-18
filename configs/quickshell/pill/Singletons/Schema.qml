pragma Singleton

import QtQuick
import Quickshell

/**
 * SCHEMA: the single declarative description of every user-facing setting the
 * shell owns. It is metadata only — no reads, no writes, no UI. Store routes a
 * write by `backend`/`key`, the pages read `label`/`caption`/`options`/`def`,
 * and the index search reads the same table, so a setting is described exactly
 * once.
 *
 * `settings` is keyed by a stable camelCase id. Every entry carries where it
 * lives today (`page`, `group`, `order`), how it reads (`label`, `caption`),
 * how it is driven (`control`), and where it is stored (`type`, `backend`,
 * `key`, `def`). Scrubs add `from`/`to`/`step`/`unit`; segs add `options`.
 *
 * `def` is the value the shipped source produces, copied from that backend's
 * source of truth — Flags.qml's JsonAdapter for `flags`/`idle`/`night`/`rec`,
 * the repo's hypr Lua modules for `deco`/`input`/`anim`, ghostty's config for
 * `app`. It is a fallback for a missing field, never an overwrite of a stored
 * user value.
 *
 * `key` is read in the namespace of its `backend`, and the namespaces differ:
 * `flags`/`idle`/`night` keys are Flags.qml JsonAdapter names; `deco`/`input`/
 * `anim` keys are Lua field names (`blur.size`/`shadow.range` name their block
 * explicitly, and an UPPER_CASE `input` key like `XCURSOR_SIZE` means env.lua,
 * not input.lua); `rec` keys are ScreenRec's WRAPPER PROPERTY names — `fps`,
 * `quality`, `captureCursor`, `micOn`, `desktopOn`. The two recorder settings
 * ScreenRec does not wrap are `flags` entries: `recordDir` (ScreenRec.outDir is
 * readonly; its folder picker writes Flags.recordDir) and `recordCountdown`
 * (the drawer writes Flags directly). `app` covers everything that belongs to
 * no other backend: ghostty's config, the screen vibrance Devices persists to
 * its own state file, and the bespoke editors that own their own files
 * (`key: ""`, never Store-routed).
 *
 * `control: "custom"` marks a setting whose UI is bespoke (the monitor card,
 * the hue strip, the bezier editor, the keybind and workspace editors). Those
 * carry page-level metadata; the ones with no Store backend of their own
 * (monitors.lua, binds.lua, workspace rules) sit on `app` with an empty key
 * and are not Store-routed.
 *
 * This file documents the CURRENT tree. Moves, renames and de-duplication
 * happen in later tasks by editing this table, not the pages.
 */
Singleton {
    id: root

    /** The settings index, in the order the rows appear today. */
    readonly property var pages: [
        { id: "appearance", title: "Appearance", caption: "Clock, accent palette, scale", icon: "sparkles" },
        { id: "look", title: "Look", caption: "Gaps, rounding, blur, opacity", icon: "app-window" },
        { id: "display", title: "Display", caption: "Resolution, refresh, scale", icon: "monitor" },
        { id: "input", title: "Input", caption: "Pointer, keyboard, cursor", icon: "mouse" },
        { id: "animation", title: "Animation", caption: "Speed, motion curve, enable", icon: "waves" },
        { id: "keybinds", title: "Keybinds", caption: "Rebind, add, set commands", icon: "keyboard" },
        { id: "workspaces", title: "Workspaces", caption: "Special spaces and their keys", icon: "layers" },
        { id: "idlelock", title: "Idle / Lock", caption: "Auto-lock, screen off, suspend", icon: "lock" }
    ]

    /**
     * Page ids that hold settings but are NOT settings pages: surfaces
     * elsewhere in the shell that own a setting today. They are legal `page`
     * values and deliberately absent from `pages`, which drives the index.
     * The homes for these are decided when the new pages land.
     */
    readonly property var outsidePages: ["mixer", "recorder", "wallpaper", "calendar"]

    /**
     * Named groups per page, in the order they appear on screen. A page absent
     * from this map is flat: every one of its entries carries `group: ""`.
     * Reordering a page's groups is an edit here, not in the page.
     */
    readonly property var groupOrder: ({
        look: ["window", "night", "shadow", "blur", "opacity", "pill"],
        input: ["pointer", "keyboard", "cursor"],
        animation: ["motion", "curve"],
        recorder: ["options", "audio"]
    })

    readonly property var settings: ({

        // ── Appearance ────────────────────────────────────────────────────
        time12h: {
            page: "appearance", group: "", order: 0,
            label: "Time format", caption: "",
            control: "seg", type: "bool", backend: "flags", key: "time12h", def: false,
            options: [{ label: "24H", value: false }, { label: "12H", value: true }]
        },
        clockSeconds: {
            page: "appearance", group: "", order: 1,
            label: "Clock seconds", caption: "",
            control: "toggle", type: "bool", backend: "flags", key: "clockSeconds", def: false
        },
        musicViz: {
            page: "appearance", group: "", order: 2,
            label: "Music visualizer", caption: "",
            control: "toggle", type: "bool", backend: "flags", key: "musicViz", def: true
        },
        paletteMode: {
            page: "appearance", group: "", order: 3,
            label: "Palette", caption: "",
            control: "seg", type: "string", backend: "flags", key: "paletteMode", def: "static",
            options: [{ label: "Static", value: "static" }, { label: "Dynamic", value: "dynamic" }, { label: "Manual", value: "manual" }]
        },
        manualHue: {
            page: "appearance", group: "", order: 4,
            label: "Accent hue", caption: "Rainbow strip, manual palette only",
            control: "custom", type: "int", backend: "flags", key: "manualHue", def: 30,
            from: 0, to: 359, step: 1, unit: ""
        },
        manualDark: {
            page: "appearance", group: "", order: 5,
            label: "Accent tone", caption: "Dark or light accent",
            control: "seg", type: "bool", backend: "flags", key: "manualDark", def: true,
            options: [{ label: "Dark", value: true }, { label: "Light", value: false }]
        },
        manualSat: {
            page: "appearance", group: "", order: 6,
            label: "Accent saturation", caption: "Set by the hex field with the hue",
            control: "custom", type: "real", backend: "flags", key: "manualSat", def: 0.5,
            from: 0, to: 1, step: 0.01, unit: ""
        },
        randomScope: {
            page: "appearance", group: "", order: 7,
            label: "Random wallpaper", caption: "",
            control: "seg", type: "string", backend: "flags", key: "randomScope", def: "all",
            options: [{ label: "All screens", value: "all" }, { label: "Cursor screen", value: "cursor" }]
        },
        uiScale: {
            page: "appearance", group: "", order: 8,
            label: "UI scale", caption: "",
            control: "seg", type: "real", backend: "flags", key: "uiScale", def: 1.0,
            options: [{ label: "90%", value: 0.9 }, { label: "100%", value: 1.0 }, { label: "110%", value: 1.1 }, { label: "125%", value: 1.25 }]
        },
        reduceMotion: {
            page: "appearance", group: "", order: 9,
            label: "Reduce motion", caption: "",
            control: "toggle", type: "bool", backend: "flags", key: "reduceMotion", def: false
        },
        uiFont: {
            page: "appearance", group: "", order: 10,
            label: "Font", caption: "",
            control: "nav", type: "string", backend: "flags", key: "uiFont", def: ""
        },

        // ── Look · Window ─────────────────────────────────────────────────
        gapsIn: {
            page: "look", group: "window", order: 0,
            label: "Gaps inner", caption: "Space between tiled windows",
            control: "scrub", type: "int", backend: "deco", key: "gaps_in", def: 6,
            from: 0, to: 40, step: 1, unit: "px"
        },
        gapsOut: {
            page: "look", group: "window", order: 1,
            label: "Gaps outer", caption: "Space to the screen edge",
            control: "scrub", type: "int", backend: "deco", key: "gaps_out", def: 12,
            from: 0, to: 60, step: 1, unit: "px"
        },
        rounding: {
            page: "look", group: "window", order: 2,
            label: "Rounding", caption: "Corner radius in pixels",
            control: "scrub", type: "int", backend: "deco", key: "rounding", def: 14,
            from: 0, to: 30, step: 1, unit: "px"
        },
        roundingPower: {
            page: "look", group: "window", order: 3,
            label: "Rounding power", caption: "Higher bends corners to a squircle",
            control: "scrub", type: "int", backend: "deco", key: "rounding_power", def: 4,
            from: 1, to: 10, step: 1, unit: ""
        },
        borderSize: {
            page: "look", group: "window", order: 4,
            label: "Border size", caption: "Window outline thickness",
            control: "scrub", type: "int", backend: "deco", key: "border_size", def: 0,
            from: 0, to: 8, step: 1, unit: "px"
        },
        resizeOnBorder: {
            page: "look", group: "window", order: 5,
            label: "Resize on border", caption: "Drag a window edge to resize",
            control: "toggle", type: "bool", backend: "deco", key: "resize_on_border", def: true
        },
        layout: {
            page: "look", group: "window", order: 6,
            label: "Layout", caption: "Tiling layout for new windows",
            control: "seg", type: "string", backend: "deco", key: "layout", def: "dwindle",
            options: [{ label: "Dwindle", value: "dwindle" }, { label: "Master", value: "master" }]
        },

        // ── Look · Night light ────────────────────────────────────────────
        nightLightMode: {
            page: "look", group: "night", order: 0,
            label: "Mode", caption: "Off, always warm, or auto by time",
            control: "seg", type: "string", backend: "night", key: "nightLightMode", def: "off",
            options: [{ label: "Off", value: "off" }, { label: "On", value: "on" }, { label: "Scheduled", value: "scheduled" }]
        },
        nightLightTemp: {
            page: "look", group: "night", order: 1,
            label: "Temperature", caption: "Lower is warmer",
            control: "scrub", type: "int", backend: "night", key: "nightLightTemp", def: 4000,
            from: 2200, to: 6000, step: 100, unit: "K"
        },
        nightLightOnMin: {
            page: "look", group: "night", order: 2,
            label: "On at", caption: "Warm tint starts",
            control: "scrub", type: "int", backend: "night", key: "nightLightOnMin", def: 1260,
            from: 0, to: 1425, step: 15, unit: ""
        },
        nightLightOffMin: {
            page: "look", group: "night", order: 3,
            label: "Off at", caption: "Back to neutral",
            control: "scrub", type: "int", backend: "night", key: "nightLightOffMin", def: 450,
            from: 0, to: 1425, step: 15, unit: ""
        },

        // ── Look · Shadow ─────────────────────────────────────────────────
        shadowEnabled: {
            page: "look", group: "shadow", order: 0,
            label: "Enabled", caption: "Drop shadow under windows",
            control: "toggle", type: "bool", backend: "deco", key: "shadow.enabled", def: true
        },
        shadowRange: {
            page: "look", group: "shadow", order: 1,
            label: "Range", caption: "How far the shadow spreads",
            control: "scrub", type: "int", backend: "deco", key: "shadow.range", def: 18,
            from: 0, to: 50, step: 1, unit: "px"
        },
        shadowRenderPower: {
            page: "look", group: "shadow", order: 2,
            label: "Render power", caption: "Shadow falloff sharpness",
            control: "scrub", type: "int", backend: "deco", key: "shadow.render_power", def: 3,
            from: 1, to: 4, step: 1, unit: ""
        },

        // ── Look · Blur ───────────────────────────────────────────────────
        blurEnabled: {
            page: "look", group: "blur", order: 0,
            label: "Enabled", caption: "Blur behind transparent windows",
            control: "toggle", type: "bool", backend: "deco", key: "blur.enabled", def: true
        },
        blurSize: {
            page: "look", group: "blur", order: 1,
            label: "Strength", caption: "Blur radius",
            control: "scrub", type: "int", backend: "deco", key: "blur.size", def: 8,
            from: 1, to: 20, step: 1, unit: "px"
        },
        blurPasses: {
            page: "look", group: "blur", order: 2,
            label: "Passes", caption: "More passes, smoother blur",
            control: "scrub", type: "int", backend: "deco", key: "blur.passes", def: 3,
            from: 1, to: 5, step: 1, unit: ""
        },
        blurVibrancy: {
            page: "look", group: "blur", order: 3,
            label: "Vibrancy", caption: "Color saturation behind the blur",
            control: "scrub", type: "real", backend: "deco", key: "blur.vibrancy", def: 0.17,
            from: 0, to: 1, step: 0.01, unit: ""
        },
        blurNoise: {
            page: "look", group: "blur", order: 4,
            label: "Noise", caption: "Grain mixed into the blur",
            control: "scrub", type: "real", backend: "deco", key: "blur.noise", def: 0.01,
            from: 0, to: 0.2, step: 0.01, unit: ""
        },

        // ── Look · Opacity ────────────────────────────────────────────────
        activeOpacity: {
            page: "look", group: "opacity", order: 0,
            label: "Active window", caption: "Focused window transparency",
            control: "scrub", type: "real", backend: "deco", key: "active_opacity", def: 1.0,
            from: 0.5, to: 1.0, step: 0.05, unit: ""
        },
        inactiveOpacity: {
            page: "look", group: "opacity", order: 1,
            label: "Inactive window", caption: "Unfocused window transparency",
            control: "scrub", type: "real", backend: "deco", key: "inactive_opacity", def: 1.0,
            from: 0.5, to: 1.0, step: 0.05, unit: ""
        },
        termBgOpacity: {
            page: "look", group: "opacity", order: 2,
            label: "Terminal background", caption: "Ghostty background only. Text stays solid.",
            control: "scrub", type: "real", backend: "app", key: "background-opacity", def: 0.85,
            from: 0.5, to: 1.0, step: 0.05, unit: ""
        },

        // ── Look · Pill ───────────────────────────────────────────────────
        topGap: {
            page: "look", group: "pill", order: 0,
            label: "Pill gap", caption: "Space above the pill. Lower pulls windows up with it.",
            control: "scrub", type: "real", backend: "flags", key: "topGap", def: 1.0,
            from: 0, to: 2, step: 0.1, unit: ""
        },
        appGap: {
            page: "look", group: "pill", order: 1,
            label: "App gap", caption: "Space under the pill. Lower pulls windows up.",
            control: "scrub", type: "real", backend: "flags", key: "appGap", def: 1.0,
            from: 0, to: 2, step: 0.1, unit: ""
        },
        pillOpacity: {
            page: "look", group: "pill", order: 2,
            label: "Pill opacity", caption: "How see-through the pill sits",
            control: "scrub", type: "real", backend: "flags", key: "pillOpacity", def: 1.0,
            from: 0.55, to: 1.0, step: 0.05, unit: ""
        },
        pillBlur: {
            page: "look", group: "pill", order: 3,
            label: "Pill blur", caption: "Frosts behind the pill. Needs opacity under 100%.",
            control: "toggle", type: "bool", backend: "flags", key: "pillBlur", def: false
        },
        material: {
            page: "look", group: "pill", order: 4,
            label: "Material", caption: "Glass, frost or ink for the pill and surfaces",
            control: "seg", type: "string", backend: "flags", key: "material", def: "frost",
            options: [{ label: "Glass", value: "glass" }, { label: "Frost", value: "frost" }, { label: "Ink", value: "ink" }]
        },
        autoHide: {
            page: "look", group: "pill", order: 5,
            label: "Auto-hide pill", caption: "Slide away at rest, reveal on the top edge",
            control: "toggle", type: "bool", backend: "flags", key: "autoHide", def: false
        },
        autoHideDelay: {
            page: "look", group: "pill", order: 6,
            label: "Delay", caption: "Dwell on the edge to reveal, linger before retracting",
            control: "seg", type: "string", backend: "flags", key: "autoHideDelay", def: "medium",
            options: [{ label: "Off", value: "off" }, { label: "Short", value: "short" }, { label: "Medium", value: "medium" }, { label: "Long", value: "long" }]
        },

        // ── Display (per-monitor card, custom UI, monitors.lua) ───────────
        displayResolution: {
            page: "display", group: "", order: 0,
            label: "Resolution", caption: "Mode of the selected monitor",
            control: "custom", type: "string", backend: "app", key: "", def: ""
        },
        displayRefresh: {
            page: "display", group: "", order: 1,
            label: "Refresh", caption: "Refresh rate of the selected mode",
            control: "custom", type: "string", backend: "app", key: "", def: ""
        },
        displayScale: {
            page: "display", group: "", order: 2,
            label: "Scale", caption: "Logical scale of the selected monitor",
            control: "custom", type: "string", backend: "app", key: "", def: ""
        },
        displayMain: {
            page: "display", group: "", order: 3,
            label: "Set as main", caption: "Move workspace 1 to this monitor",
            control: "custom", type: "string", backend: "app", key: "", def: ""
        },

        // ── Input · Pointer ───────────────────────────────────────────────
        sensitivity: {
            page: "input", group: "pointer", order: 0,
            label: "Sensitivity", caption: "Pointer speed offset",
            control: "scrub", type: "real", backend: "input", key: "sensitivity", def: 0,
            from: -1, to: 1, step: 0.1, unit: ""
        },
        accelProfile: {
            page: "input", group: "pointer", order: 1,
            label: "Acceleration", caption: "How pointer speed follows motion",
            control: "seg", type: "string", backend: "input", key: "accel_profile", def: "flat",
            options: [{ label: "Flat", value: "flat" }, { label: "Adaptive", value: "adaptive" }]
        },

        // ── Input · Keyboard ──────────────────────────────────────────────
        kbLayout: {
            page: "input", group: "keyboard", order: 0,
            label: "Layout", caption: "Click to cycle common layouts",
            control: "seg", type: "string", backend: "input", key: "kb_layout", def: "de",
            options: [{ label: "de", value: "de" }, { label: "us", value: "us" }, { label: "gb", value: "gb" },
                { label: "fr", value: "fr" }, { label: "es", value: "es" }, { label: "it", value: "it" }, { label: "tr", value: "tr" }]
        },
        repeatRate: {
            page: "input", group: "keyboard", order: 1,
            label: "Repeat rate", caption: "Key repeats per second when held",
            control: "scrub", type: "int", backend: "input", key: "repeat_rate", def: 40,
            from: 10, to: 80, step: 1, unit: "Hz"
        },
        repeatDelay: {
            page: "input", group: "keyboard", order: 2,
            label: "Repeat delay", caption: "Hold time before a key repeats",
            control: "scrub", type: "int", backend: "input", key: "repeat_delay", def: 400,
            from: 150, to: 1000, step: 25, unit: "ms"
        },
        numlock: {
            page: "input", group: "keyboard", order: 3,
            label: "Numlock", caption: "Numlock on at startup",
            control: "toggle", type: "bool", backend: "input", key: "numlock_by_default", def: false
        },

        // ── Input · Cursor (env.lua + autostart.lua, applied live) ────────
        cursorSize: {
            page: "input", group: "cursor", order: 0,
            label: "Size", caption: "Cursor size in pixels",
            control: "scrub", type: "int", backend: "input", key: "XCURSOR_SIZE", def: 24,
            from: 12, to: 96, step: 4, unit: "px"
        },
        cursorTheme: {
            page: "input", group: "cursor", order: 1,
            label: "Theme", caption: "Installed cursor themes",
            control: "custom", type: "string", backend: "input", key: "XCURSOR_THEME", def: "Bibata-Modern-Ice"
        },

        // ── Animation · Motion ────────────────────────────────────────────
        animEnabled: {
            page: "animation", group: "motion", order: 0,
            label: "Enabled", caption: "Animate windows, workspaces and fades",
            control: "toggle", type: "bool", backend: "anim", key: "enabled", def: true
        },
        motion: {
            page: "animation", group: "motion", order: 1,
            label: "Motion", caption: "Calm settles, spring overshoots, glide stretches",
            control: "seg", type: "string", backend: "flags", key: "motion", def: "calm",
            options: [{ label: "Calm", value: "calm" }, { label: "Spring", value: "spring" }, { label: "Glide", value: "glide" }]
        },
        animSpeed: {
            page: "animation", group: "motion", order: 2,
            label: "Speed", caption: "Duration in deciseconds — lower is snappier",
            control: "scrub", type: "real", backend: "anim", key: "speed", def: 3,
            from: 1, to: 10, step: 0.5, unit: ""
        },

        // ── Animation · Curve ─────────────────────────────────────────────
        animCurve: {
            page: "animation", group: "curve", order: 0,
            label: "Curve", caption: "Drag the two bezier control points",
            control: "custom", type: "string", backend: "anim", key: "pillMorph", def: "0.32,0.72,0.00,1.00"
        },
        animPreset: {
            page: "animation", group: "curve", order: 1,
            label: "Preset", caption: "Drop in a ready-made curve",
            control: "custom", type: "string", backend: "anim", key: "", def: ""
        },

        // ── Keybinds / Workspaces (bespoke editors, R4: untouched) ────────
        keybindsEditor: {
            page: "keybinds", group: "", order: 0,
            label: "Keybinds", caption: "Rebind, add, set commands",
            control: "custom", type: "string", backend: "app", key: "", def: ""
        },
        workspacesEditor: {
            page: "workspaces", group: "", order: 0,
            label: "Workspaces", caption: "Special spaces and their keys",
            control: "custom", type: "string", backend: "app", key: "", def: ""
        },

        // ── Idle / Lock ───────────────────────────────────────────────────
        idleLockMin: {
            page: "idlelock", group: "", order: 0,
            label: "Auto-lock", caption: "Lock the screen after idle",
            control: "seg", type: "int", backend: "idle", key: "idleLockMin", def: 5,
            options: [{ label: "Off", value: 0 }, { label: "1 min", value: 1 }, { label: "3 min", value: 3 },
                { label: "5 min", value: 5 }, { label: "10 min", value: 10 }, { label: "15 min", value: 15 }]
        },
        idleScreenOffMin: {
            page: "idlelock", group: "", order: 1,
            label: "Screen off", caption: "Blank the display after idle",
            control: "seg", type: "int", backend: "idle", key: "idleScreenOffMin", def: 10,
            options: [{ label: "Off", value: 0 }, { label: "3 min", value: 3 }, { label: "5 min", value: 5 },
                { label: "10 min", value: 10 }, { label: "15 min", value: 15 }]
        },
        idleSuspendMin: {
            page: "idlelock", group: "", order: 2,
            label: "Suspend", caption: "Sleep the machine after idle",
            control: "seg", type: "int", backend: "idle", key: "idleSuspendMin", def: 0,
            options: [{ label: "Off", value: 0 }, { label: "15 min", value: 15 },
                { label: "30 min", value: 30 }, { label: "60 min", value: 60 }]
        },

        // ── Mixer quick toggles (outside the settings section) ────────────
        dnd: {
            page: "mixer", group: "", order: 0,
            label: "Do not disturb", caption: "Silence notifications",
            control: "toggle", type: "bool", backend: "flags", key: "dnd", def: false
        },
        keepAwake: {
            page: "mixer", group: "", order: 1,
            label: "Keep awake", caption: "Block sleep & screen-off",
            control: "toggle", type: "bool", backend: "flags", key: "keepAwake", def: false
        },
        /**
         * The one deliberate alias in the table: this chip drives the same
         * stored key as `nightLightMode` (Look → Night light) but as a bool,
         * flipping the mode between "on" and "off". `aliasOf` records that the
         * other entry owns the key, which is what exempts the pair from the
         * (backend, key) type guard — and marks it for Task 8's duplicate pass.
         */
        nightLightQuick: {
            page: "mixer", group: "", order: 2,
            label: "Night light", caption: "Warm the screen",
            control: "toggle", type: "bool", backend: "night", key: "nightLightMode", def: false,
            aliasOf: "nightLightMode"
        },
        gameMode: {
            page: "mixer", group: "", order: 3,
            label: "Game mode", caption: "Strip effects, quiet the desktop",
            control: "toggle", type: "bool", backend: "flags", key: "gameMode", def: false
        },
        /**
         * Screen vibrance: a mixer fader, not a flags key. Devices owns it and
         * persists the percent to its own state file (pillos/nvibrant-value),
         * pushing each set to nvibrant, so it routes to Devices.vibrance rather
         * than to any of the file backends the pinned enum names.
         */
        vibrance: {
            page: "mixer", group: "", order: 4,
            label: "Vibrance", caption: "Screen colour saturation",
            control: "custom", type: "int", backend: "app", key: "vibrance", def: 40,
            from: 0, to: 100, step: 1, unit: "%"
        },

        // ── Recorder drawer + audio + save location ───────────────────────
        recordFps: {
            page: "recorder", group: "options", order: 0,
            label: "Frame rate", caption: "",
            control: "seg", type: "int", backend: "rec", key: "fps", def: 60,
            options: [{ label: "30", value: 30 }, { label: "60", value: 60 }, { label: "120", value: 120 }, { label: "144", value: 144 }]
        },
        recordQuality: {
            page: "recorder", group: "options", order: 1,
            label: "Quality", caption: "",
            control: "seg", type: "string", backend: "rec", key: "quality", def: "high",
            options: [{ label: "Med", value: "medium" }, { label: "High", value: "high" },
                { label: "Ultra", value: "ultra" }, { label: "Lossless", value: "lossless" }]
        },
        recordCursor: {
            page: "recorder", group: "options", order: 2,
            label: "Capture cursor", caption: "",
            control: "toggle", type: "bool", backend: "rec", key: "captureCursor", def: true
        },
        recordCountdown: {
            page: "recorder", group: "options", order: 3,
            label: "Countdown", caption: "",
            control: "seg", type: "int", backend: "flags", key: "recordCountdown", def: 5,
            options: [{ label: "Off", value: 0 }, { label: "3s", value: 3 }, { label: "5s", value: 5 }, { label: "10s", value: 10 }]
        },
        recordMic: {
            page: "recorder", group: "audio", order: 0,
            label: "Microphone", caption: "",
            control: "toggle", type: "bool", backend: "rec", key: "micOn", def: true
        },
        recordDesktop: {
            page: "recorder", group: "audio", order: 1,
            label: "Desktop", caption: "",
            control: "toggle", type: "bool", backend: "rec", key: "desktopOn", def: true
        },
        /** ScreenRec.outDir is readonly and derives from this; the folder picker writes Flags. */
        recordDir: {
            page: "recorder", group: "", order: 0,
            label: "Save to", caption: "Empty falls back to ~/Videos/Recordings",
            control: "custom", type: "string", backend: "flags", key: "recordDir", def: ""
        },

        // ── Wallpaper folder ──────────────────────────────────────────────
        wallpaperDir: {
            page: "wallpaper", group: "", order: 0,
            label: "Wallpaper folder", caption: "Empty autodetects the last resolved folder",
            control: "custom", type: "string", backend: "flags", key: "wallpaperDir", def: ""
        },

        // ── Calendar weather town ─────────────────────────────────────────
        weatherCity: {
            page: "calendar", group: "", order: 0,
            label: "Weather town", caption: "Empty falls back to IP geolocation",
            control: "custom", type: "string", backend: "flags", key: "weatherCity", def: ""
        }
    })

    readonly property var _controls: ["seg", "toggle", "scrub", "nav", "custom"]
    readonly property var _types: ["bool", "int", "real", "string"]
    readonly property var _backends: ["flags", "deco", "input", "anim", "idle", "night", "rec", "app"]

    /**
     * Hidden consistency check: every entry must carry the pinned fields with
     * legal enum values, a `def` of the declared type, scrub bounds that
     * contain their default, and seg options that contain it. It also holds the
     * table to its own maps: a `page` must be a real settings page or a
     * declared outside page, a non-empty `group` must appear in that page's
     * `groupOrder`, no two rows may claim one page/group/order slot, and two
     * entries may only share a (backend, key) pair with different types when
     * one declares itself an `aliasOf` the other. Anything it prints is a
     * Schema bug, not a user-visible one.
     */
    function check() {
        var ids = Object.keys(root.settings);
        var slots = {};
        var owners = {};
        var bad = 0;

        var pageIds = root.pages.map(function (p) { return p.id; }).concat(root.outsidePages);

        function warn(id, msg) {
            bad += 1;
            console.warn("Schema: " + id + " — " + msg);
        }

        for (var i = 0; i < ids.length; i++) {
            var id = ids[i];
            var e = root.settings[id];

            if (typeof e.page !== "string" || e.page.length === 0)
                warn(id, "missing page");
            else if (pageIds.indexOf(e.page) === -1)
                warn(id, "page '" + e.page + "' is in neither pages nor outsidePages");
            if (typeof e.group !== "string") {
                warn(id, "missing group");
            } else if (e.group.length > 0) {
                var groups = root.groupOrder[e.page];
                if (groups === undefined)
                    warn(id, "page '" + e.page + "' has no groupOrder but the entry is grouped");
                else if (groups.indexOf(e.group) === -1)
                    warn(id, "group '" + e.group + "' missing from groupOrder['" + e.page + "']");
            }
            if (typeof e.order !== "number")
                warn(id, "missing order");
            if (typeof e.label !== "string" || e.label.length === 0)
                warn(id, "missing label");
            if (typeof e.caption !== "string")
                warn(id, "missing caption");
            if (root._controls.indexOf(e.control) === -1)
                warn(id, "bad control: " + e.control);
            if (root._types.indexOf(e.type) === -1)
                warn(id, "bad type: " + e.type);
            if (root._backends.indexOf(e.backend) === -1)
                warn(id, "bad backend: " + e.backend);
            if (typeof e.key !== "string")
                warn(id, "missing key");
            else if (e.key.length === 0 && e.control !== "custom")
                warn(id, "empty key on a stored control");
            if (e.def === undefined)
                warn(id, "missing def");

            if (e.def !== undefined) {
                if (e.type === "bool" && typeof e.def !== "boolean")
                    warn(id, "def is not a bool");
                if ((e.type === "int" || e.type === "real") && typeof e.def !== "number")
                    warn(id, "def is not a number");
                if (e.type === "int" && typeof e.def === "number" && Math.round(e.def) !== e.def)
                    warn(id, "def is not a whole number");
                if (e.type === "string" && typeof e.def !== "string")
                    warn(id, "def is not a string");
            }

            if (e.control === "scrub" || e.from !== undefined) {
                if (typeof e.from !== "number" || typeof e.to !== "number" || typeof e.step !== "number")
                    warn(id, "scrub missing from/to/step");
                else {
                    if (e.step <= 0)
                        warn(id, "step must be positive");
                    if (e.from >= e.to)
                        warn(id, "from must be below to");
                    if (typeof e.def === "number" && (e.def < e.from || e.def > e.to))
                        warn(id, "def " + e.def + " outside " + e.from + ".." + e.to);
                }
                if (typeof e.unit !== "string")
                    warn(id, "scrub missing unit");
            }

            if (e.control === "seg") {
                if (!Array.isArray(e.options) || e.options.length === 0) {
                    warn(id, "seg missing options");
                } else {
                    var hit = false;
                    for (var j = 0; j < e.options.length; j++) {
                        var o = e.options[j];
                        if (typeof o.label !== "string" || o.label.length === 0 || o.value === undefined)
                            warn(id, "option " + j + " missing label/value");
                        if (o.value === e.def)
                            hit = true;
                    }
                    if (!hit)
                        warn(id, "def " + e.def + " is not one of the options");
                }
            }

            var slot = e.page + "/" + e.group + "/" + e.order;
            if (slots[slot] !== undefined)
                warn(id, "shares slot " + slot + " with " + slots[slot]);
            else
                slots[slot] = id;

            if (e.aliasOf !== undefined && root.settings[e.aliasOf] === undefined)
                warn(id, "aliasOf points at unknown id " + e.aliasOf);

            if (typeof e.key === "string" && e.key.length > 0) {
                var pair = e.backend + "/" + e.key;
                var owner = owners[pair];
                if (owner === undefined) {
                    owners[pair] = id;
                } else if (root.settings[owner].type !== e.type
                    && e.aliasOf !== owner && root.settings[owner].aliasOf !== id) {
                    warn(id, "shares " + pair + " with " + owner
                        + " at a different type (" + e.type + " vs " + root.settings[owner].type
                        + ") and declares no aliasOf");
                }
            }
        }

        for (var p = 0; p < root.pages.length; p++) {
            var pg = root.pages[p];
            if (typeof pg.id !== "string" || pg.id.length === 0 || typeof pg.title !== "string"
                || typeof pg.caption !== "string" || typeof pg.icon !== "string")
                warn("pages[" + p + "]", "malformed page entry");
        }

        var gpages = Object.keys(root.groupOrder);
        for (var g = 0; g < gpages.length; g++) {
            if (pageIds.indexOf(gpages[g]) === -1)
                warn("groupOrder['" + gpages[g] + "']", "not a known page");
            else if (!Array.isArray(root.groupOrder[gpages[g]]) || root.groupOrder[gpages[g]].length === 0)
                warn("groupOrder['" + gpages[g] + "']", "must be a non-empty array of group ids");
        }

        return bad;
    }

    Component.onCompleted: check()
}
