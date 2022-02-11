﻿DefaultCreateFont = DefaultCreateFont or surface.CreateFont
DefaultSetFont = DefaultSetFont or surface.SetFont
DefaultGetTextSize = DefaultGetTextSize or surface.GetTextSize
local currentfont = "Default"

function surface.SetFont(font)
    -- if currentfont ~= font then
        currentfont = font
        DefaultSetFont(font)
    -- end
end

function surface.GetTextSize(text)
    return GetTextSize(currentfont, text)
end

local spam = {
    extended = false,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = false,
}

local textsizecache = defaultdict(function() return {} end)
local textsizecachecount = 0

function surface.CreateFont(name, settings)
    for k, v in pairs(settings) do
        if spam[k] == v then
            print("Unnecessary font setting", name, k, v)
        end
    end

    textsizecachecount = textsizecachecount - table.Count(textsizecache[name])
    textsizecache[name] = {}

    return DefaultCreateFont(name, settings)
end

--- surface.GetTextSize with cached result
function GetTextSize(font, text)
    if not text then
        local w, h = GetTextSize(font, "")

        return h
    end

    local c = textsizecache[font]

    if not c[text] then
        if textsizecachecount > 1000 then
            -- todo make it make max larger if it clears twice within 10 sec or whatever
            print("CLEAR TEXT SIZE CACHE")
            textsizecachecount = 0
            textsizecache = defaultdict(function() return {} end)
        end

        surface.SetFont(font)

        c[text] = {DefaultGetTextSize(text)}

        textsizecachecount = textsizecachecount + 1
    end

    return unpack(c[text])
end

function GetTextWidth(font, text)
    local w,h = GetTextSize(font, text)
    return w
end


function GetTextHeight(font)
    local w,h = GetTextSize(font, "")
    return h
end

-- TODO add bold and the other shit. parse kvs?
local function parse_settings(setting_str)
    local stuff = ("_"):Explode(setting_str)

    local settings = {
        font = stuff[1]
    }

    local szstart = settings.font:find("%d")

    if szstart then
        settings.size = tonumber(settings.font:sub(szstart))
        settings.font = settings.font:sub(1, szstart - 1)
    end

    local i = 2
    settings.weight = tonumber(stuff[2])

    if settings.weight then
        i = 3
    end

    while stuff[i] do
        settings[stuff[i]] = true
        i = i + 1
    end

    return settings
end

local function pack_settings(settings)
    local setting_str = (settings.font or "Arial") .. (settings.size or "13")

    if settings.weight then
        setting_str = setting_str .. "_" .. settings.weight
    end

    for k, v in pairs(settings) do
        if v == true then
            setting_str = setting_str .. ("_" .. k)
        elseif k ~= "font" and k ~= "size" and k ~= "weight" then
            error()
        end
    end

    return setting_str
end

local fontsmade = {}

--- Generates a font quickly. Caches so it can be used in paint hooks.
-- Example input: draw.DrawText("based", Font.Arial24)
Font = defaultdict(function(setting_str)
    surface.CreateFont(setting_str, parse_settings(setting_str))

    return setting_str
end)

-- todo clear cache
local ffc = defaultdict(function() return defaultdict(function() return {} end) end)

function FitFont(setting_str, txt, w)
    local c = ffc[setting_str][txt][w]
    if c then return c end
    local in_setting_str = setting_str
    local settings = parse_settings(setting_str)

    if not settings.size then
        settings.size = 4

        while ({GetTextSize(Font[pack_settings(settings)], txt)})[1] <= w do
            settings.size = settings.size * 2
        end

        settings.size = settings.size - 1
    end

    local min, max = 4, settings.size + 1
    local mid2

    while min < max - 1 do
        local mid = math.floor((min + max) / 2)
        assert(mid ~= mid2)
        mid2 = mid
        settings.size = mid

        if ({GetTextSize(Font[pack_settings(settings)], txt)})[1] <= w then
            min = mid
        else
            max = mid
        end
    end

    settings.size = min
    local c = Font[pack_settings(settings)]
    ffc[in_setting_str][txt][w] = c

    return c
end

local function tryfont()
    surface.CreateFont('HintControls', {
        font = 'Lato',
        size = sz,
    })

    surface.SetFont('HintControls')
    local w, h = surface.GetTextSize(teststr)

    return w >= scrw
end