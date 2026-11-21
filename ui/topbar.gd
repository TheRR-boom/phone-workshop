class_name TopBar
extends PanelContainer
## Верхняя панель: день, деньги, репутация, уровень.
## Слушает сигналы Game и обновляется сама — экранам не нужно об этом думать.

var _day: Label
var _money: Label
var _rep: Label


func _ready() -> void:
	custom_minimum_size = Vector2(0, 150)
	add_theme_stylebox_override("panel", UI.style(UI.PANEL, 24, UI.LINE, 2))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	add_child(h)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	_day = UI.bold("День 1", 34)
	left.add_child(_day)
	left.add_child(UI.caption("Мастерская «Ремонт+»"))
	h.add_child(left)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	_money = UI.bold(UI.money(Game.money), 38, UI.ACCENT)
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_money)
	_rep = UI.caption("Репутация 50", UI.DIM)
	_rep.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_rep)
	h.add_child(right)

	Game.money_changed.connect(_on_changed)
	Game.rep_changed.connect(_on_changed)
	Game.day_changed.connect(_on_day)
	Game.level_changed.connect(_on_changed)
	refresh()


func _on_changed(_value: int) -> void:
	refresh()


func _on_day(_value: int) -> void:
	refresh()


func refresh() -> void:
	if _day == null:
		return
	_day.text = "День %d" % Game.day
	_money.text = UI.money(Game.money)
	_rep.text = "Репутация %d · ур. %d" % [Game.rep, Game.level]
	var color := UI.ACCENT
	if Game.rep < 30:
		color = UI.DANGER
	elif Game.rep < 60:
		color = UI.WARN
	_rep.add_theme_color_override("font_color", color)