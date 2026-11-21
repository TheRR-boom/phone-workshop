extends Node
## Дебаг-скрипт: рендерит экраны в PNG (запускается под xvfb).
## В игре не используется. Помогает проверять вёрстку без телефона.

const OUT_DIR := "user://shots"

var _shots := [
	{"scene": "res://scenes/workshop.tscn", "name": "01_workshop"},
	{"scene": "res://scenes/inventory.tscn", "name": "02_inventory"},
	{"scene": "res://scenes/shop.tscn", "name": "03_shop"},
	{"scene": "res://scenes/showcase.tscn", "name": "04_showcase"},
]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await get_tree().process_frame
	for item in _shots:
		await _shoot(String(item["scene"]), String(item["name"]))
	get_tree().quit()


func _shoot(path: String, name: String) -> void:
	var packed: PackedScene = load(path)
	var inst := packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, name])
	print("saved ", name, " ", img.get_width(), "x", img.get_height())
	inst.queue_free()
	await get_tree().process_frame
