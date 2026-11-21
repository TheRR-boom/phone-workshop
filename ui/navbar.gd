class_name NavBar
extends PanelContainer
## Нижняя навигация: 4 крупные кнопки (112 px ≈ 56 dp при 2x-плотности).
## Активный раздел подсвечен — игрок всегда понимает, где находится.

const ITEMS := [
	{"key": "workshop", "title": "Мастерская"},
	{"key": "showcase", "title": "Витрина"},
	{"key": "shop", "title": "Магазин"},
	{"key": "inventory", "title": "Склад"},
]

var active_key: String = "workshop"


func _ready() -> void:
	custom_minimum_size = Vector2(0, 128)
	add_theme_stylebox_override("panel", UI.style(UI.PANEL, 26, UI.LINE, 2))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	add_child(h)

	for item in ITEMS:
		var key := String(item["key"])
		var b := Button.new()
		b.text = String(item["title"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 112)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 26)

		if key == active_key:
			b.add_theme_stylebox_override("normal", UI.style(UI.ACCENT, 18))
			b.add_theme_stylebox_override("hover", UI.style(UI.ACCENT.lightened(0.06), 18))
			b.add_theme_stylebox_override("pressed", UI.style(UI.ACCENT_DARK, 18))
			b.add_theme_color_override("font_color", Color("#04140d"))
			b.add_theme_color_override("font_hover_color", Color("#04140d"))
			b.add_theme_color_override("font_pressed_color", Color("#04140d"))
		else:
			b.add_theme_stylebox_override("normal", UI.style(UI.PANEL2, 18))
			b.add_theme_stylebox_override("hover", UI.style(UI.PANEL3, 18))
			b.add_theme_stylebox_override("pressed", UI.style(UI.PANEL3, 18))

		b.pressed.connect(_on_press.bind(key))
		h.add_child(b)


func _on_press(key: String) -> void:
	if key == active_key:
		return
	Router.go(key)