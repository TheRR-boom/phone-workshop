extends Control
## Сцена разборки и поиска неисправности.
##
## Игрок сам разбирает телефон по слоям: винты → крышка → щит → батарея →
## шлейфы → плата. Поломка скрыта: её находят осмотром (лупа) или
## мультиметром, а не выбором из списка. Диагноз подтверждается на узле.

const DEV_W := 1000.0
const DEV_H := 2000.0

var model: DeviceModel
var order: Order

var _zoom := 1.0          # 1.0 = вписать целиком, 3.0 = максимальное приближение
var _pan := Vector2.ZERO  # сдвиг в экранных пикселях
var _fit := 1.0
var _area := Rect2()
var _tool := "screwdriver"
var _bit := "pentalobe"
var _pointers: Dictionary = {}
var _pinch_dist := 0.0
var _pinch_zoom := 1.0
var _press := Vector2.ZERO
var _press_time := 0
var _pressed := false
var _panned := false
var _swipe_from := Vector2.ZERO
var _swiping := false

var _toast_label: Label
var _toast_timer := 0.0
var _hint_label: Label
var _damage_label: Label
var _evidence_label: PanelContainer
var _evidence_text: Label
var _bit_row: HBoxContainer
var _tool_buttons: Dictionary = {}

var _overlay: Control = null


func _ready() -> void:
	theme = UI.theme()
	order = Game.current_order
	if order == null or order.defect == null:
		Router.go("workshop")
		return
	model = DeviceModel.new()
	model.setup(order.phone, order.defect)
	_build()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_area()
		queue_redraw()


# ---------------------------------------------------------------- вёрстка ---

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#0a0e13")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 16
	top.add_theme_constant_override("separation", 12)
	add_child(top)

	var back := UI.button("Назад", false, 84, 26)
	back.custom_minimum_size = Vector2(150, 84)
	back.pressed.connect(_on_back)
	top.add_child(back)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	title_box.add_child(UI.bold(order.phone.title, 32))
	_damage_label = UI.caption("Повреждения: 0", UI.FAINT)
	title_box.add_child(_damage_label)
	top.add_child(title_box)

	_evidence_label = UI.pill("улик: 0", UI.BLUE, 22)
	_evidence_text = _evidence_label.get_child(0)
	top.add_child(_evidence_label)

	_hint_label = UI.label("", 26, UI.TEXT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hint_label.offset_left = 24
	_hint_label.offset_right = -24
	_hint_label.offset_top = 116
	add_child(_hint_label)

	_build_toolbar()

	_toast_label = UI.label("", 24, UI.TEXT)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toast_label.offset_left = 40
	_toast_label.offset_right = -40
	_toast_label.offset_top = -300
	_toast_label.offset_bottom = -250
	_toast_label.modulate.a = 0.0
	add_child(_toast_label)

	_layout_area()


func _build_toolbar() -> void:
	var wrap := VBoxContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	wrap.offset_left = 20
	wrap.offset_right = -20
	wrap.offset_bottom = -16
	wrap.add_theme_constant_override("separation", 8)
	add_child(wrap)

	_bit_row = HBoxContainer.new()
	_bit_row.add_theme_constant_override("separation", 8)
	_bit_row.visible = true
	wrap.add_child(_bit_row)
	for bit in [["pentalobe", "P2"], ["torx", "T5"], ["phillips", "PH0"]]:
		var b := UI.button(String(bit[1]), false, 64, 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select_bit.bind(String(bit[0])))
		_bit_row.add_child(b)
	_rebuild_bits()

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	wrap.add_child(bar)

	for item in [["screwdriver", "Отвёртка"], ["suction", "Присоска"], ["spudger", "Лопатка"], ["multimeter", "Мультиметр"]]:
		var b := UI.button(String(item[1]), false, 88, 20)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select_tool.bind(String(item[0])))
		bar.add_child(b)
		_tool_buttons[String(item[0])] = b
	_rebuild_tools()


func _layout_area() -> void:
	var h := size.y
	_area = Rect2(0, 150, size.x, maxf(200.0, h - 150 - 220))
	_fit = minf(_area.size.x / DEV_W, _area.size.y / DEV_H) * 0.94


