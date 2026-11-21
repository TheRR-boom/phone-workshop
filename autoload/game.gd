extends Node
## Game — автолоад состояния: деньги, репутация, день, склад, заказы, витрина.
##
## Сохранение — JSON в user://, пишется с задержкой 0.6 с после изменения
## (чтобы не дёргать диск на каждый тап) и принудительно при сворачивании.
## Никакой сети: прогресс полностью локальный.

signal money_changed(value: int)
signal rep_changed(value: int)
signal day_changed(value: int)
signal level_changed(value: int)
signal clients_changed
signal inventory_changed
signal showcase_changed
signal notify(text: String)

const SAVE_PATH := "user://repair_plus_save.json"
const SAVE_VERSION := 1
const MAX_SHOWCASE := 3
const XP_LEVELS := [0, 250, 700, 1500, 3000]

var money: int = Econ.START_MONEY
var rep: int = Econ.START_REP
var day: int = 1
var xp: int = 0
var level: int = 1

## "screen:copy:1" -> количество. Ключ включает класс устройства,
## потому что экран от кнопочного не подходит к флагману.
var inventory: Dictionary = {}
var upgrades: Dictionary = {}
var showcase: Array[Dictionary] = []
var lots: Array[Dictionary] = []

var clients: Array[Order] = []
## Заказ, открытый на экране оформления (ещё не принят)
var pending_order: Order = null
## Заказ, который сейчас ремонтируется
var current_order: Order = null
var stats: Dictionary = {"orders": 0, "failed": 0, "earned": 0, "refunds": 0}

var _next_order_id: int = 1
var _save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.6
	_save_timer.timeout.connect(save_game)
	add_child(_save_timer)

	if not load_game():
		_seed_new_game()
	if clients.is_empty():
		_generate_clients()
	if lots.is_empty():
		_generate_lots()

	# Отдаём сценам актуальные значения после загрузки
	money_changed.emit(money)
	rep_changed.emit(rep)
	day_changed.emit(day)
	level_changed.emit(level)
	clients_changed.emit()
	showcase_changed.emit()
	inventory_changed.emit()


## Пауза при сворачивании: останавливаем дерево и сохраняемся.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()
		get_tree().paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		get_tree().paused = false
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# ---------------------------------------------------------------- деньги ---

func toast(text: String) -> void:
	notify.emit(text)


func add_money(delta: int) -> void:
	if delta == 0:
		return
	money = maxi(0, money + delta)
	money_changed.emit(money)
	_queue_save()


func spend(amount: int) -> bool:
	if amount > money:
		return false
	add_money(-amount)
	return true


func add_rep(delta: float) -> void:
	if is_zero_approx(delta):
		return
	rep = clampi(int(round(rep + delta)), 0, 100)
	rep_changed.emit(rep)
	_queue_save()


func add_xp(amount: int) -> void:
	xp += maxi(0, amount)
	var new_level := 1
	for i in XP_LEVELS.size():
		if xp >= int(XP_LEVELS[i]):
			new_level = i + 1
	if new_level != level:
		level = new_level
		level_changed.emit(level)
	_queue_save()


# ------------------------------------------------------------------ склад ---

func part_key(part_type: String, quality_id: String, tier: int) -> String:
	return "%s:%s:%d" % [part_type, quality_id, tier]


func count_part(part_type: String, quality_id: String, tier: int) -> int:
	return int(inventory.get(part_key(part_type, quality_id, tier), 0))


func has_part(part_type: String, quality_id: String, tier: int) -> bool:
	return count_part(part_type, quality_id, tier) > 0


func add_part(part_type: String, quality_id: String, tier: int, count: int = 1) -> void:
	var key := part_key(part_type, quality_id, tier)
	inventory[key] = int(inventory.get(key, 0)) + count
	if int(inventory[key]) <= 0:
		inventory.erase(key)
	inventory_changed.emit()
	_queue_save()


func take_part(part_type: String, quality_id: String, tier: int) -> bool:
	if not has_part(part_type, quality_id, tier):
		return false
	add_part(part_type, quality_id, tier, -1)
	return true


