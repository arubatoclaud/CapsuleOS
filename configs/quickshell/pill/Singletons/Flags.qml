pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Shared session flags persisted to a small JSON file and watched for external
 * change, so every CapsuleOS daemon (pill, lock) reads and writes the same
 * Do-Not-Disturb and Keep-Awake state live without a second notification server
 * or idle inhibitor. Toggling in one surface updates the others on the next file
 * event, and the state survives a daemon restart.
 */
Singleton {
    id: root

    property alias dnd: adapter.dnd
    property alias keepAwake: adapter.keepAwake
    property alias time12h: adapter.time12h
    property alias clockSeconds: adapter.clockSeconds
    /** The decorative Japanese-glyph layer is retired; constant false keeps every gated fallback active. */
    readonly property bool showGlyphs: false
    property alias paletteMode: adapter.paletteMode
    property alias material: adapter.material
    property alias motion: adapter.motion
    property alias wallpaperDir: adapter.wallpaperDir
    property alias randomScope: adapter.randomScope
    property alias uiScale: adapter.uiScale
    property alias reduceMotion: adapter.reduceMotion
    property alias manualHue: adapter.manualHue
    property alias manualSat: adapter.manualSat
    property alias uiFont: adapter.uiFont
    /**
     * TWO KEYS ARE DELIBERATELY ABSENT, both for the same reason: each was a
     * second control over a piece of state the material already decides.
     *
     * `pillBlur` — the pill's blur follows its material, its truth is
     * decoration.lua's `pill-blur` layer_rule (which Store adds and removes as
     * the material changes), and the derived value lives once as
     * `Theme.pillBlur`. The old JSON key was an independently-settable copy of
     * that state (audit P0-4).
     *
     * `pillOpacity` — the pill's alpha follows its material too, and glass
     * follows the user's window-background opacity (`Theme.glassAlpha`). The
     * flag multiplied on top of the material's alpha at the render sites, and
     * that product could fall under the `pill-blur` rule's `ignore_alpha` and
     * stop the compositor blurring with no setting anywhere admitting it.
     *
     * Neither is declared on the adapter: a stale key still sitting in an
     * existing flags.json loads without error, is ignored, and is dropped from
     * the file on the next write — no migration step needed for either.
     */
    property alias autoHide: adapter.autoHide
    property alias autoHideDelay: adapter.autoHideDelay
    property alias topGap: adapter.topGap

    /**
     * Auto-hide timing derived from autoHideDelay: how long the pointer must
     * dwell on the edge strip before the pill reveals, and how long it lingers
     * after the pointer leaves before retracting. "off" restores the original
     * instant behaviour in both directions.
     */
    readonly property var _delaySteps: ({ off: [0, 0], short: [120, 350], medium: [200, 600], long: [350, 1100] })
    readonly property int revealDwellMs: (_delaySteps[autoHideDelay] || _delaySteps.medium)[0]
    readonly property int hideLingerMs: (_delaySteps[autoHideDelay] || _delaySteps.medium)[1]
    property alias appGap: adapter.appGap
    property alias recordCountdown: adapter.recordCountdown
    property alias recordDir: adapter.recordDir
    property alias recordFps: adapter.recordFps
    property alias recordQuality: adapter.recordQuality
    property alias recordCursor: adapter.recordCursor
    property alias recordMic: adapter.recordMic
    property alias recordDesktop: adapter.recordDesktop
    property alias recordClearedBefore: adapter.recordClearedBefore
    property alias idleLockMin: adapter.idleLockMin
    property alias idleScreenOffMin: adapter.idleScreenOffMin
    property alias idleSuspendMin: adapter.idleSuspendMin
    property alias weatherCity: adapter.weatherCity
    property alias musicViz: adapter.musicViz
    property alias gameMode: adapter.gameMode
    property alias gamePrevDnd: adapter.gamePrevDnd
    property alias gamePrevViz: adapter.gamePrevViz
    property alias gamePrevAwake: adapter.gamePrevAwake
    property alias gamePrevProfile: adapter.gamePrevProfile
    property alias nightLightMode: adapter.nightLightMode
    property alias nightPrevMode: adapter.nightPrevMode
    property alias nightLightTemp: adapter.nightLightTemp
    property alias nightLightOnMin: adapter.nightLightOnMin
    property alias nightLightOffMin: adapter.nightLightOffMin

    /**
     * False until flags.json has actually been read — or written out from the
     * defaults, for a fresh install that has no file yet. The FileView's load is
     * asynchronous, so a singleton that comes up alongside this one and reads a
     * value straight away can see the ADAPTER DEFAULT rather than the user's
     * stored value. That is harmless for a binding, which re-evaluates when the
     * load lands, but not for a one-shot that writes the world to match a flag:
     * it would reconcile against a value the user never chose. Those wait for
     * this (see Store's pill-blur reconcile). A load that fails for any other
     * reason leaves it false — skipping a reconcile is always safer than running
     * one from defaults.
     */
    readonly property bool loaded: root._loaded
    property bool _loaded: false

    FileView {
        id: file
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/capsuleos/flags.json"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: root._loaded = true
        onLoadFailed: function(error) {
            // No file yet: the defaults become the stored state, and they are
            // then as authoritative as anything read off disk.
            if (error === FileViewError.FileNotFound) {
                writeAdapter();
                root._loaded = true;
            }
        }

        JsonAdapter {
            id: adapter
            property bool dnd: false
            property bool keepAwake: false
            property bool time12h: false
            property bool clockSeconds: false
            property string paletteMode: "static"
            /** Surface material: "glass" bright translucent, "frost" the shipped middle, "ink" flat opaque. Rides Theme's surface alpha so every surface follows one choice. */
            property string material: "frost"
            /** Motion character: "calm" the shipped Apple-standard settle, "spring" overshoots, "glide" stretches everything cinematic. Drives Motion's durations and curve, and the Hyprland side through the animation surface. */
            property string motion: "calm"
            /** Explicit wallpaper folder override. Empty means autodetect: the dir wallpaper.sh last resolved (capsuleos-wallpaper-dir state file), then ~/CapsuleOS/wallpapers. Lives in user state so an in-app update never clobbers a custom folder. */
            property string wallpaperDir: ""
            /** Super+B random target: "all" repaints every monitor, "cursor" only the one under the pointer. */
            property string randomScope: "all"
            property real uiScale: 1.0
            property bool reduceMotion: false
            property int manualHue: 30
            property real manualSat: 0.5
            property string uiFont: ""
            /** macOS menubar behaviour: the pill retracts off the top edge at rest and releases its reserved band, and a thin hover strip at the screen edge slides it back. */
            property bool autoHide: false
            /** Auto-hide pacing: "off" instant, else short/medium/long scale the reveal dwell and hide linger together. */
            property string autoHideDelay: "medium"
            /** Top margin as a fraction of the shipped 8px. 0 sits the pill flush to the screen edge. */
            property real topGap: 1.0
            /** Pill-to-window band as a fraction of the shipped 12px. 0 tucks the windows flush under the pill. */
            property real appGap: 1.0
            property int recordCountdown: 5
            property string recordDir: ""
            property int recordFps: 60
            property string recordQuality: "high"
            property bool recordCursor: true
            property bool recordMic: true
            property bool recordDesktop: true
            property real recordClearedBefore: 0
            property int idleLockMin: 5
            property int idleScreenOffMin: 10
            property int idleSuspendMin: 0
            property string weatherCity: ""
            property bool musicViz: true
            property bool gameMode: false
            property bool gamePrevDnd: false
            property bool gamePrevViz: true
            property bool gamePrevAwake: false
            property string gamePrevProfile: ""
            property string nightLightMode: "off"
            /** The mode the night-light quick toggle restores when it is switched back on, remembered the moment it switches off — the `gamePrev*` pattern, so flipping the chip off and on again does not silently demote "scheduled" to "on". */
            property string nightPrevMode: "on"
            property int nightLightTemp: 4000
            property int nightLightOnMin: 1260
            property int nightLightOffMin: 450
        }
    }
}