func _rebuild_tools() -> void:
	for key in _tool_buttons.keys():
		var b: Button = _tool_buttons[key]
		var active: bool = String(key) == _tool
		b.add_theme_stylebox_override("normal", UI.style(UI.ACCENT if active else UI.PANEL2, 20))
		b.add_theme_color_override("font_color", Color("#04140d") if active else UI.TEXT)
		if active:
			b.add_theme_color_override("font_hover_color", Color("#04140d"))


func _rebuild_bits() -> void:
	for i in _bit_row.get_child_count():
		var b: Button = _bit_row.get_child(i)
		var key: String = ["pentalobe", "torx", "phillips"][i]
		var active: bool = key == _bit
		b.add_theme_stylebox_override("normal", UI.style(UI.PANEL3 if active else UI.PANEL, 18, UI.ACCENT if active else UI.LINE, 2))
		b.add_theme_color_override("font_color", UI.ACCENT if active else UI.DIM)


func _select_bit(bit: String) -> void:
	_bit = bit
	_tool = "screwdriver"
	_rebuild_bits()
	_rebuild_tools()
	_tap_feedback()


func _select_tool(tool: String) -> void:
	_tool = tool
	_bit_row.visible = tool == "screwdriver"
	_rebuild_tools()
	_tap_feedback()
	queue_redraw()


func _tap_feedback() -> void:
	Input.vibrate_handheld(20)


func _toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	_toast_timer = 2.2


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.4:
			_toast_label.modulate.a = maxf(0.0, _toast_timer / 0.4)


# ---------------------------------------------------------------- ввод ---

func _unhandled_input(event: InputEvent) -> void:
	if _overlay != null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_pointer_down(event.position, event.index)
		else:
			_pointer_up(event.position, event.index)
		return
	if event is InputEventScreenDrag:
		_pointer_drag(event.position, event.index)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_down(event.position, 0)
		else:
			_pointer_up(event.position, 0)
		return
	if event is InputEventMouseMotion and _pressed:
		_pointer_drag(event.position, 0)
		return
	if event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)
		queue_redraw()


func _pointer_down(pos: Vector2, id: int) -> void:
	if not _area.has_point(pos):
		return
	_pointers[id] = pos
	if _pointers.size() == 2:
		var pts := _pointers.values()
		_pinch_dist = (pts[0] as Vector2).distance_to(pts[1] as Vector2)
		_pinch_zoom = _zoom
		_swiping = false
		return
	_pressed = true
	_panned = false
	_press = pos
	_press_time = Time.get_ticks_msec()
	_swipe_from = _to_device(pos)
	_swiping = _tool == "suction" and not model.is_done("back_cover")


func _pointer_drag(pos: Vector2, id: int) -> void:
	if not _pointers.has(id):
		return
	_pointers[id] = pos

	if _pointers.size() >= 2:
		var pts := _pointers.values()
		var dist := (pts[0] as Vector2).distance_to(pts[1] as Vector2)
		if _pinch_dist > 1.0:
			_zoom = clampf(_pinch_zoom * (dist / _pinch_dist), 1.0, 3.5)
			queue_redraw()
		return

	if _press.distance_to(pos) > 14.0:
		_panned = true
	if _swiping:
		queue_redraw()
		return
	if _zoom > 1.01:
		_pan += pos - _press
		_press = pos
		queue_redraw()


func _pointer_up(pos: Vector2, id: int) -> void:
	if _pointers.has(id):
		_pointers.erase(id)
	if _pointers.size() < 2:
		_pinch_dist = 0.0

	if _swiping:
		_swiping = false
		var delta := _to_device(pos) - _swipe_from
		if delta.y < -420.0 and absf(delta.y) > absf(delta.x) * 1.4:
			var res := model.remove("back_cover", "suction")
			if res.ok:
				_toast("Крышка снята")
				_refresh()
			else:
				_toast(String(res.get("text", "Не получилось")))
		else:
			_toast("Свайп вверх, увереннее")
		return

	if not _pressed:
		return
	_pressed = false
	var held := Time.get_ticks_msec() - _press_time
	if _panned or pos.distance_to(_press) > 14.0 or held > 900:
		return
	_handle_tap(_to_device(pos))


