class_name PhoneModel
extends Resource
## Модель устройства. Данные статичны и живут в Catalog, но тип Resource
## удобно расширять (иконки, 3D-превью, звуки) без переделки логики.

@export var id: String = ""
@export var title: String = ""
## 0 — кнопочный, 1 — старый смартфон, 2 — современный смартфон
@export var tier: int = 0
## Рыночная цена б/у в рублях (для trade-in и витрины)
@export var base_value: int = 0
## 1.0 — ремонтопригодный, 0.75 — «клеевой бутерброд»
@export var repairability: float = 1.0
## Сколько винтов нужно выкрутить в мини-игре разборки
@export var screws: int = 4
@export var color: Color = Color("#4a5563")


func tier_name() -> String:
	match tier:
		0:
			return "Кнопочный"
		1:
			return "Старый смартфон"
		_:
			return "Современный"