extends Control
## Экран ремонта: мини-игра «разборка» (винты по порядку) и «замена модуля»
## (перетаскивание детали в гнездо). Затем проверка и итог заказа.
##
## Вся логика результата — в Econ/Game, сцена только собирает действия игрока.

const PHONE_SIZE := Vector2(440, 660)

var _order: Order
var _stage := 0                    # 0 — винты, 1 — модуль, 2 — проверка
var _next_screw := 0
var _damage := 0
var _module_placed := false
var _dragging := false
var _drag_offset := Vector2.ZERO

var _phone_area: Control
var _module: PanelContainer
var _socket: PanelContainer
var _hint: Label
var _stage_label: Label
var _action: Button
var _damage_lbl: Label
var _screw_buttons: Array[Button] = []
var _spots_left := 0
var _solder_btn: Button = null
var _solder_progress := 0.0
var _soldered := 0


func _ready() -> void:
	theme = UI.theme()
	_order = Game.current_order
	if _order == null:
		Router.go("workshop")
		return
	_build()
	if _order.teardown_done:
		_stage = 1
		_build_module_stage()
		_update_stage_ui()
	else:
		_build_screws()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := UI.margins(24)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	# Заголовок
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	var title := UI.bold(_order.phone.title, 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_damage_lbl = UI.caption("Повреждения: 0", UI.FAINT)
	head.add_child(_damage_lbl)
	root.add_child(head)

	_stage_label = UI.caption("ШАГ 1 ИЗ 3 · РАЗБОРКА", UI.FAINT)
	root.add_child(_stage_label)

	# Центральная область с телефоном
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	_phone_area = Control.new()
	_phone_area.custom_minimum_size = PHONE_SIZE
	_phone_area.size = PHONE_SIZE
	center.add_child(_phone_area)

	var body := PanelContainer.new()
	var body_style := UI.style(_order.phone.color.darkened(0.35), 44, _order.phone.color.lightened(0.25), 4)
	body.add_theme_stylebox_override("panel", body_style)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone_area.add_child(body)

	var cover := PanelContainer.new()
	cover.add_theme_stylebox_override("panel", UI.style(_order.phone.color.darkened(0.55), 40))
	cover.position = Vector2(14, 14)
	cover.size = PHONE_SIZE - Vector2(28, 28)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(cover)

	_hint = UI.label("", 26, UI.TEXT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_hint)

	_action = UI.button("Открутите винты", true, 96, 28)
	_action.disabled = true
	_action.pressed.connect(_on_action)
	root.add_child(_action)

	_update_stage_ui()


# --------------------------------------------------------------- винты ---

func _screw_points(n: int) -> Array[Vector2]:
	var w := PHONE_SIZE.x
	var h := PHONE_SIZE.y
	var m := 52.0
	var pts: Array[Vector2] = []
	if n <= 2:
		pts = [Vector2(w * 0.30, h - m), Vector2(w * 0.70, h - m)]
	elif n == 4:
		pts = [Vector2(m, m), Vector2(w - m, m), Vector2(m, h - m), Vector2(w - m, h - m)]
	else:
		pts = [
			Vector2(m, m), Vector2(w - m, m),
			Vector2(m, h * 0.5), Vector2(w - m, h * 0.5),
			Vector2(m, h - m), Vector2(w - m, h - m),
		]
	return pts


func _build_screws() -> void:
	var pts := _screw_points(_order.phone.screws)
	for i in pts.size():
		var b := Button.new()
		b.text = str(i + 1)
		b.custom_minimum_size = Vector2(92, 92)
		b.size = Vector2(92, 92)
		b.position = pts[i] - Vector2(46, 46)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 32)
		var st := UI.style(UI.PANEL3, 46, UI.LINE, 3)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.add_theme_stylebox_override("pressed", UI.style(UI.PANEL3, 46, UI.ACCENT, 3))
		b.add_theme_stylebox_override("disabled", UI.style(UI.PANEL, 46, UI.LINE, 3))
		b.pressed.connect(_tap_screw.bind(i, b))
		_phone_area.add_child(b)
		_screw_buttons.append(b)
	_highlight_next()


