extends Control
## Экран заказа: жалоба клиента → диагноз → запчасть → цена → старт ремонта.
##
## Три решения игрока (диагноз, качество детали, цена) и есть основная
## «головоломка» экономики: дешёвая деталь повышает шанс возврата клиента,
## а высокая цена может отпугнуть.

var _order: Order
var _diagnosed := false
var _attempts := 0
var _quality_id := ""
var _price := 0
var _ceiling := 0
var _min_price := 0
var _max_price := 0

var _diag_grid: GridContainer
var _diag_hint: Label
var _parts_section: VBoxContainer
var _price_section: VBoxContainer
var _price_label: Label
var _reaction: Label
var _start_btn: Button
var _slider: HSlider


func _ready() -> void:
	theme = UI.theme()
	_order = Game.pending_order
	if _order == null:
		Router.go("workshop")
		return
	_build()


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

	root.add_child(_header())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 16)
	scroll.add_child(col)

	col.add_child(_client_card())
	col.add_child(_diagnosis_block())
	col.add_child(_parts_block())
	col.add_child(_price_block())

	root.add_child(_footer())


func _header() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)

	var back := UI.button("Назад", false, 88, 28)
	back.custom_minimum_size = Vector2(150, 88)
	back.pressed.connect(_on_back)
	h.add_child(back)

	var title := UI.bold("ЗАКАЗ", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(title)
	return h


func _client_card() -> Control:
	var card := UI.card()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	card.add_child(h)

	h.add_child(UI.badge(_order.fault.badge, _order.fault.color, 110))

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(UI.bold(_order.client_name, 32))
	top.add_child(UI.pill(_order.client_type.title, _order.client_type.color))
	v.add_child(top)

	v.add_child(UI.caption("%s · %s" % [_order.phone.title, _order.phone.tier_name()], UI.TEXT))

	var symptom := UI.label(_order.fault.symptom, 25, UI.DIM)
	symptom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(symptom)

	var mood := UI.caption(_order.client_type.description, _order.client_type.color)
	v.add_child(mood)
	h.add_child(v)
	return card


func _section_title(text: String) -> Control:
	var l := UI.bold(text, 26, UI.DIM)
	return l


func _diagnosis_block() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(_section_title("ДИАГНОЗ · что меняем?"))

	_diag_grid = GridContainer.new()
	_diag_grid.columns = 2
	_diag_grid.add_theme_constant_override("h_separation", 10)
	_diag_grid.add_theme_constant_override("v_separation", 10)
	v.add_child(_diag_grid)

	for fault in DB.faults:
		var b := UI.button("%s  %s" % [fault.badge, fault.title], false, 92, 25)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_pick_fault.bind(fault, b))
		_diag_grid.add_child(b)

	_diag_hint = UI.caption("Подсказка в жалобе клиента", UI.FAINT)
	v.add_child(_diag_hint)
	return v


func _pick_fault(fault: Fault, button: Button) -> void:
	if _diagnosed:
		return

	if fault.id == _order.fault.id:
		_diagnosed = true
		_diag_hint.text = "Верно: %s" % fault.title
		_diag_hint.add_theme_color_override("font_color", UI.ACCENT)
		for b in _diag_grid.get_children():
			b.disabled = true
		button.add_theme_stylebox_override("disabled", UI.style(Color("#123027"), 22, UI.ACCENT, 2))
		_parts_section.visible = true
		call_deferred("_rebuild_parts")
		return

	_attempts += 1
	button.disabled = true
	button.text = "Мимо"
	Game.add_rep(-1.0 * _order.client_type.rep_mul)

	if _attempts >= 2:
		_diag_hint.text = "Клиент забрал телефон и ушёл"
		_diag_hint.add_theme_color_override("font_color", UI.DANGER)
		Game.decline_order(_order)
		Game.pending_order = null
		await get_tree().create_timer(0.6).timeout
		Router.go("workshop")
	else:
		_diag_hint.text = "Не похоже. Осталась одна попытка"
		_diag_hint.add_theme_color_override("font_color", UI.WARN)


func _parts_block() -> Control:
	_parts_section = VBoxContainer.new()
	_parts_section.add_theme_constant_override("separation", 10)
	_parts_section.visible = false
	return _parts_section


func _rebuild_parts() -> void:
	for child in _parts_section.get_children():
		child.queue_free()

	_parts_section.add_child(_section_title("ЗАПЧАСТЬ"))

	if _order.fault.needs_cleaning:
		_parts_section.add_child(_cleaning_row())
		_price_section.visible = true
		_build_price()
		return

	var any_stock := false
	for quality in DB.qualities:
		var stock := Game.count_part(_order.fault.part_type, quality.id, _order.phone.tier)
		if stock > 0:
			any_stock = true
		_parts_section.add_child(_part_row(quality, stock))

	if not any_stock:
		_parts_section.add_child(UI.caption("Нет запчастей этого класса — купите в магазине", UI.WARN))

	_price_section.visible = true
	_build_price()


