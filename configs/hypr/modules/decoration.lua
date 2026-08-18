local home = os.getenv("HOME")
local ok, wc = pcall(dofile, home .. "/.cache/pillos/hypr-colors.lua")
if not ok then wc = nil end

local function border(hex, fallback)
    if type(hex) ~= "string" then hex = fallback end
    return "rgb(" .. hex:gsub("#", "") .. ")"
end

local active   = border(wc and wc.active, "#ffb454")
local inactive = border(wc and wc.inactive, "#263042")

--[[
    Splash rendering SEGVs Hyprland (pango free in renderSplash) when a monitor
    gets reconfigured while the splash would draw, e.g. a display apply from the
    pill. Logo and splash off closes that crash surface.
]]
hl.config({
    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
    },
    general = {
        gaps_in     = 6,
        gaps_out    = 12,
        border_size = 0,
        layout      = "dwindle",
        resize_on_border = true,
        ["col.active_border"]   = active,
        ["col.inactive_border"] = inactive,
    },
    decoration = {
        rounding         = 13,
        rounding_power   = 2,
        active_opacity   = 1.00,
        inactive_opacity = 1.00,
        dim_inactive     = true,
        dim_strength     = 0.12,
        shadow = {
            enabled      = true,
            range        = 18,
            render_power = 3,
            color        = 0xcc06080f,
        },
        blur = {
            enabled           = true,
            size              = 8,
            passes            = 3,
            vibrancy          = 0.17,
            noise             = 0.01,
            new_optimizations = true,
        },
    },
})

--[[
    Blur behind the pill, owned by the pill's Material setting rather than by
    hand. Blur for a shell layer cannot be set as a config field, only as a
    layer rule, so the presence or absence of a rule named "pill-blur" below IS
    the pill's blur state — no flag stores it. The shell adds the rule for glass
    and frost, removes it for ink, and reconciles it against the stored material
    at startup, so a hand edit here is undone: change Material instead. Shipped
    present because the default material (frost) blurs.
]]
hl.layer_rule({ name = "pill-blur", match = { namespace = "pill" }, blur = true, ignore_alpha = 0.2 })
