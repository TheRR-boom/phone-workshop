extends Control
## Склад: что лежит в мастерской по классам устройств.
## Игрок видит, на что хватает запчастей, и сколько это стоит.

func _ready() -> void:
	theme = UI.theme()
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
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	root.add_child(TopBar.new())

	var head := HBoxContainer.new()
	var title := UI.bold("СКЛАД", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UI.caption("запчасти по классам"))
	root.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)

	if Game.inventory.is_empty():
		col.add_child(UI.caption("Склад пуст. Купите запчасти в магазине."))
	else:
		for tier in 3:
			var rows := _rows_for_tier(tier)
			if rows.is_empty():
				continue
			col.add_child(UI.bold(Catalog.tier_title(tier).to_upper(), 26, UI.DIM))
			for r in rows:
				col.add_child(r)

	root.add_child(NavBar.new())


func _rows_for_tier(tier: int) -> Array[Control]:
	var rows: Array[Control] = []
	for part_type in ["screen", "battery", "port", "speaker"]:
		for quality in DB.qualities:
			var key := Game.part_key(part_type, quality.id, tier)
			var count := int(Game.inventory.get(key, 0))
			if count <= 0:
				continue
			rows.append(_row(part_type, quality, tier, count))
	return rows


func _row(part_type: String, quality: PartQuality, tier: int, count: int) -> Control:
	var card := UI.card(22)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	card.add_child(h)

	h.add_child(UI.badge(Catalog.part_badge(part_type), Catalog.part_color(part_type), 76))

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	v.add_child(UI.bold("%s · %s" % [Catalog.part_title(part_type), quality.title], 28))
	v.add_child(UI.caption("Гарантия %s" % quality.warranty_text(), UI.DIM))
	h.add_child(v)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	var count_lbl := UI.bold("×%d" % count, 32, UI.ACCENT)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(count_lbl)
	var value := Catalog.part_cost(part_type, tier, quality.id)
	var val_lbl := UI.caption(UI.money(value), UI.FAINT)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(val_lbl)
	h.add_child(right)
	return card