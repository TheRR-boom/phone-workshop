extends Control
## Магазин: запчасти (по классам устройств) и улучшения мастерской.
## Покупки сразу влияют на шанс ремонта и поток клиентов.

var _tab := "parts"
var _tier := 0
var _content: VBoxContainer


func _ready() -> void:
	theme = UI.theme()
	_build()
	Game.money_changed.connect(_on_money)
	Game.inventory_changed.connect(_refresh)


func _on_money(_v: int) -> void:
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
	var title := UI.bold("МАГАЗИН", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	root.add_child(head)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	var parts_btn := UI.button("Запчасти", _tab == "parts", 88, 28)
	parts_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts_btn.pressed.connect(_set_tab.bind("parts"))
	tabs.add_child(parts_btn)
	var up_btn := UI.button("Улучшения", _tab == "upgrades", 88, 28)
	up_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up_btn.pressed.connect(_set_tab.bind("upgrades"))
	tabs.add_child(up_btn)
	root.add_child(tabs)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)

	root.add_child(NavBar.new())

	_refresh()


func _set_tab(tab: String) -> void:
	_tab = tab
	_build_content()


func _refresh() -> void:
	_build_content()


func _build_content() -> void:
	if _content == null:
		return
	for c in _content.get_children():
		c.queue_free()

	if _tab == "parts":
		_build_parts()
	else:
		_build_upgrades()


func _build_parts() -> void:
	var tiers := HBoxContainer.new()
	tiers.add_theme_constant_override("separation", 8)
	for t in 3:
		var b := UI.button(Catalog.tier_title(t), t == _tier, 88, 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_tier.bind(t))
		tiers.add_child(b)
	_content.add_child(tiers)

	for part_type in ["screen", "battery", "port", "speaker"]:
		_content.add_child(UI.bold(Catalog.part_title(part_type).to_upper(), 24, UI.DIM))
		for quality in DB.qualities:
			_content.add_child(_part_row(part_type, quality))


func _part_row(part_type: String, quality: PartQuality) -> Control:
	var card := UI.card(22)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)

	h.add_child(UI.badge(Catalog.part_badge(part_type), Catalog.part_color(part_type), 70))

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	v.add_child(UI.bold(quality.title, 26))
	var stock := Game.count_part(part_type, quality.id, _tier)
	v.add_child(UI.caption("на складе %d · гарантия %s" % [stock, quality.warranty_text()], UI.DIM))
	h.add_child(v)

	var cost := Catalog.part_cost(part_type, _tier, quality.id)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	var price_lbl := UI.bold(UI.money(cost), 26)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(price_lbl)
	var buy := UI.button("Купить", false, 88, 22)
	buy.custom_minimum_size = Vector2(150, 88)
	buy.disabled = Game.money < cost
	buy.pressed.connect(_buy_part.bind(part_type, quality.id))
	right.add_child(buy)
	h.add_child(right)
	return card


func _buy_part(part_type: String, quality_id: String) -> void:
	if Game.buy_part(part_type, quality_id, _tier):
		Game.toast("Куплено: %s · %s" % [Catalog.part_title(part_type), DB.quality(quality_id).title])


func _set_tier(tier: int) -> void:
	_tier = tier
	_build_content()


func _build_upgrades() -> void:
	for u in DB.upgrades:
		var id := String(u["id"])
		var owned := Game.upgrades.has(id)
		var card := UI.card(24, Color("#123027") if owned else UI.PANEL)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		card.add_child(v)

		var head := HBoxContainer.new()
		var title := UI.bold(String(u["title"]), 28)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		head.add_child(UI.pill("куплено" if owned else String(u["bonus"]), UI.ACCENT if owned else UI.WARN, 22))
		v.add_child(head)

		var desc := UI.caption(String(u["desc"]), UI.DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(desc)

		if not owned:
			var price := int(u["price"])
			var btn := UI.button("Купить за %s" % UI.money(price), false, 88, 24)
			btn.disabled = Game.money < price
			btn.pressed.connect(_buy_upgrade.bind(id))
			v.add_child(btn)

		_content.add_child(card)


func _buy_upgrade(id: String) -> void:
	if Game.buy_upgrade(id):
		Game.toast("Улучшение куплено")
		_build_content()