func _highlight_next() -> void:
	for i in _screw_buttons.size():
		var b := _screw_buttons[i]
		if i == _next_screw:
			b.add_theme_stylebox_override("normal", UI.style(UI.PANEL3, 46, UI.ACCENT, 4))
			b.add_theme_color_override("font_color", UI.ACCENT)
		elif i > _next_screw:
			b.add_theme_stylebox_override("normal", UI.style(UI.PANEL3, 46, UI.LINE, 3))
			b.add_theme_color_override("font_color", UI.TEXT)


func _tap_screw(index: int, button: Button) -> void:
	if index != _next_screw:
		_damage += 1
		_damage_lbl.text = "Повреждения: %d" % _damage
		_hint.text = "Не этот винт: сначала подсвеченный %d" % (_next_screw + 1)
		var tw := create_tween()
		tw.tween_property(button, "position:x", button.position.x + 8, 0.05)
		tw.tween_property(button, "position:x", button.position.x - 8, 0.05)
		tw.tween_property(button, "position:x", button.position.x, 0.05)
		return

	button.disabled = true
	button.text = "OK"
	button.modulate = Color(1, 1, 1, 0.35)
	_next_screw += 1

	if _next_screw >= _order.phone.screws:
		_stage = 1
		_build_module_stage()
	else:
		_highlight_next()
		_hint.text = "Винт %d из %d откручен" % [_next_screw, _order.phone.screws]
	_update_stage_ui()


# ------------------------------------------------------------ модуль ---

func _build_module_stage() -> void:
	for b in _screw_buttons:
		b.queue_free()
	_screw_buttons.clear()

	# Залитие: вместо замены модуля — чистка платы
	if _order.fault.needs_cleaning and _order.quality == null:
		_build_cleaning_stage()
		return
	if _order.fault.id == "port":
		_build_soldering_stage()
		return

	_socket = PanelContainer.new()
	_socket.custom_minimum_size = Vector2(230, 230)
	_socket.size = Vector2(230, 230)
	_socket.position = (PHONE_SIZE - _socket.size) * 0.5 - Vector2(0, 40)
	_socket.add_theme_stylebox_override("panel", UI.style(Color("#0a1018"), 26, UI.ACCENT, 3))
	_phone_area.add_child(_socket)

	var socket_hint := UI.label("ГНЕЗДО", 22, UI.ACCENT)
	socket_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	socket_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_socket.add_child(socket_hint)

	var tray := PanelContainer.new()
	tray.add_theme_stylebox_override("panel", UI.style(UI.PANEL2, 24, UI.LINE, 2))
	tray.position = Vector2(60, PHONE_SIZE.y - 230)
	tray.size = Vector2(PHONE_SIZE.x - 120, 160)
	_phone_area.add_child(tray)

	var tray_row := HBoxContainer.new()
	tray_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tray.add_child(tray_row)

	_module = PanelContainer.new()
	_module.custom_minimum_size = Vector2(150, 150)
	_module.size = Vector2(150, 150)
	_module.add_theme_stylebox_override("panel", UI.style(_order.fault.color.darkened(0.5), 22, _order.fault.color, 3))
	_phone_area.add_child(_module)

	var letter := UI.label(_order.fault.badge, 52, _order.fault.color)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_module.add_child(letter)

	# Деталь стартует поверх лотка
	_module.position = Vector2(
		(PHONE_SIZE.x - _module.size.x) * 0.5,
		PHONE_SIZE.y - 225
	)

	_hint.text = "Перетащите деталь в гнездо"


