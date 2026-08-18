pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/setDeco.js" as SetDeco
import "../lib/setInput.js" as SetInput
import "../lib/setAnim.js" as SetAnim

/**
 * STORE: the one validated read/write path for every setting Schema describes.
 * A page never touches a backend again — it calls `Store.get(id)` for the
 * current value and `Store.set(id, value)` to change it, and Store decides where
 * that value actually lives, coerces and range-checks it on the way in, and
 * surfaces a failure as `writeFailed(id, message)` instead of swallowing it the
 * way each page's `if (!res.ok) return;` used to (audit P0-3).
 *
 * Routing is entirely Schema-driven, by `backend` then `key`:
 *
 *   flags  — a plain `Flags.<key>` assignment (the JSON state file).
 *   idle   — the three hypridle timeouts: writes the Flags key, then regenerates
 *            the whole hypridle.conf and restarts the service. `buildIdleConf`
 *            lives here rather than on the page because a singleton cannot call
 *            into a transient surface, and the surface is about to stop owning
 *            the write.
 *   deco   — decoration.lua. A dotted key (`blur.size`, `shadow.range`) is
 *            scoped to that Lua block so a name shared by sibling blocks
 *            (`enabled`) lands in the right one. The two opacity fields also get
 *            the `hl.config` push that makes already-open windows recompute.
 *   input  — input.lua for lower-case keys; an UPPER_CASE key is an env.lua
 *            variable, which for the cursor also rewrites autostart.lua's
 *            `setcursor` line and pushes the pair live over hyprctl.
 *   anim   — animations.lua: `enabled` flips the master flag, `speed` retimes
 *            every leaf, and the curve key rewrites one named bezier's points
 *            (carried as an "x1,y1,x2,y2" string).
 *   night  — the NightLight singleton's setters, so the conf debounce and the
 *            live hyprsunset push stay in one place. `nightLightQuick` is the
 *            one alias in Schema: a bool over the same mode key, on → "on",
 *            off → "off", exactly as the mixer chip does today.
 *   rec    — ScreenRec's wrapper properties, which mirror themselves back into
 *            Flags. The recorder settings ScreenRec does not wrap are `flags`.
 *   app    — everything owning no file of ours: ghostty's `background-opacity`
 *            (rewritten, then SIGUSR2'd so open windows pick it up) and the
 *            screen vibrance Devices persists to its own state file.
 *
 * A Schema entry with an empty `key` and `control: "custom"` is a bespoke editor
 * that owns its own file (monitors.lua, binds.lua, workspace rules, the preset
 * picker). Those are deliberately NOT routable: `set` warns and returns false.
 *
 * The three Lua texts are read once at construction and are the in-memory source
 * of truth afterwards. They are deliberately not watched: a watcher would re-read
 * the file while an atomic write of ours was still in flight and hand the next
 * write a stale base, dropping the value that was just saved. `reload()` is the
 * explicit re-read for a page that wants to resync on open.
 *
 * Transitional note: Look, Input and AnimationSurface still own their own
 * FileViews on these same three files until they migrate. Store's writers are
 * constructed but nothing calls them yet, so exactly one writer per file is live
 * at every task boundary. Two `flags` keys also still carry a side effect Look
 * owns and Store does not: `pillBlur` and `material` add or remove the pill-blur
 * `hl.layer_rule` in decoration.lua. Routing either through Store today would
 * persist the flag without the rule, so Look keeps writing them until that
 * side effect moves here with the rest of the page.
 */
