#!/usr/bin/env lua

-- Hyprpaper Wallpaper Changer
-- Requer: lgi (LuaGI), hyprpaper

local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "3.0")
local Gdk = lgi.require("Gdk", "3.0")
local GdkPixbuf = lgi.GdkPixbuf
local GLib = lgi.GLib

-- Configurações
local WALLPAPER_DIR = os.getenv("HOME") .. "/Pictures/Wallpapers"
local HYPRPAPER_CONFIG = os.getenv("HOME") .. "/.config/hypr/hyprpaper.conf"
local HYPRLOCK_CONFIG = os.getenv("HOME") .. "/.config/hypr/hyprlock.conf"

-- Criar diretório se não existir
os.execute("mkdir -p " .. WALLPAPER_DIR)

-- ==========================================================
-- CSS - visual da aplicação
-- ==========================================================
local CSS = [[
window {
    background-color: #1a1b26;
}

/* ---------- Header ---------- */
.header-bar {
    background-color: #24273a;
    border-radius: 12px;
    padding: 10px 14px;
    border: 1px solid #363a4f;
}

.app-title {
    color: #cad3f5;
    font-weight: 800;
    font-size: 16px;
}

.app-subtitle {
    color: #6e738d;
    font-size: 11px;
}

combobox, combobox button, entry {
    background-color: #363a4f;
    color: #cad3f5;
    border-radius: 8px;
    border: 1px solid #494d64;
    padding: 4px 8px;
    min-height: 26px;
}

entry {
    padding: 6px 10px;
}

entry:focus {
    border-color: #8aadf4;
}

button {
    background-color: #363a4f;
    color: #cad3f5;
    border-radius: 8px;
    border: 1px solid #494d64;
    padding: 6px 12px;
    transition: background-color 150ms ease;
}

button:hover {
    background-color: #494d64;
}

button.suggested {
    background-color: #8aadf4;
    color: #1a1b26;
    border: none;
    font-weight: 700;
}

button.suggested:hover {
    background-color: #a6c8ff;
}

/* ---------- Grid area ---------- */
scrolledwindow {
    background-color: transparent;
}

flowboxchild {
    padding: 0;
    border-radius: 14px;
}

flowboxchild:selected {
    background-color: transparent;
}

.wallpaper-card {
    background-color: #24273a;
    border-radius: 14px;
    border: 2px solid #363a4f;
    padding: 8px;
    transition: border-color 150ms ease, background-color 150ms ease;
}

.wallpaper-card:hover {
    border-color: #6e738d;
    background-color: #2a2e42;
}

.wallpaper-card.selected {
    border-color: #8aadf4;
    background-color: #2a3350;
}

.thumb-frame {
    border-radius: 10px;
    background-color: #14151f;
}

.thumb-placeholder {
    color: #494d64;
    font-size: 34px;
}

.wallpaper-name {
    color: #cad3f5;
    font-size: 11.5px;
    font-weight: 600;
}

.wallpaper-card.selected .wallpaper-name {
    color: #8aadf4;
}

/* ---------- Status bar ---------- */
.status-bar {
    background-color: #24273a;
    border-radius: 10px;
    border: 1px solid #363a4f;
    padding: 6px 12px;
    color: #6e738d;
    font-size: 11px;
}

.status-bar .count-badge {
    color: #8aadf4;
    font-weight: 700;
}

/* ---------- Scrollbar ---------- */
scrollbar slider {
    background-color: #494d64;
    border-radius: 10px;
    min-width: 8px;
}

scrollbar slider:hover {
    background-color: #6e738d;
}
]]

local function apply_css()
	local provider = Gtk.CssProvider()
	provider:load_from_data(CSS)
	Gtk.StyleContext.add_provider_for_screen(
		Gdk.Screen.get_default(),
		provider,
		Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
	)
end

-- Função para obter lista de wallpapers
local function get_wallpapers()
	local wallpapers = {}
	local handle = io.popen(
		"find '"
			.. WALLPAPER_DIR
			.. "' -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.jxl' \\) 2>/dev/null | sort"
	)
	if handle then
		for file in handle:lines() do
			table.insert(wallpapers, file)
		end
		handle:close()
	end
	return wallpapers
end