func buy_part(part_type: String, quality_id: String, tier: int) -> bool:
	var cost := Catalog.part_cost(part_type, tier, quality_id)
	if not spend(cost):
		notify.emit("Не хватает денег на запчасть")
		return false
	add_part(part_type, quality_id, tier, 1)
	return true


# --------------------------------------------------------------- клиенты ---

func _generate_clients() -> void:
	clients.clear()
	var count := 3
	if upgrades.has("advertising"):
		count += 1
	for i in count:
		clients.append(_make_order())
	clients_changed.emit()


func _make_order() -> Order:
	var o := Order.new()
	o.id = _next_order_id
	_next_order_id += 1
	o.day = day
	o.phone = _pick_phone()
	o.defect = DB.defects[randi() % DB.defects.size()]
	o.fault = DB.fault(o.defect.fault_id)
	o.client_type = _pick_client_type()
	o.client_name = String(Catalog.CLIENT_NAMES[randi() % Catalog.CLIENT_NAMES.size()])
	o.urgent = o.client_type.id == "urgent"
	return o


func _pick_phone() -> PhoneModel:
	var pool: Array[PhoneModel] = []
	for p in DB.phones:
		if p.tier <= 1 or level >= 2:
			pool.append(p)
	return pool[randi() % pool.size()]


## Мошенники и скандалисты попадаются реже обычных клиентов.
func _pick_client_type() -> ClientType:
	var weights := {"regular": 32, "urgent": 20, "karen": 15, "loyal": 20, "scammer": 13}
	var total := 0
	for v in weights.values():
		total += int(v)
	var roll := randi() % total
	var acc := 0
	for id in weights.keys():
		acc += int(weights[id])
		if roll < acc:
			return DB.client(id)
	return DB.client("regular")


## Приём устройства на диагностику: цена обсуждается после разборки.
func accept_for_diagnosis(order: Order) -> bool:
	if order == null or order.defect == null:
		return false
	clients.erase(order)
	current_order = order
	order.status = "diagnostics"
	clients_changed.emit()
	_queue_save()
	return true


## Игрок передумал / вышел: заказ возвращается на доску.
func return_order(order: Order) -> void:
	if order == null:
		return
	if current_order == order:
		current_order = null
	if not clients.has(order):
		clients.push_front(order)
	order.status = "waiting"
	clients_changed.emit()
	_queue_save()


func accept_order(order: Order, quality_id: String, price: int) -> bool:
	if order == null or price <= 0:
		return false
	if quality_id != "" and not has_part(order.fault.part_type, quality_id, order.phone.tier):
		notify.emit("Этой запчасти нет на складе")
		return false
	order.quality = DB.quality(quality_id) if quality_id != "" else null
	order.price = price
	order.status = "accepted"
	clients.erase(order)
	current_order = order
	clients_changed.emit()
	_queue_save()
	return true


func decline_order(order: Order) -> void:
	if order == null:
		return
	clients.erase(order)
	add_rep(-1.0 * order.client_type.rep_mul)
	notify.emit("Клиент ушёл: −%d к репутации" % int(round(order.client_type.rep_mul)))
	clients_changed.emit()
	_queue_save()


## Завершение ремонта. success считает сцена ремонта по шансу Econ.
func finish_order(success: bool) -> Dictionary:
	var report := {
		"success": success, "scam": false, "paid": 0,
		"rep": 0, "xp": 0, "review": "", "title": "", "client": "",
	}
	var o := current_order
	if o == null:
		return report

	report["title"] = o.title()
	report["client"] = o.client_name

	# Запчасть списывается в момент завершения, а не при приёме заказа:
	# если игрок закроет приложение посреди ремонта, деталь не потеряется.
	if o.quality != null:
		take_part(o.fault.part_type, o.quality.id, o.phone.tier)

	var scam := false
	if success:
		scam = randf() < o.client_type.scam_chance

	if success and not scam:
		add_money(o.price)
		report["paid"] = o.price
		stats["earned"] = int(stats["earned"]) + o.price
		stats["orders"] = int(stats["orders"]) + 1
	else:
		stats["failed"] = int(stats["failed"]) + 1
		if scam:
			stats["refunds"] = int(stats["refunds"]) + 1

	var rep_delta := Econ.rep_delta(success and not scam, scam, o)
	add_rep(float(rep_delta))
	report["rep"] = rep_delta

	var xp_gain := Econ.xp_reward(o, success and not scam)
	add_xp(xp_gain)
	report["xp"] = xp_gain

	report["scam"] = scam
	report["review"] = Econ.review_text(success and not scam, scam, o.quality)

	current_order = null
	_queue_save()
	return report


