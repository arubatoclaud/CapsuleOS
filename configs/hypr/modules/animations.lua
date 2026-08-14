hl.config({
    animations = {
        enabled = true,
    },
})

--[[
    pillMorph mirrors the pill's calm character, cubic-bezier(0.32, 0.72, 0, 1)
    at speed 3.0, so windows, layers and workspaces speak the same motion
    language as the shell instead of a faster quint pop. The Animation surface's
    Motion row rewrites both the points and every speed when the character
    changes.
]]
hl.curve("pillMorph",      { type = "bezier", points = { { 0.32, 0.72 },    { 0.00, 1.00 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1 } } })

hl.animation({ leaf = "global",     enabled = true, speed = 3.0,   bezier = "pillMorph" })
hl.animation({ leaf = "windows",    enabled = true, speed = 3.0,   bezier = "pillMorph" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 3.0,   bezier = "pillMorph", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3.0, bezier = "pillMorph", style = "popin 92%" })
hl.animation({ leaf = "border",     enabled = true, speed = 3.0,   bezier = "quick" })
hl.animation({ leaf = "fade",       enabled = true, speed = 3.0, bezier = "almostLinear" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 3.0, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 3.0, bezier = "almostLinear" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.0, bezier = "pillMorph", style = "popin 90%" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 3.0, bezier = "pillMorph" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 3.0, bezier = "pillMorph" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.0, bezier = "pillMorph", style = "slide" })
