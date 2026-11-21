class_name Fault
extends Resource
## Неисправность. Одна жалоба клиента = одна неисправность (для MVP),
## чтобы диагноз читался по симптомам, а не угадывался.

@export var id: String = ""
@export var title: String = ""
## Жалоба клиента «своими словами»
@export var symptom: String = ""
## Какой узел меняем: screen / battery / port / speaker / "" (чистка)
@export var part_type: String = ""
## Базовая стоимость работы в рублях
@export var labor: int = 500
## 1.0 — просто, 1.5 — ювелирная работа
@export var difficulty: float = 1.0
## Залитие: нужна чистка, запчасть опциональна
@export var needs_cleaning: bool = false
## Короткая метка для карточки: Э / Б / З / В / Д
@export var badge: String = "?"
@export var color: Color = Color("#4aa8ff")


func part_name() -> String:
	match part_type:
		"screen":
			return "Экран"
		"battery":
			return "Аккумулятор"
		"port":
			return "Разъём зарядки"
		"speaker":
			return "Динамик"
		_:
			return "Чистка"