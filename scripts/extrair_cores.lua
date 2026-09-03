local img = arg[1]
local out_lua = arg[2]
local out_conf = arg[4]
local out_kitty = arg[5]
local out_qml = arg[7]

if not img or not out_lua or not out_conf or not out_kitty then
	print("Uso: lua extrair_cores.lua <img_path> <out_lua> <out_conf> <out_kitty> [out_qml]")
	os.exit(1)
end

-- Usa o ImageMagick para encolher a imagem e extrair a paleta sem crashar
local cmd = string.format(
	"magick '%s' -resize 50x50 -colors 6 -unique-colors -format '%%c' histogram:info: | grep -Eo '#[0-9A-Fa-f]{6}'",
	img
)
local f = io.popen(cmd)
local saida = f:read("*a")
f:close()

-- Salva as cores encontradas
local cores = {}
for hex in string.gmatch(saida, "#([0-9a-fA-F]+)") do
	table.insert(cores, hex)
end

-- Fallbacks caso a imagem seja muito escura ou tenha poucas cores
local bg = cores[1] or "020508"
local c_red = cores[2] or "a73e47"
local c_yellow = cores[3] or "c6bc53"
local c_green = cores[4] or "53c666"
local c_blue = cores[5] or "4255af"
local accent = cores[6] or "353236"

-- Função para clarear a cor
local function clarear(hex, factor)
	local r = tonumber(hex:sub(1, 2), 16) or 0
	local g = tonumber(hex:sub(3, 4), 16) or 0
	local b = tonumber(hex:sub(5, 6), 16) or 0

	r = math.min(255, math.floor(r + (255 - r) * factor))
	g = math.min(255, math.floor(g + (255 - g) * factor))
	b = math.min(255, math.floor(b + (255 - b) * factor))

	return string.format("%02x%02x%02x", r, g, b)
end

-- Gera os tons derivados
local surface = clarear(bg, 0.15)
local muted = clarear(bg, 0.35)
local b_red = clarear(c_red, 0.3)
local b_green = clarear(c_green, 0.3)
local b_blue = clarear(c_blue, 0.3)

-- 1. Monta e salva o arquivo LUA (Hyprland)
local lua_content = string.format(
	[[
return {
    bg       = "%s",
    fg       = "e2dacf",
    accent1  = "%s",
    accent2  = "%s",
    accent3  = "%s",
    inactive = "%s",
}
]],
	bg,
	c_red,
	c_blue,
	accent,
	muted
)

local f_lua = io.open(out_lua, "w")
f_lua:write(lua_content)
f_lua:close()

-- 3. Monta e salva o arquivo CONF (Hyprlock / Hyprland)
local conf_content = string.format(
	[[
# Gerado automaticamente para hyprlock
$bg       = rgb(%s)
$surface  = rgb(%s)
$fg       = rgb(cfdae2)
$muted    = rgb(%s)

$accent   = rgb(%s)
$red      = rgb(%s)
$yellow   = rgb(%s)
$green    = rgb(%s)
$blue     = rgb(%s)

# cores de texto/UI
$time_hour   = rgb(%s)
$time_minute = rgb(%s)
$date_color  = rgb(cfdae2)
$user_color  = rgb(cfdae2)
$outer_color = rgb(%s)
$inner_color = rgb(%s)
$font_color  = rgb(cfdae2)
$song_color  = rgb(%s)
]],
	bg,
	surface,
	muted,
	accent,
	c_red,
	c_yellow,
	c_green,
	c_blue,
	accent,
	c_blue,
	accent,
	surface,
	accent
)

local f_conf = io.open(out_conf, "w")
f_conf:write(conf_content)
f_conf:close()

-- 4. Monta e salva o arquivo CONF (Kitty)
local kitty_content = string.format(
	[[
# Gerado automaticamente para o Kitty
background #%s
foreground #cfdae2
selection_background #%s
selection_foreground #cfdae2

color0  #%s
color1  #%s
color2  #%s
color3  #%s
color4  #%s
color5  #%s
color6  #%s
color7  #cfdae2

color8  #%s
color9  #%s
color10 #%s
color11 #%s
color12 #%s
color13 #%s
color14 #%s
color15 #ffffff
]],
	bg,
	surface,
	bg,
	c_red,
	c_green,
	c_yellow,
	c_blue,
	accent,
	c_blue,
	muted,
	b_red,
	b_green,
	c_yellow,
	b_blue,
	accent,
	b_blue
)

local f_kitty = io.open(out_kitty, "w")
f_kitty:write(kitty_content)
f_kitty:close()


-- 6. Monta e salva o Colors.qml (quickshell)
if out_qml then
	local qml_content = string.format(
		[[
pragma Singleton
import QtQuick

QtObject {
    readonly property color bg: "#%s"
    readonly property color surface: "#%s"
    readonly property color fg: "#cfdae2"
    readonly property color muted: "#%s"

    readonly property color accent: "#%s"
    readonly property color red: "#%s"
    readonly property color yellow: "#%s"
    readonly property color green: "#%s"
    readonly property color blue: "#%s"

    readonly property color brightRed: "#%s"
    readonly property color brightGreen: "#%s"
    readonly property color brightBlue: "#%s"
}
]],
		bg,
		surface,
		muted,
		accent,
		c_red,
		c_yellow,
		c_green,
		c_blue,
		b_red,
		b_green,
		b_blue
	)

	local f_qml = io.open(out_qml, "w")
	f_qml:write(qml_content)
	f_qml:close()
end

print("Cores extraídas no pique via Lua!")
