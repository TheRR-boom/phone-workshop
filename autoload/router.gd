extends CanvasLayer
## Router — навигация между экранами с затемнением и показ уведомлений.
## Живёт выше всех сцен (layer 128), поэтому тосты видны поверх любого экрана.

const SCENES := {
	"workshop": "res://scenes/workshop.tscn",
	"order": "res://scenes/order.tscn",
	"teardown": "res://scenes/teardown.tscn",
	"repair": "res://scenes/repair.tscn",
	"inventory": "res://scenes/inventory.tscn",
	"shop": "res://scenes/shop.tscn",
	"showcase": "res://scenes/showcase.tscn",
}

var _fade: ColorRect
var _toasts: VBoxContainer
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128

	# Контейнер тостов (внизу, над навигацией)
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	_toasts = VBoxContainer.new()
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.add_theme_constant_override("separation", 10)
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toasts.offset_left = 40
	_toasts.offset_right = -40
	_toasts.offset_top = -420
	_toasts.offset_bottom = -150
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_toasts)

	# Затемнение для переходов
	_fade = ColorRect.new()
	_fade.color = Color(0.043, 0.055, 0.075, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)

	Game.notify.connect(_on_notify)


func go(key: String) -> void:
	if _busy:
		return
	if not SCENES.has(key):
		push_error("Неизвестный экран: %s" % key)
		return

	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.16)
	await tw.finished

	get_tree().change_scene_to_file(String(SCENES[key]))
	await get_tree().process_frame
	await get_tree().process_frame

	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.18)
	await tw2.finished

	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _on_notify(text: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.style(Color("#243040"), 18, UI.LINE, 2))
	var l := UI.label(text, 26, UI.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(p)

	var tw := p.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)