# ------------------------------------------------------------------- день ---

func close_day() -> Dictionary:
	var report := {"day": day + 1, "rent": Econ.RENT, "left": clients.size()}
	day += 1
	# Клиенты, которых не приняли, уходят без штрафа — просто теряется выручка.
	clients.clear()
	add_money(-Econ.RENT)
	_generate_clients()
	_generate_lots()
	day_changed.emit(day)
	_queue_save()
	return report


# ----------------------------------------------------------------- витрина ---

func _generate_lots() -> void:
	lots.clear()
	var count := 2
	for i in count:
		if DB.phones.is_empty():
			break
		var phone: PhoneModel = DB.phones[randi() % DB.phones.size()]
		var fault: Fault = DB.faults[randi() % DB.faults.size()]
		var price := int(round(float(phone.base_value) * 0.22))
		lots.append({
			"phone_id": phone.id,
			"fault_id": fault.id,
			"price": price,
		})


func buy_lot(index: int) -> bool:
	if index < 0 or index >= lots.size():
		return false
	if showcase.size() >= MAX_SHOWCASE:
		notify.emit("Витрина заполнена (3/3)")
		return false
	var lot: Dictionary = lots[index]
	if not spend(int(lot["price"])):
		notify.emit("Не хватает денег на лот")
		return false
	showcase.append({
		"phone_id": lot["phone_id"],
		"fault_id": lot["fault_id"],
		"ready": false,
		"quality_id": "",
		"price": 0,
	})
	lots.remove_at(index)
	showcase_changed.emit()
	return true


## Восстановление телефона с витрины: нужна любая запчасть под его класс.
func restore_showcase(index: int) -> bool:
	if index < 0 or index >= showcase.size():
		return false
	var item: Dictionary = showcase[index]
	if bool(item["ready"]):
		return false
	var phone: PhoneModel = DB.phone(String(item["phone_id"]))
	var fault: Fault = DB.fault(String(item["fault_id"]))

	var chosen := ""
	for qid in ["original", "copy", "used"]:
		if has_part(fault.part_type, qid, phone.tier):
			chosen = qid
			break
	if chosen == "":
		notify.emit("Нужна запчасть: %s" % fault.part_name())
		return false

	take_part(fault.part_type, chosen, phone.tier)
	item["ready"] = true
	item["quality_id"] = chosen
	item["price"] = int(round(float(phone.base_value) * 0.85))
	showcase_changed.emit()
	return true


func sell_showcase(index: int, price: int) -> Dictionary:
	if index < 0 or index >= showcase.size():
		return {"sold": false}
	var item: Dictionary = showcase[index]
	var phone: PhoneModel = DB.phone(String(item["phone_id"]))
	var chance := Econ.sale_chance(price, phone.base_value, rep, upgrades)
	if randf() <= chance:
		item["price"] = price
		add_money(price)
		add_rep(1.0)
		showcase.remove_at(index)
		showcase_changed.emit()
		return {"sold": true, "price": price, "chance": chance}
	return {"sold": false, "chance": chance}


# --------------------------------------------------------------- улучшения ---

func buy_upgrade(id: String) -> bool:
	if upgrades.has(id):
		return false
	for u in DB.upgrades:
		if String(u["id"]) == id:
			if not spend(int(u["price"])):
				notify.emit("Не хватает денег")
				return false
			upgrades[id] = true
			if id == "advertising" and clients.size() < 4:
				clients.append(_make_order())
			clients_changed.emit()
			_queue_save()
			return true
	return false


# ---------------------------------------------------------------- сейв/лоад ---

func _queue_save() -> void:
	if _save_timer:
		_save_timer.start()