-- Função para obter monitores
local function get_monitors()
	local monitors = {}

	-- Método mais confiável: hyprctl monitors com grep
	local handle = io.popen("hyprctl monitors 2>/dev/null | grep -E '^Monitor' | awk '{print $2}'")
	if handle then
		for monitor in handle:lines() do
			if monitor and monitor ~= "" then
				table.insert(monitors, monitor)
			end
		end
		handle:close()
	end

	-- Fallback se não encontrou nada
	if #monitors == 0 then
		table.insert(monitors, "HDMI-A-1")
		table.insert(monitors, "eDP-1")
		table.insert(monitors, "DP-1")
	end

	return monitors
end

-- Função para aplicar wallpaper
local function apply_wallpaper(image_path, monitor)
	-- Preload da imagem (CLI do hyprpaper)
	os.execute("hyprctl hyprpaper preload '" .. image_path .. "' 2>/dev/null")

	-- Definir wallpaper (CLI do hyprpaper)
	os.execute("hyprctl hyprpaper wallpaper '" .. monitor .. "," .. image_path .. "' 2>/dev/null")

	local config = io.open(HYPRPAPER_CONFIG, "w")
	if config then
		-- Mantendo o preload que geralmente é exigido pelo hyprpaper e o splash off
		config:write("splash = false\n")
		config:write("preload = " .. image_path .. "\n\n")

		-- Escrevendo o novo bloco de wallpaper
		config:write("wallpaper {\n")
		config:write("    monitor = " .. monitor .. "\n")
		config:write("    path = " .. image_path .. "\n")
		config:write("    fit_mode = cover\n")
		config:write("}\n")
		config:close()
	end

	-- ATUALIZANDO O HYPRLOCK, TWIN:
	-- O 'sed' procura a linha que começa com espaços/tabs seguidos de 'path =' e substitui
	local sed_cmd = string.format("sed -i 's|^[ \t]*path = .*|    path = %s|' '%s'", image_path, HYPRLOCK_CONFIG)
	os.execute(sed_cmd)
end