func _to_device(pos: Vector2) -> Vector2:
	var scale := _fit * _zoom
	var origin := _origin(scale)
	return (pos - origin) / scale


func _origin(scale: float) -> Vector2:
	var base := Vector2(
		_area.position.x + (_area.size.x - DEV_W * scale) * 0.5,
		_area.position.y + (_area.size.y - DEV_H * scale) * 0.5
	)
	return base + _pan


func _zoom_at(pos: Vector2, factor: float) -> void:
	var before := _to_device(pos)
	_zoom = clampf(_zoom * factor, 1.0, 3.5)
	var after := _to_device(pos)
	_pan += (after - before) * _fit * _zoom


# ---------------------------------------------------------------- тап ---

func _handle_tap(p: Vector2) -> void:
	# 1. Винты
	if _tool == "screwdriver":
		for c in model.components:
			var id := String(c["id"])
			if model.is_done(id) or not model.is_exposed(id):
				continue
			var idx := model.screw_at(id, p)
			if idx >= 0:
				var res := model.unscrew(id, idx, _bit)
				if res.ok:
					_toast("Винт выкручен (осталось %d)" % int(res.get("left", 0)))
					Input.vibrate_handheld(35)
				else:
					_toast(String(res.get("text", "Не выходит")))
					Input.vibrate_handheld(90)
				_refresh()
				return

	# 2. Мультиметр: точки замера
	if _tool == "multimeter":
		for point in model.test_points:
			if (point["pos"] as Vector2).distance_to(p) <= 70.0:
				_open_multimeter(String(point["id"]))
				return
		_toast("Наведите на контактную площадку")
		return

	# 3. Компонент под пальцем
	var target := _component_at(p)
	if target.is_empty():
		return
	var id := String(target["id"])

	if _tool == "suction":
		if id == "back_cover":
			_toast("Потяните крышку вверх свайпом")
		return

	if _tool == "spudger":
		if bool(target.get("disconnect", false)):
			var res := model.disconnect_flex(id, "spudger")
			if res.ok:
				_toast("Разъём отключён")
				_refresh()
			else:
				_toast(String(res.get("text", "")))
			return
		var res2 := model.remove(id, "spudger")
		if res2.ok:
			_toast("Снято: %s" % String(target["title"]))
			_refresh()
		else:
			_toast(String(res2.get("text", "Не снимается")))
		return

	# Без инструмента — осмотр
	_open_inspect(id)


func _component_at(p: Vector2) -> Dictionary:
	var best := {}
	for c in model.components:
		var id := String(c["id"])
		if model.is_done(id) or not model.is_exposed(id):
			continue
		if (c["rect"] as Rect2).has_point(p):
			if best.is_empty() or int(c["layer"]) > int(best["layer"]):
				best = c
	return best


# ---------------------------------------------------------------- отрисовка ---