func save_game() -> void:
	var data := {
		"v": SAVE_VERSION,
		"money": money,
		"rep": rep,
		"day": day,
		"xp": xp,
		"inventory": inventory,
		"upgrades": upgrades,
		"showcase": showcase,
		"lots": lots,
		"stats": stats,
		"clients": _serialize_clients(),
		"next_id": _next_order_id,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Не удалось сохранить прогресс")
		return
	f.store_string(JSON.stringify(data))
	f.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	if int(d.get("v", 0)) != SAVE_VERSION:
		return false

	money = int(d.get("money", Econ.START_MONEY))
	rep = clampi(int(d.get("rep", Econ.START_REP)), 0, 100)
	day = maxi(1, int(d.get("day", 1)))
	xp = maxi(0, int(d.get("xp", 0)))
	level = 1
	for i in XP_LEVELS.size():
		if xp >= int(XP_LEVELS[i]):
			level = i + 1

	inventory = _int_dict(d.get("inventory", {}))
	upgrades = _bool_dict(d.get("upgrades", {}))
	stats = _int_dict(d.get("stats", {}))

	showcase.clear()
	for row in d.get("showcase", []):
		if typeof(row) == TYPE_DICTIONARY:
			showcase.append({
				"phone_id": String(row.get("phone_id", "k1")),
				"fault_id": String(row.get("fault_id", "screen")),
				"ready": bool(row.get("ready", false)),
				"quality_id": String(row.get("quality_id", "")),
				"price": int(row.get("price", 0)),
			})

	lots.clear()
	for row in d.get("lots", []):
		if typeof(row) == TYPE_DICTIONARY:
			lots.append({
				"phone_id": String(row.get("phone_id", "k1")),
				"fault_id": String(row.get("fault_id", "screen")),
				"price": int(row.get("price", 500)),
			})

	clients.clear()
	for row in d.get("clients", []):
		var o := _order_from_dict(row)
		if o != null:
			clients.append(o)

	_next_order_id = maxi(1, int(d.get("next_id", clients.size() + 1)))
	return true


func _serialize_clients() -> Array:
	var arr := []
	for o in clients:
		arr.append({
			"id": o.id,
			"day": o.day,
			"name": o.client_name,
			"client": o.client_type.id,
			"phone": o.phone.id,
			"fault": o.fault.id,
			"defect": o.defect.id if o.defect != null else "",
			"urgent": o.urgent,
		})
	return arr


func _order_from_dict(row: Variant) -> Order:
	if typeof(row) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = row
	var phone: PhoneModel = DB.phone(String(d.get("phone", "")))
	var fault: Fault = DB.fault(String(d.get("fault", "")))
	var ctype: ClientType = DB.client(String(d.get("client", "regular")))
	if phone == null or fault == null or ctype == null:
		return null
	var o := Order.new()
	o.id = int(d.get("id", 0))
	o.day = int(d.get("day", 1))
	o.client_name = String(d.get("name", "Клиент"))
	o.client_type = ctype
	o.phone = phone
	o.fault = fault
	o.defect = DB.defect(String(d.get("defect", "")))
	if o.defect == null:
		o.defect = DB.defects[0]
	o.urgent = bool(d.get("urgent", false))
	return o


func _int_dict(raw: Variant) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for k in raw.keys():
		out[String(k)] = int(raw[k])
	return out


func _bool_dict(raw: Variant) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for k in raw.keys():
		out[String(k)] = bool(raw[k])
	return out


func _seed_new_game() -> void:
	money = Econ.START_MONEY
	rep = Econ.START_REP
	day = 1
	xp = 0
	level = 1
	upgrades = {}
	showcase.clear()
	stats = {"orders": 0, "failed": 0, "earned": 0, "refunds": 0}
	# Стартовый набор: по паре копий на ходовые ремонты
	inventory = {
		"screen:copy:0": 1, "battery:copy:0": 2,
		"screen:copy:1": 1, "battery:copy:1": 1,
		"port:copy:1": 1, "speaker:copy:1": 1,
	}
	_next_order_id = 1
	current_order = null
	pending_order = null
	clients.clear()
	showcase.clear()
	lots.clear()
	_generate_clients()
	_generate_lots()
	# Полный сброс не должен оставлять старый файл сохранения
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))