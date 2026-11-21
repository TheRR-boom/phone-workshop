extends Control
## Мастерская — хаб игры. Здесь очередь клиентов, деньги и вход во все разделы.
## Экран полностью собирается из состояния Game, поэтому сохранение/загрузка
## и смена дня восстанавливают его без ручной синхронизации.

var _queue: VBoxContainer
var _close_btn: Button
var _confirm_close := false
var _confirm_timer: Timer


func _ready() -> void:
	theme = UI.theme()
	_build()

	Game.clients_changed.connect(_refresh_queue)
	_refresh_queue()


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
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	root.add_child(TopBar.new())

	var head := HBoxContainer.new()
	var title := UI.bold("ОЧЕРЕДЬ", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var hint := UI.caption("%d клиент(ов)" % Game.clients.size())
	head.add_child(hint)
	root.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_queue = VBoxContainer.new()
	_queue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue.add_theme_constant_override("separation", 14)
	scroll.add_child(_queue)

	_close_btn = UI.button("Закрыть день", false, 92, 30)
	_close_btn.pressed.connect(_on_close_day)
	root.add_child(_close_btn)

	root.add_child(NavBar.new())

	_confirm_timer = Timer.new()
	_confirm_timer.one_shot = true
	_confirm_timer.wait_time = 3.0
	_confirm_timer.timeout.connect(_reset_confirm)
	add_child(_confirm_timer)


func _refresh_queue() -> void:
	if _queue == null:
		return
	for child in _queue.get_children():
		child.queue_free()

	if Game.clients.is_empty():
		var empty := UI.card()
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		v.add_child(UI.bold("Клиентов нет", 32))
		v.add_child(UI.caption("Закройте день — завтра придут новые"))
		empty.add_child(v)
		_queue.add_child(empty)
		return

	for order in Game.clients:
		_queue.add_child(_client_card(order))


func _client_card(order: Order) -> Control:
	var card := UI.card()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	card.add_child(h)

	h.add_child(UI.badge(order.fault.badge, order.fault.color, 100))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(UI.bold(order.client_name, 30))
	var pill := UI.pill(order.client_type.title, order.client_type.color)
	top.add_child(pill)
	info.add_child(top)

	info.add_child(UI.caption("%s · %s" % [order.phone.title, order.fault.title], UI.TEXT))

	var symptom := UI.label(order.fault.symptom, 23, UI.DIM)
	symptom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(symptom)

	h.add_child(info)

	var btn := UI.button("Принять", false, 88, 26)
	btn.custom_minimum_size = Vector2(176, 88)
	btn.pressed.connect(_open_order.bind(order))
	h.add_child(btn)

	return card


func _open_order(order: Order) -> void:
	Game.pending_order = order
	Router.go("order")


func _on_close_day() -> void:
	if not _confirm_close:
		_confirm_close = true
		_close_btn.text = "Точно закрыть? Клиенты уйдут"
		_confirm_timer.start()
		return

	var report := Game.close_day()
	_reset_confirm()
	Game.toast("День %d · аренда −%s" % [report["day"], UI.money(int(report["rent"]))])
	_refresh_queue()


func _reset_confirm() -> void:
	_confirm_close = false
	if _close_btn:
		_close_btn.text = "Закрыть день"