class_name UI
extends RefCounted
## UI-кит: палитра, шрифты, кнопки, карточки, бейджи.
##
## Интерфейс собирается кодом, а не .tscn-файлами: экраны полностью
## data-driven (список клиентов, заказов, запчастей), а такую вёрстку проще
## тестировать headless-скриптом. Стили живут в одном месте — перекрасить
## игру можно, не трогая сцены.

const BG := Color("#0b0f14")
const PANEL := Color("#151c25")
const PANEL2 := Color("#1d2632")
const PANEL3 := Color("#243040")
const LINE := Color("#2a3646")
const TEXT := Color("#e8f0f8")
const DIM := Color("#8fa3b8")
const FAINT := Color("#5f7488")
const ACCENT := Color("#38e8a0")
const ACCENT_DARK := Color("#1aa677")
const DANGER := Color("#ff5a5f")
const WARN := Color("#ffb020")
const GOLD := Color("#ffcc33")
const BLUE := Color("#4aa8ff")

const FONT_REG := "res://assets/fonts/NotoSans-Regular.ttf"
const FONT_BOLD := "res://assets/fonts/NotoSans-Bold.ttf"

static var _theme: Theme = null
static var _font_reg: FontFile = null
static var _font_bold: FontFile = null


static func font_regular() -> FontFile:
	if _font_reg == null:
		_font_reg = load(FONT_REG)
	return _font_reg


static func font_bold() -> FontFile:
	if _font_bold == null:
		_font_bold = load(FONT_BOLD)
	return _font_bold


## Скруглённая плашка-стильбокс.
static func style(bg: Color, radius: int = 22, border: Color = Color.TRANSPARENT, border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	if border_w > 0:
		sb.border_color = border
		sb.border_width_left = border_w
		sb.border_width_top = border_w
		sb.border_width_right = border_w
		sb.border_width_bottom = border_w
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb


static func theme() -> Theme:
	if _theme != null:
		return _theme

	var t := Theme.new()
	t.default_font = font_regular()
	t.default_font_size = 30

	# --- Кнопки ---
	t.set_stylebox("normal", "Button", style(PANEL2, 22, LINE, 2))
	t.set_stylebox("hover", "Button", style(PANEL3, 22, LINE, 2))
	t.set_stylebox("pressed", "Button", style(PANEL3, 22, ACCENT, 2))
	t.set_stylebox("disabled", "Button", style(PANEL, 22, LINE, 2))
	t.set_stylebox("focus", "Button", style(Color.TRANSPARENT, 22))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color("#5f7488"))
	t.set_font_size("font_size", "Button", 32)

	# --- Панели ---
	t.set_stylebox("panel", "PanelContainer", style(PANEL, 24, LINE, 2))
	t.set_stylebox("panel", "Panel", style(PANEL, 24, LINE, 2))

	# --- Поля ввода/слайдер ---
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", 30)

	_theme = t
	return t


## Шрифт нужен и отдельным Label'ам с другим начертанием.
static func bold_font() -> Font:
	return font_bold()


static func label(text: String, size: int = 30, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func bold(text: String, size: int = 30, color: Color = TEXT) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", font_bold())
	return l


static func caption(text: String, color: Color = DIM) -> Label:
	return label(text, 24, color)


## Кнопка с большой зоной нажатия (по умолчанию 96 px при ширине экрана 720).
static func button(text: String, primary: bool = false, height: int = 96, font_size: int = 34) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	if primary:
		b.add_theme_stylebox_override("normal", style(ACCENT, 22))
		b.add_theme_stylebox_override("hover", style(ACCENT.lightened(0.06), 22))
		b.add_theme_stylebox_override("pressed", style(ACCENT_DARK, 22))
		b.add_theme_stylebox_override("disabled", style(Color("#1d3a2e"), 22))
		b.add_theme_color_override("font_color", Color("#04140d"))
		b.add_theme_color_override("font_hover_color", Color("#04140d"))
		b.add_theme_color_override("font_pressed_color", Color("#04140d"))
		b.add_theme_color_override("font_disabled_color", Color("#5f7488"))
	return b


static func card(radius: int = 24, bg: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, radius, LINE, 2))
	return p


## Квадратный цветной бейдж с буквой (Э/Б/З/В/Д) — «иконка» без картинок.
static func badge(letter: String, color: Color, size: int = 96) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(size, size)
	var sb := style(color.darkened(0.55), 20, color, 3)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", sb)
	var l := label(letter, int(size * 0.5), color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## Пилюля-статус: «готов», «дорого», «в наличии».
static func pill(text: String, color: Color, font_size: int = 24) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := style(color.darkened(0.6), 14, color, 2)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(label(text, font_size, color))
	return p


static func margins(m: int) -> MarginContainer:
	var c := MarginContainer.new()
	c.add_theme_constant_override("margin_left", m)
	c.add_theme_constant_override("margin_right", m)
	c.add_theme_constant_override("margin_top", m)
	c.add_theme_constant_override("margin_bottom", m)
	return c


static func spacer(h: int = 12) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func hspacer(w: int = 12) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	return c


static func divider() -> ColorRect:
	var r := ColorRect.new()
	r.color = LINE
	r.custom_minimum_size = Vector2(0, 2)
	return r


## 12345 → «12 345 ₽»
static func money(value: int) -> String:
	var s := str(absi(value))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = " " + out
	return ("−" if value < 0 else "") + out + " ₽"