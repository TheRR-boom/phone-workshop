extends Control
## Витрина: три слота под восстановленные телефоны + лоты «битых» устройств.
## Купил битый → восстановил (нужна запчасть) → выставил цену → продал.

var _slots_box: VBoxContainer
var _lots_box: VBoxContainer
var _count_lbl: Label
## Ссылки на подписи цен/шанса, чтобы обновлять их без пересборки экрана
var _price_labels: Dictionary = {}
var _chance_labels: Dictionary = {}


func _ready() -> void:
	theme = UI.theme()
	_build()
	Game.showcase_changed.connect(_refresh)
	_refresh()


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

	root.add_child(TopBar.new())

	var head := HBoxContainer.new()
	var title := UI.bold("ВИТРИНА", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_count_lbl = UI.caption("0 / 3", UI.DIM)
	head.add_child(_count_lbl)
	root.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)

	_slots_box = VBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 12)
	col.add_child(_slots_box)

	col.add_child(UI.bold("БИТЫЕ ТЕЛЕФОНЫ", 26, UI.DIM))
	_lots_box = VBoxContainer.new()
	_lots_box.add_theme_constant_override("separation", 12)
	col.add_child(_lots_box)

	root.add_child(NavBar.new())


func _refresh() -> void:
	if _slots_box == null:
		return
	_count_lbl.text = "%d / %d" % [Game.showcase.size(), Game.MAX_SHOWCASE]

	for c in _slots_box.get_children():
		c.queue_free()
	for c in _lots_box.get_children():
		c.queue_free()

	_price_labels.clear()
	_chance_labels.clear()

	for i in Game.MAX_SHOWCASE:
		if i < Game.showcase.size():
			_slots_box.add_child(_slot_card(i))
		else:
			_slots_box.add_child(_empty_slot())

	for i in Game.lots.size():
		_lots_box.add_child(_lot_card(i))

	if Game.lots.is_empty():
		_lots_box.add_child(UI.caption("Сегодня битых телефонов нет"))


func _empty_slot() -> Control:
	var card := UI.card(22)
	card.custom_minimum_size = Vector2(0, 120)
	var v := VBoxContainer.new()
	v.add_child(UI.caption("Свободный слот", UI.FAINT))
	v.add_child(UI.caption("Купите битый телефон ниже", UI.FAINT))
	card.add_child(v)
	return card


func _slot_card(index: int) -> Control:
	var item: Dictionary = Game.showcase[index]
	var phone: PhoneModel = DB.phone(String(item["phone_id"]))
	var fault: Fault = DB.fault(String(item["fault_id"]))
	var ready := bool(item["ready"])

	var card := UI.card(24, Color("#123027") if ready else UI.PANEL)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(UI.badge(fault.badge, fault.color, 72))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UI.bold(phone.title, 28))
	tv.add_child(UI.caption(fault.title, UI.DIM))
	head.add_child(tv)
	head.add_child(UI.pill("готов" if ready else "битый", UI.ACCENT if ready else UI.WARN, 22))
	v.add_child(head)

	if not ready:
		var need := UI.caption("Нужна запчасть: %s (%s)" % [fault.part_name(), Catalog.tier_title(phone.tier)], UI.DIM)
		v.add_child(need)
		var btn := UI.button("Восстановить", false, 88, 26)
		btn.pressed.connect(_restore.bind(index))
		v.add_child(btn)
		return card

	var price: int = int(item.get("price", int(round(phone.base_value * 0.85))))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var slider := HSlider.new()
	slider.min_value = int(round(phone.base_value * 0.5))
	slider.max_value = int(round(phone.base_value * 1.3))
	slider.step = 50
	slider.value = price
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 60)
	slider.value_changed.connect(_on_price.bind(index))
	row.add_child(slider)
	var price_lbl := UI.bold(UI.money(price), 28, UI.ACCENT)
	price_lbl.custom_minimum_size = Vector2(170, 0)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price_lbl)
	v.add_child(row)

	var chance := Econ.sale_chance(price, phone.base_value, Game.rep, Game.upgrades)
	var chance_lbl := UI.caption("Шанс продажи сегодня: %d%%" % int(round(chance * 100)), UI.FAINT)
	v.add_child(chance_lbl)

	_price_labels[index] = price_lbl
	_chance_labels[index] = chance_lbl

	var sell := UI.button("Продать", true, 88, 28)
	sell.pressed.connect(_sell.bind(index))
	v.add_child(sell)
	return card


func _lot_card(index: int) -> Control:
	var lot: Dictionary = Game.lots[index]
	var phone: PhoneModel = DB.phone(String(lot["phone_id"]))
	var fault: Fault = DB.fault(String(lot["fault_id"]))
	var price := int(lot["price"])

	var card := UI.card(22)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)

	h.add_child(UI.badge(fault.badge, fault.color, 70))

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.bold(phone.title, 26))
	v.add_child(UI.caption("%s · %s" % [fault.title, Catalog.tier_title(phone.tier)], UI.DIM))
	h.add_child(v)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	var price_lbl := UI.bold(UI.money(price), 26)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(price_lbl)
	var buy := UI.button("Купить", false, 88, 22)
	buy.custom_minimum_size = Vector2(150, 88)
	buy.disabled = Game.money < price
	buy.pressed.connect(_buy_lot.bind(index))
	right.add_child(buy)
	h.add_child(right)
	return card


func _buy_lot(index: int) -> void:
	if Game.buy_lot(index):
		Game.toast("Телефон на витрине")


func _restore(index: int) -> void:
	if Game.restore_showcase(index):
		Game.toast("Телефон восстановлен")
	else:
		Game.toast("Не хватает запчасти")


func _sell(index: int) -> void:
	var item: Dictionary = Game.showcase[index]
	var report := Game.sell_showcase(index, int(item.get("price", 0)))
	if bool(report.get("sold", false)):
		Game.toast("Продан за %s" % UI.money(int(report.get("price", 0))))
	else:
		Game.toast("Пока никто не купил (шанс %d%%)" % int(round(float(report.get("chance", 0)) * 100)))


func _on_price(value: float, index: int) -> void:
	if index >= Game.showcase.size():
		return
	Game.showcase[index]["price"] = int(value)
	var phone: PhoneModel = DB.phone(String(Game.showcase[index]["phone_id"]))
	if _price_labels.has(index):
		(_price_labels[index] as Label).text = UI.money(int(value))
	if _chance_labels.has(index):
		var chance := Econ.sale_chance(int(value), phone.base_value, Game.rep, Game.upgrades)
		(_chance_labels[index] as Label).text = "Шанс продажи сегодня: %d%%" % int(round(chance * 100))
