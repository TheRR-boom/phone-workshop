class_name Defect
extends Resource
## Скрытая неисправность. Игрок её не видит в меню — только находит:
## осмотром узла (визуальная улика) или замером мультиметром.

@export var id: String = ""
@export var title: String = ""
## Компонент, на котором живёт дефект (id из DeviceModel)
@export var component_id: String = ""
## Тип работы для экономики и склада (screen/battery/port/liquid/speaker)
@export var fault_id: String = ""
## Жалоба клиента: намёк, но не диагноз
@export var symptom: String = ""
## Что видно при осмотре (улика)
@export var evidence: String = ""
## Точка замера и режим мультиметра
@export var test_point: String = ""
@export var test_mode: String = "V"
@export var test_normal: String = ""
@export var test_faulty: String = ""
## replace / clean / solder
@export var repair: String = "replace"
@export var color: Color = Color("#ffb020")