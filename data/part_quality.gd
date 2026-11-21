class_name PartQuality
extends Resource
## Качество запчасти. Влияет на цену, надёжность ремонта и срок гарантии —
## это главный «торговый» выбор игрока: дешевле сейчас или меньше проблем потом.

@export var id: String = ""
@export var title: String = ""
## Множитель к базовой цене запчасти
@export var cost_mul: float = 1.0
## Шанс успешного ремонта (0..1)
@export var reliability: float = 0.95
## Гарантия в днях: чем меньше, тем выше шанс возврата
@export var warranty_days: int = 90
@export var color: Color = Color("#38e8a0")


func warranty_text() -> String:
	if warranty_days >= 365:
		return "%d год" % int(warranty_days / 365)
	if warranty_days >= 30:
		return "%d мес." % int(round(warranty_days / 30.0))
	return "%d дн." % warranty_days