func _build_cleaning_stage() -> void:
	_spots_left = 6
	var spots := [
		Vector2(70, 90), Vector2(300, 70), Vector2(180, 220),
		Vector2(60, 380), Vector2(320, 360), Vector2(200, 500),
	]
	for i in spots.size():
		var spot := Button.new()
		spot.text = "грязь"
		spot.custom_minimum_size = Vector2(120, 120)
		spot.size = Vector2(120, 120)
		spot.position = spots[i]
		spot.focus_mode = Control.FOCUS_NONE
		spot.add_theme_font_size_override("font_size", 22)
		spot.add_theme_color_override("font_color", Color("#8a6a3a"))
		spot.add_theme_stylebox_override("normal", UI.style(Color("#4a3a24"), 60, Color("#8a6a3a"), 4))
		spot.add_theme_stylebox_override("hover", UI.style(Color("#4a3a24"), 60, Color("#8a6a3a"), 4))
		spot.add_theme_stylebox_override("pressed", UI.style(Color("#2e2416"), 60, UI.ACCENT, 4))
		spot.pressed.connect(_clean_spot.bind(spot))
		_phone_area.add_child(spot)

	_hint.text = "Очистите плату от окисла: 6 пятен"


func _clean_spot(spot: Button) -> void:
	if spot.modulate.a < 0.4:
		return
	spot.modulate.a = maxf(0.25, spot.modulate.a - 0.5)
	if spot.modulate.a <= 0.3:
		spot.disabled = true
		_spots_left -= 1
		_hint.text = "Осталось пятен: %d" % _spots_left
		if _spots_left <= 0:
			_hint.text = "Плата чистая"
			_stage = 2
			_update_stage_ui()
	else:
		_hint.text = "Ещё раз по этому пятну"


func _build_soldering_stage() -> void:
	_soldered = 0
	var pads := [
		Vector2(110, 250), Vector2(210, 250), Vector2(310, 250), Vector2(210, 350),
	]
	for i in pads.size():
		var pad := Button.new()
		pad.text = "0%"
		pad.custom_minimum_size = Vector2(80, 80)
		pad.size = Vector2(80, 80)
		pad.position = pads[i] - Vector2(40, 40)
		pad.focus_mode = Control.FOCUS_NONE
		pad.add_theme_font_size_override("font_size", 20)
		pad.add_theme_stylebox_override("normal", UI.style(Color("#5a3a1a"), 40, Color("#c98a3a"), 4))
		pad.add_theme_stylebox_override("hover", UI.style(Color("#5a3a1a"), 40, Color("#c98a3a"), 4))
		pad.add_theme_stylebox_override("pressed", UI.style(Color("#7a4a1a"), 40, UI.WARN, 5))
		pad.button_down.connect(_start_solder.bind(pad))
		pad.button_up.connect(_stop_solder)
		_phone_area.add_child(pad)

	_hint.text = "Прогрейте 4 контакта: держите палец до 100%"


func _start_solder(pad: Button) -> void:
	if pad.disabled:
		return
	_solder_btn = pad
	_solder_progress = 0.0


func _stop_solder() -> void:
	if _solder_btn != null and not _solder_btn.disabled:
		_solder_btn.text = "0%"
	_solder_btn = null
	_solder_progress = 0.0


func _process(delta: float) -> void:
	if _solder_btn == null or _stage != 1:
		return
	_solder_progress = minf(1.0, _solder_progress + delta / 0.7)
	_solder_btn.text = "%d%%" % int(round(_solder_progress * 100))
	if _solder_progress >= 1.0:
		_solder_btn.disabled = true
		_solder_btn.text = "OK"
		_solder_btn = null
		_soldered += 1
		_hint.text = "Припаяно %d из 4" % _soldered
		if _soldered >= 4:
			_hint.text = "Разъём припаян"
			_stage = 2
			_update_stage_ui()


func _input(event: InputEvent) -> void:
	if _stage != 1 or _module == null or _module_placed:
		return

	# Мышь (десктоп/эмулятор)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _module.get_global_rect().has_point(event.position):
				_dragging = true
				_drag_offset = _module.global_position - event.position
		elif _dragging:
			_dragging = false
			_try_snap()
		return

	if event is InputEventMouseMotion and _dragging:
		_module.global_position = event.position + _drag_offset
		return

	# Палец (Android/iOS)
	if event is InputEventScreenTouch:
		if event.pressed:
			if _module.get_global_rect().has_point(event.position):
				_dragging = true
				_drag_offset = _module.global_position - event.position
		elif _dragging:
			_dragging = false
			_try_snap()
		return

	if event is InputEventScreenDrag and _dragging:
		_module.global_position = event.position + _drag_offset


