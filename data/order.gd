class_name Order
extends RefCounted
## Заказ на ремонт: конкретный клиент + устройство + неисправность.
## Создаётся на день, живёт в Game.clients, удаляется после оплаты.

var id: int = 0
var day: int = 1
var client_name: String = ""
var client_type: ClientType
var phone: PhoneModel
var fault: Fault

## Выбранная запчасть (null для чистки)
var quality: PartQuality = null
## Итоговая цена, которую назвал игрок
var price: int = 0
## Поставленный диагноз (id неисправности)
var diagnosis: String = ""
## waiting → accepted → done / failed
var status: String = "waiting"
## Клиент готов доплатить за срочность/оставить телефон — для будущих итераций
var urgent: bool = false


func title() -> String:
	return "%s · %s" % [phone.title, fault.title]


func part_label() -> String:
	if quality == null:
		return "чистка"
	return "%s · %s" % [fault.part_name(), quality.title]