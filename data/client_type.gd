class_name ClientType
extends Resource
## Тип клиента задаёт характер торга и «сюрпризы» после ремонта.

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
## Насколько клиент готов переплатить: 1.0 — рыночная цена
@export var pay_bonus: float = 0.0
## Сколько раз клиент готов торговаться (0 — не торгуется)
@export var patience: int = 1
## Шанс, что после ремонта клиент заявит «всё равно сломано» и потребует возврат
@export var scam_chance: float = 0.0
## Множитель изменения репутации при работе с ним
@export var rep_mul: float = 1.0
@export var color: Color = Color("#8fa3b8")