func _draw() -> void:
	var scale := _fit * _zoom
	draw_set_transform(_origin(scale), 0.0, Vector2(scale, scale))

	_draw_frame()
	if not model.is_done("back_cover"):
		_draw_cover()
	else:
		_draw_internals()
	_draw_screws()
	if _tool == "multimeter":
		_draw_test_points()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _rrect(rect: Rect2, color: Color, radius: int, border: Color = Color.TRANSPARENT, bw: int = 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	if bw > 0:
		sb.border_color = border
		sb.border_width_left = bw
		sb.border_width_top = bw
		sb.border_width_right = bw
		sb.border_width_bottom = bw
	draw_style_box(sb, rect)


func _draw_frame() -> void:
	_rrect(Rect2(78, 38, 844, 1924), Color("#2a3542"), 70, Color("#4b5d70"), 5)
	_rrect(Rect2(96, 56, 808, 1888), Color("#0b1118"), 56)
	# Боковые кнопки
	_rrect(Rect2(60, 520, 18, 120), Color("#3a4857"), 8)
	_rrect(Rect2(922, 480, 18, 150), Color("#3a4857"), 8)


func _draw_cover() -> void:
	var c := model.comp("back_cover")
	_rrect(c["rect"], Color("#1c2734"), 66, Color("#3d4f63"), 4)
	# Блик стекла
	_rrect(Rect2(120, 90, 760, 520), Color("#24354a"), 48)
	# Блок камер
	_rrect(Rect2(540, 110, 300, 300), Color("#111a24"), 46, Color("#3c4c5e"), 3)
	draw_circle(Vector2(620, 190), 52, Color("#0a0f15"))
	draw_circle(Vector2(760, 190), 52, Color("#0a0f15"))
	draw_circle(Vector2(620, 330), 52, Color("#0a0f15"))
	draw_circle(Vector2(760, 330), 42, Color("#0a0f15"))
	draw_circle(Vector2(620, 190), 30, Color("#1b4a6b"))
	draw_circle(Vector2(760, 190), 30, Color("#1b4a6b"))
	# Логотип
	draw_string(ThemeDB.fallback_font, Vector2(420, 1180), "VOLT", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color("#38506a"))


func _draw_internals() -> void:
	_draw_board()
	_draw_battery()
	_draw_flexes()
	_draw_shield()
	_draw_camera()
	_draw_speaker()
	_draw_vibro()


func _draw_board() -> void:
	if model.is_done("board"):
		return
	var shown := model.is_exposed("board") or not model.is_done("shield_plate")
	if not shown:
		return
	var r := Rect2(120, 140, 760, 740)
	_rrect(r, Color("#123b2f"), 18, Color("#2a6a55"), 3)
	# Дорожки
	for i in 12:
		var y := r.position.y + 40 + i * 56
		draw_line(Vector2(r.position.x + 20, y), Vector2(r.end.x - 20, y + ((i % 3) - 1) * 8), Color("#2f8a6c"), 2.0)
	for i in 8:
		var x := r.position.x + 60 + i * 90
		draw_line(Vector2(x, r.position.y + 20), Vector2(x, r.end.y - 20), Color("#1f6b52"), 1.5)
	# Чипы
	_chip(Rect2(180, 190, 210, 160), "SoC")
	_chip(Rect2(410, 190, 150, 90), "RAM")
	_chip(Rect2(180, 380, 140, 110), "PMIC")
	_chip(Rect2(340, 380, 120, 90), "MODEM")
	_chip(Rect2(480, 380, 150, 70), "CODEC")
	_chip(Rect2(600, 560, 120, 90), "CHARGE")
	# Разъёмы
	_rrect(Rect2(430, 860, 160, 100), Color("#0e141b"), 14, Color("#3a4b5c"), 2)
	draw_rect(Rect2(448, 876, 124, 30), Color("#c8a24a"))
	# Антенные дорожки
	draw_polyline(PackedVector2Array([
		Vector2(140, 820), Vector2(300, 820), Vector2(300, 700), Vector2(520, 700),
	]), Color("#8a6a2a"), 4.0)


func _chip(r: Rect2, label: String) -> void:
	_rrect(r, Color("#0d1319"), 8, Color("#3d5164"), 2)
	draw_rect(Rect2(r.position + Vector2(12, 12), r.size - Vector2(24, 24)), Color("#111b24"))
	# Выводы
	for i in 5:
		draw_rect(Rect2(r.position.x + 10 + i * (r.size.x - 20) / 5.0, r.position.y - 6, 10, 6), Color("#8ea3b8"))
		draw_rect(Rect2(r.position.x + 10 + i * (r.size.x - 20) / 5.0, r.end.y, 10, 6), Color("#8ea3b8"))
	draw_string(ThemeDB.fallback_font, r.position + Vector2(12, r.size.y - 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#5f7d94"))


func _draw_battery() -> void:
	if model.is_done("battery"):
		return
	var swollen := model.defect != null and model.defect.component_id == "battery"
	var r := Rect2(130, 980, 740, 780)
	if swollen:
		r = r.grow(10.0)
	_rrect(r, Color("#17322b"), 22, Color("#2f6d58"), 3)
	_rrect(Rect2(r.position + Vector2(24, 24), r.size - Vector2(48, 150)), Color("#1b3f36"), 14)
	draw_string(ThemeDB.fallback_font, r.position + Vector2(60, 120), "Li-ion 3.87V", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("#4f8d77"))
	if swollen:
		draw_string(ThemeDB.fallback_font, r.position + Vector2(60, 180), "ВЗДУТИЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("#ffb020"))
		draw_arc(r.get_center(), r.size.x * 0.52, -1.2, 1.2, 28, Color("#ffb02080"), 10.0)
	# Шлейф батареи
	draw_line(Vector2(500, 980), Vector2(500, 900), Color("#c98a3a"), 14.0)
	draw_rect(Rect2(470, 880, 60, 30), Color("#c9d6e2"))


func _draw_flexes() -> void:
	if not model.is_done("display_flex"):
		draw_line(Vector2(155, 780), Vector2(155, 1260), Color("#c98a3a"), 26.0)
		for i in 3:
			draw_line(Vector2(147 + i * 6, 790), Vector2(147 + i * 6, 1250), Color("#7a4a1a"), 2.0)
		if model.defect != null and model.defect.component_id == "display_flex":
			draw_circle(Vector2(155, 1240), 16, Color("#ff5a5f"))
	if not model.is_done("port_flex"):
		_rrect(Rect2(410, 1740, 180, 150), Color("#b97a2a"), 16, Color("#e0a24a"), 3)
		draw_rect(Rect2(430, 1770, 140, 30), Color("#e8d8b0"))
		if model.defect != null and model.defect.component_id == "port_flex":
			for i in 5:
				draw_circle(Vector2(440 + i * 28, 1800), 6, Color("#5fd08a"))


func _draw_shield() -> void:
	if model.is_done("shield_plate"):
		return
	var r := Rect2(120, 120, 760, 520)
	_rrect(r, Color("#2b3742"), 16, Color("#56697d"), 3)
	for i in 14:
		draw_line(Vector2(r.position.x + 20, r.position.y + 20 + i * 36), Vector2(r.end.x - 20, r.position.y + 20 + i * 36), Color("#3a4a58"), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(180, 420), "SHIELD", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#66798c"))


func _draw_camera() -> void:
	if model.is_done("camera_main"):
		return
	var r := Rect2(560, 150, 260, 240)
	_rrect(r, Color("#0f151c"), 22, Color("#38495a"), 3)
	draw_circle(r.get_center(), 78, Color("#0a0f15"))
	draw_circle(r.get_center(), 58, Color("#12293d"))
	draw_circle(r.get_center() + Vector2(-14, -14), 18, Color("#2b5f8a"))


func _draw_speaker() -> void:
	if model.is_done("speaker"):
		return
	var r := Rect2(640, 1690, 190, 140)
	_rrect(r, Color("#141c24"), 18, Color("#36485a"), 2)
	for row in 3:
		for col in 5:
			draw_circle(Vector2(r.position.x + 28 + col * 32, r.position.y + 32 + row * 30), 6, Color("#3d5468"))


func _draw_vibro() -> void:
	if model.is_done("vibro"):
		return
	var r := Rect2(220, 1700, 160, 120)
	_rrect(r, Color("#1d2732"), 30, Color("#3b4d5f"), 3)
	draw_circle(r.get_center(), 34, Color("#2a3a4a"))
	draw_circle(r.get_center() + Vector2(10, 0), 14, Color("#52687c"))


func _draw_screws() -> void:
	for c in model.components:
		var id := String(c["id"])
		if model.is_done(id) or not model.is_exposed(id):
			continue
		var list: Array = c["screws"]
		for s in list:
			if bool(s["removed"]):
				continue
			var pos := s["pos"] as Vector2
			var type := String(s["type"])
			draw_circle(pos, 24, Color("#9fb0c2"))
			draw_circle(pos, 15, Color("#101820"))
			match type:
				"pentalobe":
					for i in 5:
						var a := -PI / 2 + i * TAU / 5
						draw_circle(pos + Vector2(cos(a), sin(a)) * 9, 4, Color("#0a0f14"))
				"torx":
					for i in 6:
						var a2 := -PI / 2 + i * TAU / 6
						draw_line(pos, pos + Vector2(cos(a2), sin(a2)) * 12, Color("#0a0f14"), 5.0)
				_:
					draw_line(pos - Vector2(12, 0), pos + Vector2(12, 0), Color("#0a0f14"), 5.0)
					draw_line(pos - Vector2(0, 12), pos + Vector2(0, 12), Color("#0a0f14"), 5.0)


func _draw_test_points() -> void:
	for point in model.test_points:
		var blocked := false
		for req in point["requires"]:
			if not model.is_done(String(req)):
				blocked = true
		if blocked:
			continue
		var pos := point["pos"] as Vector2
		draw_circle(pos, 26, Color("#ffcc33"))
		draw_circle(pos, 16, Color("#8a6a10"))
		draw_string(ThemeDB.fallback_font, pos + Vector2(-20, -34), String(point["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#ffd97a"))


# ------------------------------------------------------------ обновление ---

func _refresh() -> void:
	_damage_label.text = "Повреждения: %d" % model.damage
	_evidence_text.text = "улик: %d" % model.evidence.size()
	_hint_label.text = model.hint()
	queue_redraw()


func _on_back() -> void:
	Game.return_order(order)
	Router.go("workshop")


# ------------------------------------------------------------ осмотр ---

func _open_inspect(id: String) -> void:
	var res := model.inspect(id)
	if not res.ok:
		_toast(String(res.get("text", "")))
		return
	var c: Dictionary = res["component"]

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.04, 0.9)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(scrim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.style(UI.PANEL, 26, UI.LINE, 2))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(620, 760)
	panel.position = (size - panel.custom_minimum_size) * 0.5
	_overlay.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	v.add_child(UI.bold(String(c["title"]), 34))
	v.add_child(UI.caption("Осмотр · наведите на подозрительное место", UI.DIM))

	var view := InspectView.new()
	view.custom_minimum_size = Vector2(0, 420)
	view.model = model
	view.component = c
	view.on_found = func(text: String) -> void:
		_toast(text)
		_refresh()
		_close_overlay()
	v.add_child(view)

	if bool(res["anomaly"]):
		v.add_child(UI.caption("Тапните по подсвеченной зоне", UI.WARN))
	else:
		v.add_child(UI.caption("Следов нет — проверьте прибором", UI.FAINT))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var close := UI.button("Закрыть", false, 84, 26)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(_close_overlay)
	row.add_child(close)
	if id == model.defect.component_id and not model.evidence.is_empty():
		var confirm := UI.button("Это причина", true, 84, 26)
		confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		confirm.pressed.connect(_confirm.bind(id))
		row.add_child(confirm)
	v.add_child(row)


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


# --------------------------------------------------------- мультиметр ---

func _open_multimeter(point_id: String) -> void:
	var panel := _make_sheet(560)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	v.add_child(UI.bold("Мультиметр", 32))
	var reading := UI.bold("—", 56, UI.ACCENT)
	reading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(reading)
	var note := UI.caption("Выберите режим", UI.DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)

	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 10)
	var buttons := {}
	for pair in [["V", "Напряжение"], ["R", "Сопротивление"], ["C", "Прозвонка"]]:
		var b := UI.button(String(pair[1]), false, 76, 20)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_measure.bind(point_id, String(pair[0]), reading, note, buttons))
		modes.add_child(b)
		buttons[String(pair[0])] = b
	v.add_child(modes)

	var close := UI.button("Закрыть", false, 84, 26)
	close.pressed.connect(_close_overlay)
	v.add_child(close)
	_measure(point_id, "V", reading, note, buttons)


func _measure(point_id: String, mode: String, label: Label, note: Label, buttons: Dictionary) -> void:
	var res := model.measure(point_id, mode)
	for key in buttons.keys():
		var b: Button = buttons[key]
		var active: bool = String(key) == mode
		b.add_theme_stylebox_override("normal", UI.style(UI.ACCENT if active else UI.PANEL2, 18))
		b.add_theme_color_override("font_color", Color("#04140d") if active else UI.TEXT)
	if res.ok:
		label.text = String(res["reading"])
		label.add_theme_color_override("font_color", UI.WARN if bool(res["faulty"]) else UI.ACCENT)
		note.text = "Точка %s · %s" % [res["label"], "аномалия" if bool(res["faulty"]) else "норма"]
		if bool(res["faulty"]):
			Input.vibrate_handheld(60)
	else:
		label.text = "—"
		note.text = String(res.get("text", "Нет доступа"))
	_refresh()


# --------------------------------------------------------------- оплата ---

func _confirm(id: String) -> void:
	var res := model.confirm(id)
	if not res.ok:
		_toast(String(res.get("text", "")))
		Input.vibrate_handheld(120)
		return
	_close_overlay()
	_refresh()
	_open_quote()


func _open_quote(selected_quality: String = "") -> void:
	var fault := order.fault
	var ceiling := Econ.client_ceiling(order.phone, fault, order.client_type, Game.rep)

	var quality_id := selected_quality
	if fault.part_type == "":
		quality_id = ""
	elif quality_id == "":
		# По умолчанию — самая доступная деталь на складе
		for qid in ["copy", "original", "used"]:
			if Game.count_part(fault.part_type, qid, order.phone.tier) > 0:
				quality_id = qid
				break
		if quality_id == "":
			quality_id = "copy"

	var panel := _make_sheet(800)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	v.add_child(UI.bold("Диагноз: %s" % order.defect.title, 30))
	var last_evidence := ""
	if not model.evidence.is_empty():
		last_evidence = String(model.evidence.back())
	v.add_child(UI.caption("Улика: %s" % last_evidence, UI.DIM))

	if fault.part_type != "":
		v.add_child(UI.caption("Запчасть:", UI.DIM))
		for q in DB.qualities:
			var stock := Game.count_part(fault.part_type, q.id, order.phone.tier)
			var active: bool = q.id == quality_id
			var b := UI.button(
				"%s · %s · склад %d" % [q.title, UI.money(Catalog.part_cost(fault.part_type, order.phone.tier, q.id)), stock],
				active, 76, 22
			)
			b.disabled = stock <= 0
			if stock <= 0:
				b.text = "%s · нет на складе" % q.title
			b.pressed.connect(_open_quote.bind(q.id))
			v.add_child(b)

	var price_label := UI.bold("", 38, UI.ACCENT)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(price_label)

	var cost := Econ.cost_price(order.phone, fault, quality_id)
	var slider := HSlider.new()
	slider.min_value = maxi(int(cost * 0.9), 100)
	slider.max_value = maxi(int(ceiling * 1.2), int(slider.min_value) + 100)
	slider.step = 50
	slider.value = mini(Econ.suggested_price(order.phone, fault, Game.rep), int(ceiling * 0.95))
	slider.custom_minimum_size = Vector2(0, 56)
	v.add_child(slider)

	var reaction := UI.caption("", UI.ACCENT)
	reaction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(reaction)

	var go := UI.button("Согласовать и ремонтировать", true, 90, 24)
	go.pressed.connect(func() -> void: _accept_quote(int(slider.value), ceiling, quality_id))
	v.add_child(go)

	var cancel := UI.button("Вернуться к разборке", false, 76, 22)
	cancel.pressed.connect(_close_overlay)
	v.add_child(cancel)

	var has_stock := true
	if fault.part_type != "":
		has_stock = false
		for q in DB.qualities:
			if Game.count_part(fault.part_type, q.id, order.phone.tier) > 0:
				has_stock = true
				break
	if not has_stock:
		v.add_child(UI.caption("Нет запчастей этого класса — купите в магазине", UI.DANGER))

	var update := func(value: float) -> void:
		price_label.text = UI.money(int(value))
		var r := Econ.reaction(int(value), ceiling)
		reaction.text = String(r["text"])
		reaction.add_theme_color_override("font_color", r["color"])
		go.disabled = not bool(r["ok"]) or not has_stock
	slider.value_changed.connect(update)
	update.call(slider.value)


func _accept_quote(price: int, ceiling: int, quality_id: String) -> void:
	if price > ceiling:
		_toast("Клиент не согласится на такую цену")
		return
	if order.fault.part_type != "" and not Game.has_part(order.fault.part_type, quality_id, order.phone.tier):
		_toast("Этой запчасти нет на складе")
		return
	order.price = price
	order.quality = DB.quality(quality_id) if quality_id != "" else null
	order.teardown_done = true
	order.status = "repair"
	Game.save_game()
	Router.go("repair")


func _make_sheet(height: int) -> PanelContainer:
	_close_overlay()
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.04, 0.85)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(scrim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.style(UI.PANEL, 26, UI.LINE, 2))
	panel.custom_minimum_size = Vector2(minf(size.x - 40, 680), height)
	panel.position = Vector2((size.x - panel.custom_minimum_size.x) * 0.5, (size.y - height) * 0.5)
	_overlay.add_child(panel)
	return panel


# ------------------------------------------------------- вспомогательный ---

class InspectView extends Control:
	var model: DeviceModel
	var component: Dictionary
	var on_found: Callable
	var _pulse := 0.0
	var _found := false

	func _ready() -> void:
		set_process(true)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		_pulse = fmod(_pulse + delta * 2.4, TAU)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(20, 20), size - Vector2(40, 40))
		draw_style_box(_style(), r)
		var kind := String(component.get("kind", ""))
		var c := r.get_center()
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x + 24, r.position.y + 52), "×4", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#5f7488"))
		match kind:
			"battery":
				draw_rect(Rect2(c - Vector2(210, 120), Vector2(420, 240)), Color("#1b3f36"))
				draw_rect(Rect2(c - Vector2(180, 90), Vector2(360, 180)), Color("#22503f"))
				draw_string(ThemeDB.fallback_font, c + Vector2(-150, 10), "Li-ion 3.87V", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("#5f9c86"))
			"board":
				draw_rect(Rect2(c - Vector2(230, 130), Vector2(460, 260)), Color("#123b2f"))
				draw_rect(Rect2(c - Vector2(160, 90), Vector2(120, 90)), Color("#0d1319"))
				draw_rect(Rect2(c + Vector2(20, -80), Vector2(90, 70)), Color("#0d1319"))
			"flex":
				draw_rect(Rect2(c - Vector2(40, 150), Vector2(80, 300)), Color("#c98a3a"))
				for i in 4:
					draw_line(c + Vector2(-24 + i * 16, -140), c + Vector2(-24 + i * 16, 140), Color("#7a4a1a"), 2.0)
			"speaker":
				draw_rect(Rect2(c - Vector2(150, 100), Vector2(300, 200)), Color("#141c24"))
				for row in 3:
					for col in 5:
						draw_circle(c + Vector2(-100 + col * 50, -50 + row * 45), 9, Color("#3d5468"))
			"camera":
				draw_circle(c, 140, Color("#0f151c"))
				draw_circle(c, 100, Color("#12293d"))
			"connector":
				draw_rect(Rect2(c - Vector2(120, 70), Vector2(240, 140)), Color("#0e141b"))
				draw_rect(Rect2(c - Vector2(90, 20), Vector2(180, 40)), Color("#c8a24a"))
			_:
				draw_rect(Rect2(c - Vector2(160, 90), Vector2(320, 180)), Color("#243240"))

		if String(component.get("id", "")) == model.defect.component_id:
			var glow := 0.55 + 0.35 * sin(_pulse)
			draw_circle(c + Vector2(70, -10), 46, Color(1.0, 0.45, 0.2, 0.18 * glow))
			draw_circle(c + Vector2(70, -10), 26, Color(1.0, 0.62, 0.25, 0.9))
			draw_string(ThemeDB.fallback_font, c + Vector2(46, 56), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#ffb020"))

	func _style() -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#0d141b")
		sb.corner_radius_top_left = 18
		sb.corner_radius_top_right = 18
		sb.corner_radius_bottom_left = 18
		sb.corner_radius_bottom_right = 18
		sb.border_color = Color("#2a3646")
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		return sb

	func _gui_input(event: InputEvent) -> void:
		var pos := Vector2.ZERO
		var pressed := false
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			pos = event.position
			pressed = event.pressed
		elif event is InputEventScreenTouch:
			pos = event.position
			pressed = event.pressed
		if not pressed or _found:
			return
		var c := Rect2(Vector2(20, 20), size - Vector2(40, 40)).get_center()
		if String(component.get("id", "")) == model.defect.component_id and pos.distance_to(c + Vector2(70, -10)) <= 70.0:
			_found = true
			on_found.call(model.defect.evidence)