Singleton {
    id: root

    /** A value landed on its backend. */
    signal wrote(string id)
    /** A write was refused or failed; `message` is user-facing. */
    signal writeFailed(string id, string message)

    readonly property string decoPath: Quickshell.env("HOME") + "/.config/hypr/modules/decoration.lua"
    readonly property string inputPath: Quickshell.env("HOME") + "/.config/hypr/modules/input.lua"
    readonly property string animPath: Quickshell.env("HOME") + "/.config/hypr/modules/animations.lua"
    readonly property string envPath: Quickshell.env("HOME") + "/.config/hypr/modules/env.lua"
    readonly property string autostartPath: Quickshell.env("HOME") + "/.config/hypr/modules/autostart.lua"
    readonly property string ghosttyPath: Quickshell.env("HOME") + "/.config/ghostty/config"
    readonly property string hypridlePath: Quickshell.env("HOME") + "/.config/hypr/hypridle.conf"
    readonly property string lockScript: Quickshell.env("HOME") + "/.config/hypr/scripts/lock.sh"

    property string _decoText: ""
    property string _inputText: ""
    property string _animText: ""
    property string _envText: ""
    property string _autostartText: ""
    property string _ghosttyText: ""

    readonly property string decoText: root._decoText
    readonly property string inputText: root._inputText
    readonly property string animText: root._animText
    readonly property string envText: root._envText

    /** The id whose write armed the pending Hyprland reload, so a failed reload can name it. */
    property string _reloadId: ""

    /** Re-reads every backing file. For a page that wants to resync on open. */
    function reload() {
        decoFile.reload();
        inputFile.reload();
        animFile.reload();
        envFile.reload();
        autostartFile.reload();
        ghosttyFile.reload();
        root._decoText = decoFile.text();
        root._inputText = inputFile.text();
        root._animText = animFile.text();
        root._envText = envFile.text();
        root._autostartText = autostartFile.text();
        root._ghosttyText = ghosttyFile.text();
    }

    // ── validation ────────────────────────────────────────────────────────

    /**
     * Coerces `v` to the entry's declared type, clamps it into `from..to` when
     * the entry carries a range, and checks membership for a segmented choice.
     * Returns `{ ok, value, msg }`; a value that cannot be coerced or is not one
     * of the offered options fails rather than being written approximately.
     */
    function _coerce(e, v) {
        var out;
        if (e.type === "bool") {
            if (typeof v !== "boolean" && v !== 0 && v !== 1 && v !== "true" && v !== "false")
                return { ok: false, value: v, msg: e.label + " needs an on/off value." };
            out = v === true || v === 1 || v === "true";
        } else if (e.type === "int" || e.type === "real") {
            var n = typeof v === "number" ? v : parseFloat(v);
            if (typeof n !== "number" || isNaN(n) || !isFinite(n))
                return { ok: false, value: v, msg: e.label + " needs a number." };
            if (typeof e.from === "number" && typeof e.to === "number")
                n = Math.max(e.from, Math.min(e.to, n));
            out = e.type === "int" ? Math.round(n) : n;
        } else {
            if (v === undefined || v === null)
                return { ok: false, value: v, msg: e.label + " needs a value." };
            out = String(v);
        }

        if (e.control === "seg" && Array.isArray(e.options)) {
            var hit = false;
            for (var i = 0; i < e.options.length; i++)
                if (e.options[i].value === out)
                    hit = true;
            if (!hit)
                return { ok: false, value: out, msg: out + " is not an option for " + e.label + "." };
        }
        return { ok: true, value: out, msg: "" };
    }

    /** Formats a coerced value as the Lua literal its backend expects. */
    function _lit(e, v) {
        if (e.type === "string")
            return "\"" + v + "\"";
        if (e.type === "bool")
            return v ? "true" : "false";
        if (e.type === "int")
            return String(v);
        // decoration.lua's reals are all written to two places, matching the
        // values already on disk; the others carry their own natural precision.
        return e.backend === "deco" ? v.toFixed(2) : String(Math.round(v * 1e6) / 1e6);
    }

    function _fail(id, message) {
        root.writeFailed(id, message);
        return false;
    }

    // ── reads ─────────────────────────────────────────────────────────────

    /** Parses a raw Lua/config string into the entry's declared type. */
    function _parse(e, raw) {
        if (raw === undefined || raw === null || raw === "")
            return e.def;
        if (e.type === "bool")
            return raw === "true" || raw === true;
        if (e.type === "int") {
            var i = parseInt(raw, 10);
            return isNaN(i) ? e.def : i;
        }
        if (e.type === "real") {
            var f = parseFloat(raw);
            return isNaN(f) ? e.def : f;
        }
        return String(raw);
    }

    /**
     * The current value of `id`, read from wherever it actually lives. Falls
     * back to the Schema default when the field is missing from its file, so a
     * hand-trimmed config never leaves a control blank. Unknown or unroutable
     * ids return `undefined` and the Schema default respectively.
     */
    function get(id) {
        var e = Schema.settings[id];
        if (e === undefined)
            return undefined;
        if (e.key.length === 0)
            return e.def;

        switch (e.backend) {
        case "flags":
        case "idle":
            return Flags[e.key];
        case "night":
            if (id === "nightLightQuick")
                return Flags.nightLightMode !== "off";
            return Flags[e.key];
        case "rec":
            return ScreenRec[e.key];
        case "deco":
            var dot = e.key.indexOf(".");
            return dot < 0
                ? root._parse(e, SetDeco.getField(root._decoText, e.key))
                : root._parse(e, SetDeco.getBlockField(root._decoText, e.key.slice(0, dot), e.key.slice(dot + 1)));
        case "input":
            return root._isEnvKey(e.key)
                ? root._parse(e, SetInput.getField(root._envText, e.key))
                : root._parse(e, SetInput.getField(root._inputText, e.key));
        case "anim":
            if (e.key === "enabled")
                return SetAnim.getEnabled(root._animText) === "true";
            if (e.key === "speed")
                return root._parse(e, SetAnim.getLeafSpeed(root._animText, "global"));
            var pts = SetAnim.getCurvePoints(root._animText, e.key);
            return pts === null ? e.def : pts.map(function (p) { return p.toFixed(2); }).join(",");
        case "app":
            if (e.key === "vibrance")
                return Devices.vibrance;
            if (e.key === "background-opacity") {
                var m = root._ghosttyText.match(/^\s*background-opacity\s*=\s*([0-9.]+)/m);
                return m ? parseFloat(m[1]) : e.def;
            }
            return e.def;
        }
        return e.def;
    }

    /** An UPPER_CASE `input` key is an env.lua variable, not an input.lua field. */
    function _isEnvKey(key) {
        return /^[A-Z0-9_]+$/.test(key);
    }

    // ── writes ────────────────────────────────────────────────────────────

    /**
     * Validates `value` against the Schema entry for `id` and routes it to its
     * backend. Returns true once the value has landed; on any refusal or failed
     * rewrite it emits `writeFailed` and returns false without touching a file.
     */
    function set(id, value) {
        var e = Schema.settings[id];
        if (e === undefined) {
            console.warn("Store: set on unknown setting '" + id + "'");
            return false;
        }
        if (e.key.length === 0 && e.control === "custom") {
            console.warn("Store: '" + id + "' is a bespoke control that owns its own backend; it is not routed through Store.");
            return false;
        }

        var c = root._coerce(e, value);
        if (!c.ok)
            return root._fail(id, c.msg);
        var v = c.value;

        switch (e.backend) {
        case "flags":
            Flags[e.key] = v;
            break;
        case "idle":
            Flags[e.key] = v;
            idleWriter.setText(root.buildIdleConf());
            hypridleRestart.running = true;
            break;
        case "night":
            if (!root._setNight(id, e, v))
                return root._fail(id, "Couldn't apply " + e.label + ".");
            break;
        case "rec":
            ScreenRec[e.key] = v;
            break;
        case "deco":
            if (!root._setDeco(id, e, v))
                return root._fail(id, "Couldn't save " + e.label + " — the field is missing from decoration.lua.");
            break;
        case "input":
            if (!root._setInput(id, e, v))
                return root._fail(id, "Couldn't save " + e.label + " — the field is missing from the input config.");
            break;
        case "anim":
            if (!root._setAnim(id, e, v))
                return root._fail(id, "Couldn't save " + e.label + " — the field is missing from animations.lua.");
            break;
        case "app":
            if (!root._setApp(id, e, v))
                return root._fail(id, "Couldn't apply " + e.label + ".");
            break;
        default:
            return root._fail(id, "No backend for " + e.label + ".");
        }

        root.wrote(id);
        return true;
    }

    /**
     * The full hypridle.conf for the current three Flags values. The general
     * block is always present; a listener is appended only for each non-zero
     * timeout, in the order lock, screen-off, suspend, with minutes written out
     * as seconds. Byte-for-byte the generator the Idle/Lock page used to carry,
     * so regenerating with unchanged values reproduces the file exactly.
     */
    function buildIdleConf() {
        var out = "general {\n"
            + "    lock_cmd = " + root.lockScript + "\n"
            + "    before_sleep_cmd = loginctl lock-session\n"
            + "    after_sleep_cmd = hyprctl dispatch dpms on\n"
            + "}\n";

        if (Flags.idleLockMin > 0)
            out += "\nlistener {\n"
                + "    timeout = " + (Flags.idleLockMin * 60) + "\n"
                + "    on-timeout = " + root.lockScript + "\n"
                + "}\n";

        if (Flags.idleScreenOffMin > 0)
            out += "\nlistener {\n"
                + "    timeout = " + (Flags.idleScreenOffMin * 60) + "\n"
                + "    on-timeout = hyprctl dispatch dpms off\n"
                + "    on-resume = hyprctl dispatch dpms on\n"
                + "}\n";

        if (Flags.idleSuspendMin > 0)
            out += "\nlistener {\n"
                + "    timeout = " + (Flags.idleSuspendMin * 60) + "\n"
                + "    on-timeout = systemctl suspend\n"
                + "}\n";

        return out;
    }

    /**
     * Night light goes through NightLight's own setters so the debounced conf
     * write and the live hyprsunset push stay in one place. The quick chip is a
     * bool over the same mode key: on picks "on", off picks "off", which is the
     * mixer's behaviour today, kept identical here until Task 8 respecifies it.
     */
    function _setNight(id, e, v) {
        if (id === "nightLightQuick") {
            NightLight.setMode(v ? "on" : "off");
            return true;
        }
        if (e.key === "nightLightMode")
            NightLight.setMode(v);
        else if (e.key === "nightLightTemp")
            NightLight.setTemp(v);
        else if (e.key === "nightLightOnMin")
            NightLight.setOnMin(v);
        else if (e.key === "nightLightOffMin")
            NightLight.setOffMin(v);
        else
            return false;
        return true;
    }

    /**
     * Rewrites one decoration.lua field, top-level or scoped to its block, and
     * arms the debounced Hyprland reload. The two window-opacity fields also get
     * pushed through `hl.config`, which hits the REFRESH_WINDOW_STATES path so
     * windows that were not focused when the value changed do not keep a stale
     * alpha until their next focus change.
     */
    function _setDeco(id, e, v) {
        var lit = root._lit(e, v);
        var dot = e.key.indexOf(".");
        var res = dot < 0
            ? SetDeco.setField(root._decoText, e.key, lit)
            : SetDeco.setBlockField(root._decoText, e.key.slice(0, dot), e.key.slice(dot + 1), lit);
        if (!res.ok)
            return false;
        root._decoText = res.text;
        decoWriter.setText(res.text);
        root._reloadId = id;
        reloadTimer.restart();

        if (e.key === "active_opacity" || e.key === "inactive_opacity") {
            var ao = parseFloat(SetDeco.getField(root._decoText, "active_opacity"));
            var io = parseFloat(SetDeco.getField(root._decoText, "inactive_opacity"));
            opacityRefresh.command = ["hyprctl", "eval",
                "hl.config({ decoration = { active_opacity = " + (isNaN(ao) ? 1 : ao).toFixed(2)
                + ", inactive_opacity = " + (isNaN(io) ? 1 : io).toFixed(2) + " } })"];
            opacityRefresh.running = true;
        }
        return true;
    }

    /**
     * Lower-case keys are input.lua fields and want a Hyprland reload.
     * UPPER_CASE keys are env.lua variables; the two cursor ones additionally
     * rewrite autostart.lua's `setcursor` call and push the theme/size pair live
     * over hyprctl, which needs no reload.
     */
    function _setInput(id, e, v) {
        if (!root._isEnvKey(e.key)) {
            var res = SetInput.setField(root._inputText, e.key, root._lit(e, v));
            if (!res.ok)
                return false;
            root._inputText = res.text;
            inputWriter.setText(res.text);
            root._reloadId = id;
            reloadTimer.restart();
            return true;
        }

        if (e.key === "XCURSOR_THEME" || e.key === "XCURSOR_SIZE") {
            var theme = e.key === "XCURSOR_THEME" ? String(v) : SetInput.getField(root._envText, "XCURSOR_THEME");
            var size = e.key === "XCURSOR_SIZE" ? v : parseInt(SetInput.getField(root._envText, "XCURSOR_SIZE"), 10);
            if (theme.length === 0)
                theme = Schema.settings.cursorTheme.def;
            if (isNaN(size))
                size = Schema.settings.cursorSize.def;
            return root._applyCursor(theme, size);
        }

        var er = SetInput.setEnv(root._envText, e.key, String(v));
        if (!er.ok)
            return false;
        root._envText = er.text;
        envWriter.setText(er.text);
        return true;
    }

    /**
     * Applies a cursor theme/size pair live, then persists it by rewriting the
     * XCURSOR/HYPRCURSOR env lines and the autostart setcursor call. Each rewrite
     * is independent, so a config missing one of the three lines still lands the
     * others.
     */
    function _applyCursor(theme, size) {
        setcursorProc.command = ["hyprctl", "setcursor", theme, String(size)];
        setcursorProc.running = true;

        var env = root._envText;
        var e1 = SetInput.setEnv(env, "XCURSOR_THEME", theme);
        var e2 = SetInput.setEnv(e1.ok ? e1.text : env, "XCURSOR_SIZE", String(size));
        var e3 = SetInput.setEnv(e2.ok ? e2.text : (e1.ok ? e1.text : env), "HYPRCURSOR_SIZE", String(size));
        var any = e1.ok || e2.ok || e3.ok;
        if (any) {
            root._envText = e3.ok ? e3.text : (e2.ok ? e2.text : e1.text);
            envWriter.setText(root._envText);
        }

        var auto = SetInput.setCursorLine(root._autostartText, theme, String(size));
        if (auto.ok) {
            root._autostartText = auto.text;
            autostartWriter.setText(auto.text);
        }
        return any || auto.ok;
    }

    /**
     * animations.lua is a list of calls, not a config table, so each key has its
     * own rewrite: the master flag, a blanket retime of every leaf's speed, or
     * one named bezier's two control points carried as "x1,y1,x2,y2".
     */
    function _setAnim(id, e, v) {
        var res;
        if (e.key === "enabled") {
            res = SetAnim.setEnabled(root._animText, v ? "true" : "false");
        } else if (e.key === "speed") {
            res = SetAnim.setAllSpeeds(root._animText, String(Math.round(v * 1e6) / 1e6));
        } else {
            var p = String(v).split(",").map(function (x) { return parseFloat(x); });
            if (p.length !== 4 || p.some(function (x) { return isNaN(x); }))
                return false;
            res = SetAnim.setCurvePoints(root._animText, e.key,
                p[0].toFixed(2), p[1].toFixed(2), p[2].toFixed(2), p[3].toFixed(2));
        }
        if (!res.ok)
            return false;
        root._animText = res.text;
        animWriter.setText(res.text);
        root._reloadId = id;
        reloadTimer.restart();
        return true;
    }

    /**
     * The app backend owns what belongs to no config of ours. Ghostty's
     * background-opacity has to be an app-side knob because compositor opacity
     * fades text with the background; the SIGUSR2 poke is debounced like the
     * Hyprland reload so a scrub drag reloads open windows once, and a failed
     * pkill only means no ghostty is running and the value waits for the next
     * launch. Vibrance is Devices' own persisted state.
     */
    function _setApp(id, e, v) {
        if (e.key === "vibrance") {
            Devices.setVibrance(v);
            return true;
        }
        if (e.key === "background-opacity") {
            var line = "background-opacity = " + v.toFixed(2);
            var t = root._ghosttyText;
            if (/^\s*background-opacity\s*=.*$/m.test(t))
                t = t.replace(/^\s*background-opacity\s*=.*$/m, line);
            else
                t += (t.length > 0 && !t.endsWith("\n") ? "\n" : "") + line + "\n";
            root._ghosttyText = t;
            ghosttyWriter.setText(t);
            ghosttySignalTimer.restart();
            return true;
        }
        return false;
    }

    // ── backing files ─────────────────────────────────────────────────────

    FileView { id: decoFile; path: root.decoPath; blockLoading: true; printErrors: false }
    FileView { id: decoWriter; path: root.decoPath; atomicWrites: true; printErrors: false }
    FileView { id: inputFile; path: root.inputPath; blockLoading: true; printErrors: false }
    FileView { id: inputWriter; path: root.inputPath; atomicWrites: true; printErrors: false }
    FileView { id: animFile; path: root.animPath; blockLoading: true; printErrors: false }
    FileView { id: animWriter; path: root.animPath; atomicWrites: true; printErrors: false }
    FileView { id: envFile; path: root.envPath; blockLoading: true; printErrors: false }
    FileView { id: envWriter; path: root.envPath; atomicWrites: true; printErrors: false }
    FileView { id: autostartFile; path: root.autostartPath; blockLoading: true; printErrors: false }
    FileView { id: autostartWriter; path: root.autostartPath; atomicWrites: true; printErrors: false }
    FileView { id: ghosttyFile; path: root.ghosttyPath; blockLoading: true; printErrors: false }
    FileView { id: ghosttyWriter; path: root.ghosttyPath; atomicWrites: true; printErrors: false }
    FileView { id: idleWriter; path: root.hypridlePath; atomicWrites: true; printErrors: false }

    /**
     * The Hyprland reload is debounced so a scrub drag writes the file on every
     * step but reloads once, and captured rather than detached so a failed reload
     * reaches the user through the same error strip as a refused write.
     */
    Timer {
        id: reloadTimer
        interval: 250
        repeat: false
        onTriggered: reloadProc.running = true
    }

    Process {
        id: reloadProc
        command: ["sh", "-c", "sleep 0.3; hyprctl reload"]
        onExited: function (exitCode) {
            if (exitCode !== 0)
                root.writeFailed(root._reloadId, "Hyprland reload failed. The change is saved but not applied.");
        }
    }

    Process { id: opacityRefresh; command: [] }
    Process { id: setcursorProc; command: [] }
    Process { id: hypridleRestart; command: ["systemctl", "--user", "restart", "hypridle"] }

    Timer {
        id: ghosttySignalTimer
        interval: 250
        repeat: false
        onTriggered: ghosttyReload.running = true
    }

    Process { id: ghosttyReload; command: ["pkill", "-USR2", "-x", "ghostty"] }

    Component.onCompleted: root.reload()
}