func _cleaning_row() -> Control:
	var card := UI.card(24, Color("#123027"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	card.add_child(h)

	h.add_child(UI.badge("Ч", UI.BLUE, 80))

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.bold("Чистка ультразвуком", 28))
	v.add_child(UI.caption("Разборка, промывка платы, сушка", UI.DIM))
	h.add_child(v)

	var p := UI.pill("выбрано", UI.ACCENT)
	h.add_child(p)
	_quality_id = ""
	return card


func _part_row(quality: PartQuality, stock: int) -> Control:
	var selected := quality.id == _quality_id
	var card := UI.card(24, Color("#123027") if selected else UI.PANEL)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	card.add_child(h)

	h.add_child(UI.badge(quality.title.substr(0, 1), quality.color, 80))

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	v.add_child(UI.bold(quality.title, 28))
	v.add_child(UI.caption("Гарантия %s · надёжность %d%%" % [quality.warranty_text(), int(quality.reliability * 100)], UI.DIM))
	v.add_child(UI.caption("На складе: %d" % stock, UI.ACCENT if stock > 0 else UI.DANGER))
	h.add_child(v)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	var cost := Catalog.part_cost(_order.fault.part_type, _order.phone.tier, quality.id)
	var price_lbl := UI.bold(UI.money(cost), 28)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(price_lbl)

	var btn := UI.button("Выбрано" if selected else "Выбрать", selected, 88, 24)
	btn.custom_minimum_size = Vector2(160, 88)
	btn.disabled = stock <= 0
	btn.pressed.connect(_choose_quality.bind(quality.id))
	right.add_child(btn)
	h.add_child(right)
	return card


func _choose_quality(quality_id: String) -> void:
	_quality_id = quality_id
	call_deferred("_rebuild_parts")


func _price_block() -> Control:
	_price_section = VBoxContainer.new()
	_price_section.add_theme_constant_override("separation", 10)
	_price_section.visible = false
	return _price_section


func _build_price() -> void:
	for child in _price_section.get_children():
		child.queue_free()

	_ceiling = Econ.client_ceiling(_order.phone, _order.fault, _order.client_type, Game.rep)
	var cost := Econ.cost_price(_order.phone, _order.fault, _quality_id)

	_min_price = maxi(int(round(cost * 0.9)), 100)
	_max_price = maxi(int(round(_ceiling * 1.2)), _min_price + 100)
	# Стартовая цена обязана проходить: иначе игрок видит заблокированную
	# кнопку ещё до того, как успел что-то выбрать.
	var suggested := mini(
		Econ.suggested_price(_order.phone, _order.fault, Game.rep),
		int(round(_ceiling * 0.95))
	)
	_price = clampi(suggested, _min_price, _max_price)

	_price_section.add_child(_section_title("ЦЕНА РАБОТЫ"))

	var card := UI.card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	_price_label = UI.bold(UI.money(_price), 40, UI.ACCENT)
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_price_label)

	_slider = HSlider.new()
	_slider.min_value = _min_price
	_slider.max_value = _max_price
	_slider.step = 50
	_slider.value = _price
	_slider.custom_minimum_size = Vector2(0, 64)
	_slider.value_changed.connect(_on_price_changed)
	v.add_child(_slider)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var cost_lbl := UI.caption("Себестоимость %s" % UI.money(cost), UI.DIM)
	cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cost_lbl)
	row.add_child(UI.caption("Прибыль %s" % UI.money(_price - cost), UI.DIM))
	v.add_child(row)

	_reaction = UI.label("", 26, UI.ACCENT)
	_reaction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_reaction)

	_price_section.add_child(card)

	_update_price_texts()
	_update_start_state()


func _on_price_changed(value: float) -> void:
	_price = int(value)
	_update_price_texts()
	_update_start_state()


func _update_price_texts() -> void:
	if _price_label == null:
		return
	_price_label.text = UI.money(_price)
	var r := Econ.reaction(_price, _ceiling)
	_reaction.text = String(r["text"])
	_reaction.add_theme_color_override("font_color", r["color"])

	var cost := Econ.cost_price(_order.phone, _order.fault, _quality_id)
	var profit := _price - cost
	# Обновляем подпись прибыли (последний Label в строке)
	if _price_section.get_child_count() > 0:
		var card: Node = _price_section.get_child(_price_section.get_child_count() - 1)
		for n in card.find_children("*", "Label", true, false):
			if String(n.text).begins_with("Прибыль"):
				n.text = "Прибыль %s" % UI.money(profit)


func _update_start_state() -> void:
	if _start_btn == null:
		return
	var ready_to_go := _diagnosed and (_quality_id != "" or _order.fault.needs_cleaning)
	var fits := _price <= _ceiling
	_start_btn.disabled = not (ready_to_go and fits)
	if not ready_to_go:
		_start_btn.text = "Сначала диагноз и запчасть"
	elif not fits:
		_start_btn.text = "Дорого для клиента"
	else:
		_start_btn.text = "Начать ремонт"


func _footer() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)

	_start_btn = UI.button("Сначала диагноз и запчасть", true, 96, 30)
	_start_btn.disabled = true
	_start_btn.pressed.connect(_on_start)
	v.add_child(_start_btn)

	var decline := UI.button("Отказать клиенту", false, 88, 26)
	decline.pressed.connect(_on_decline)
	v.add_child(decline)
	return v


func _on_start() -> void:
	if not Game.accept_order(_order, _quality_id, _price):
		return
	Game.pending_order = null
	Router.go("repair")


func _on_decline() -> void:
	Game.decline_order(_order)
	Game.pending_order = null
	Router.go("workshop")


func _on_back() -> void:
	Game.pending_order = null
	Router.go("workshop")