func _try_snap() -> void:
	var module_center := _module.get_global_rect().get_center()
	var socket_center := _socket.get_global_rect().get_center()

	if module_center.distance_to(socket_center) <= 130.0:
		_module_placed = true
		var tw := create_tween()
		tw.tween_property(_module, "global_position", _socket.global_position + (_socket.size - _module.size) * 0.5, 0.12)
		_hint.text = "Модуль на месте"
		_stage = 2
		_update_stage_ui()
	else:
		var tw := create_tween()
		tw.tween_property(_module, "position", Vector2((PHONE_SIZE.x - _module.size.x) * 0.5, PHONE_SIZE.y - 225), 0.18)
		_hint.text = "Мимо гнезда — попробуйте ещё раз"


# ------------------------------------------------------------ проверка ---

func _update_stage_ui() -> void:
	match _stage:
		0:
			_stage_label.text = "ШАГ 1 ИЗ 3 · РАЗБОРКА"
			_action.text = "Открутите винты по порядку"
			_action.disabled = true
		1:
			if _order.fault.needs_cleaning and _order.quality == null:
				_stage_label.text = "ШАГ 2 ИЗ 3 · ЧИСТКА"
				_action.text = "Очистите плату"
			elif _order.fault.id == "port":
				_stage_label.text = "ШАГ 2 ИЗ 3 · ПАЙКА"
				_action.text = "Припаяйте 4 контакта"
			else:
				_stage_label.text = "ШАГ 2 ИЗ 3 · ЗАМЕНА МОДУЛЯ"
				_action.text = "Установите модуль в гнездо"
			_action.disabled = true
		_:
			_stage_label.text = "ШАГ 3 ИЗ 3 · ПРОВЕРКА"
			_action.text = "Проверить телефон"
			_action.disabled = false
			var chance := _success_chance()
			_hint.text = "Шанс успеха: %d%%" % int(round(chance * 100))


func _success_chance() -> float:
	var chance := Econ.success_chance(_order, Game.upgrades)
	chance -= float(_damage) * 0.02
	return clampf(chance, 0.2, 0.995)


func _on_action() -> void:
	if _stage != 2:
		return
	var chance := _success_chance()
	var success := randf() < chance
	var report := Game.finish_order(success)
	_show_result(report)


func _show_result(report: Dictionary) -> void:
	_action.disabled = true

	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.03, 0.04, 0.88)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := UI.card(28, UI.PANEL)
	card.custom_minimum_size = Vector2(600, 0)
	center.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	var ok := bool(report.get("success", false)) and not bool(report.get("scam", false))
	var title := UI.bold("ГОТОВО" if ok else "НЕ ВЫШЛО", 42, UI.ACCENT if ok else UI.DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var review := UI.label(String(report.get("review", "")), 26, UI.TEXT)
	review.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	review.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(review)

	v.add_child(UI.divider())

	v.add_child(_result_row("Оплата", UI.money(int(report.get("paid", 0))), UI.ACCENT))
	v.add_child(_result_row("Репутация", "%+d" % int(report.get("rep", 0)), UI.ACCENT if int(report.get("rep", 0)) >= 0 else UI.DANGER))
	v.add_child(_result_row("Опыт", "+%d" % int(report.get("xp", 0)), UI.BLUE))

	if bool(report.get("scam", false)):
		var scam := UI.caption("Клиент потребовал возврат — оплаты не будет", UI.DANGER)
		scam.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(scam)

	var cont := UI.button("Продолжить", true, 96, 30)
	cont.pressed.connect(_to_workshop)
	v.add_child(cont)


func _result_row(label_text: String, value: String, color: Color) -> Control:
	var h := HBoxContainer.new()
	var l := UI.label(label_text, 26, UI.DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UI.bold(value, 28, color))
	return h


func _to_workshop() -> void:
	Router.go("workshop")