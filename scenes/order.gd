extends Control
## Экран приёма заказа.
##
## Здесь НЕТ выбора неисправности из списка — только жалоба клиента и
## устройство. Диагноз ставится после реальной разборки на экране teardown.

var _order: Order


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

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	var back := UI.button("Назад", false, 88, 28)
	back.custom_minimum_size = Vector2(150, 88)
	back.pressed.connect(_on_back)
	head.add_child(back)
	var title := UI.bold("ПРИЁМ", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	root.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 16)
	scroll.add_child(col)

	col.add_child(_client_card())
	col.add_child(_hint_card())

	root.add_child(_footer())


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

	var complaint := UI.label(_order.complaint(), 26, UI.DIM)
	complaint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(complaint)

	v.add_child(UI.caption(_order.client_type.description, _order.client_type.color))
	h.add_child(v)
	return card


func _hint_card() -> Control:
	var card := UI.card(24, Color("#14202b"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	v.add_child(UI.bold("Что дальше", 26))
	var text := UI.caption(
		"Клиент оставляет телефон. Разберите его, найдите причину и подтвердите диагноз — только потом обсуждаем цену.",
		UI.DIM
	)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(text)
	v.add_child(UI.caption("Диагностика бесплатная, но ошибка стоит репутации", UI.FAINT))
	return card


func _footer() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)

	var accept := UI.button("Принять на диагностику", true, 96, 28)
	accept.pressed.connect(_on_accept)
	v.add_child(accept)

	var decline := UI.button("Отказать клиенту", false, 88, 26)
	decline.pressed.connect(_on_decline)
	v.add_child(decline)
	return v


func _on_accept() -> void:
	if not Game.accept_for_diagnosis(_order):
		return
	Game.pending_order = null
	Router.go("teardown")


func _on_decline() -> void:
	Game.decline_order(_order)
	Game.pending_order = null
	Router.go("workshop")


func _on_back() -> void:
	Game.pending_order = null
	Router.go("workshop")