-- Criar janela principal
local function create_window()
	apply_css()

	local window = Gtk.Window({
		title = "Hyprpaper Wallpaper Changer",
		default_width = 980,
		default_height = 640,
		window_position = Gtk.WindowPosition.CENTER,
		on_destroy = Gtk.main_quit,
	})
	window:set_border_width(14)

	local main_box = Gtk.Box({
		orientation = Gtk.Orientation.VERTICAL,
		spacing = 12,
	})

	-- ===================== Header =====================
	local header_bar = Gtk.Box({
		orientation = Gtk.Orientation.HORIZONTAL,
		spacing = 14,
	})
	header_bar:get_style_context():add_class("header-bar")

	local title_box = Gtk.Box({
		orientation = Gtk.Orientation.VERTICAL,
		spacing = 0,
	})
	local title_label = Gtk.Label({ label = "🖼  Wallpapers", xalign = 0 })
	title_label:get_style_context():add_class("app-title")
	local subtitle_label = Gtk.Label({ label = WALLPAPER_DIR, xalign = 0 })
	subtitle_label:get_style_context():add_class("app-subtitle")
	title_box:pack_start(title_label, false, false, 0)
	title_box:pack_start(subtitle_label, false, false, 0)

	local search_entry = Gtk.SearchEntry({
		placeholder_text = "Buscar wallpaper...",
		hexpand = true,
	})

	local monitor_label = Gtk.Label({ label = "Monitor" })
	monitor_label:get_style_context():add_class("app-subtitle")

	local monitor_combo = Gtk.ComboBoxText()
	local monitors = get_monitors()
	for _, monitor in ipairs(monitors) do
		monitor_combo:append_text(monitor)
	end
	monitor_combo:set_active(0)

	local refresh_btn = Gtk.Button({ label = "🔄  Atualizar" })
	refresh_btn:get_style_context():add_class("suggested")

	local monitor_box = Gtk.Box({ orientation = Gtk.Orientation.HORIZONTAL, spacing = 6 })
	monitor_box:pack_start(monitor_label, false, false, 0)
	monitor_box:pack_start(monitor_combo, false, false, 0)

	header_bar:pack_start(title_box, false, false, 0)
	header_bar:pack_start(search_entry, true, true, 0)
	header_bar:pack_start(monitor_box, false, false, 0)
	header_bar:pack_start(refresh_btn, false, false, 0)

	-- ===================== Grid =====================
	local scrolled = Gtk.ScrolledWindow({
		hscrollbar_policy = Gtk.PolicyType.NEVER,
		vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
	})

	local flowbox = Gtk.FlowBox({
		valign = Gtk.Align.START,
		max_children_per_line = 5,
		min_children_per_line = 2,
		selection_mode = Gtk.SelectionMode.NONE,
		column_spacing = 14,
		row_spacing = 14,
		homogeneous = true,
		margin = 4,
	})

	-- Tabela para mapear widgets (o "card") para caminhos de wallpapers
	local wallpaper_paths = {}
	local card_widgets = {}
	local selected_card = nil

	local function select_card(card)
		if selected_card then
			selected_card:get_style_context():remove_class("selected")
		end
		selected_card = card
		if selected_card then
			selected_card:get_style_context():add_class("selected")
		end
	end

	-- Status bar (declarado antes para poder atualizar a contagem)
	local status_label = Gtk.Label({ xalign = 0, use_markup = true })
	status_label:get_style_context():add_class("status-bar")

	local function update_status(shown, total)
		status_label:set_markup(string.format("<span class='count-badge'>%d</span> de %d wallpapers", shown, total))
	end

	-- Função para carregar wallpapers no flowbox
	local all_wallpapers = {}

	local function build_card(path)
		local card = Gtk.Box({
			orientation = Gtk.Orientation.VERTICAL,
			spacing = 8,
		})
		card:get_style_context():add_class("wallpaper-card")

		-- Frame do thumbnail
		local thumb_frame = Gtk.Box({
			orientation = Gtk.Orientation.VERTICAL,
			halign = Gtk.Align.CENTER,
			valign = Gtk.Align.CENTER,
		})
		thumb_frame:get_style_context():add_class("thumb-frame")
		thumb_frame:set_size_request(200, 130)

		local success, pixbuf = pcall(function()
			return GdkPixbuf.Pixbuf.new_from_file_at_scale(path, 200, 130, false)
		end)

		if success and pixbuf then
			local image = Gtk.Image({ pixbuf = pixbuf })
			thumb_frame:pack_start(image, true, true, 0)
		else
			local placeholder = Gtk.Label({ label = "📷" })
			placeholder:get_style_context():add_class("thumb-placeholder")
			thumb_frame:pack_start(placeholder, true, true, 0)
		end

		-- Nome do arquivo
		local filename = path:match("([^/]+)$")
		local label = Gtk.Label({
			label = filename,
			max_width_chars = 22,
			ellipsize = 3, -- ELLIPSIZE_END
			tooltip_text = filename,
			xalign = 0.5,
		})
		label:get_style_context():add_class("wallpaper-name")

		card:pack_start(thumb_frame, false, false, 0)
		card:pack_start(label, false, false, 0)

		-- Clique aplica o wallpaper (evita depender do double-click do FlowBox)
		local event_box = Gtk.EventBox({ visible_window = false })
		event_box:add(card)
		event_box:add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
		event_box.on_button_press_event = function()
			select_card(card)
			local monitor = monitor_combo:get_active_text()
			apply_wallpaper(path, monitor)

			local dialog = Gtk.MessageDialog({
				transient_for = window,
				modal = true,
				message_type = Gtk.MessageType.INFO,
				buttons = Gtk.ButtonsType.OK,
				text = "✅ Wallpaper aplicado!",
				secondary_text = filename .. "  →  " .. monitor,
			})
			dialog:run()
			dialog:destroy()
			return false
		end

		return event_box, card
	end

	local function populate(filter)
		filter = (filter or ""):lower()

		local children = flowbox:get_children()
		for i = 1, #children do
			flowbox:remove(children[i])
		end
		wallpaper_paths = {}
		card_widgets = {}
		selected_card = nil

		local shown = 0
		for _, path in ipairs(all_wallpapers) do
			local filename = (path:match("([^/]+)$") or ""):lower()
			if filter == "" or filename:find(filter, 1, true) then
				local event_box, card = build_card(path)
				event_box:show_all()
				flowbox:add(event_box)
				wallpaper_paths[card] = path
				table.insert(card_widgets, card)
				shown = shown + 1
			end
		end

		update_status(shown, #all_wallpapers)
	end

	local function load_wallpapers()
		all_wallpapers = get_wallpapers()
		populate(search_entry.text)
	end

	search_entry.on_search_changed = function()
		populate(search_entry.text)
	end

	-- Botão refresh
	refresh_btn.on_clicked = function()
		load_wallpapers()
	end

	scrolled:add(flowbox)

	main_box:pack_start(header_bar, false, false, 0)
	main_box:pack_start(scrolled, true, true, 0)
	main_box:pack_start(status_label, false, false, 0)

	window:add(main_box)

	-- Carregar wallpapers inicialmente
	load_wallpapers()

	window:show_all()
	return window
end

-- Inicializar aplicação
Gtk.init()
create_window()
Gtk.main()
