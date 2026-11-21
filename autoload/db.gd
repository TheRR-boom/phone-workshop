extends Node
## DB — автолоад с контентом. Загружается один раз при старте, дальше
## все сцены читают телефоны/неисправности/качества отюда.
##
## Контент лежит в Catalog (таблицы), а здесь он превращается в типизированные
## Resource. Когда контента станет много — таблицы заменяются на .tres/JSON,
## а сцены и логика остаются без изменений.

var phones: Array[PhoneModel] = []
var faults: Array[Fault] = []
var qualities: Array[PartQuality] = []
var clients: Array[ClientType] = []
var upgrades: Array[Dictionary] = []

var phones_by_id: Dictionary = {}
var faults_by_id: Dictionary = {}
var qualities_by_id: Dictionary = {}
var clients_by_id: Dictionary = {}


func _ready() -> void:
	_build_phones()
	_build_faults()
	_build_qualities()
	_build_clients()
	upgrades.clear()
	for row in Catalog.UPGRADES:
		upgrades.append(row.duplicate(true))


func _build_phones() -> void:
	for row in Catalog.PHONES:
		var p := PhoneModel.new()
		p.id = String(row["id"])
		p.title = String(row["title"])
		p.tier = int(row["tier"])
		p.base_value = int(row["base_value"])
		p.repairability = float(row["repairability"])
		p.screws = int(row["screws"])
		p.color = Color(String(row["color"]))
		phones.append(p)
		phones_by_id[p.id] = p


func _build_faults() -> void:
	for row in Catalog.FAULTS:
		var f := Fault.new()
		f.id = String(row["id"])
		f.title = String(row["title"])
		f.symptom = String(row["symptom"])
		f.part_type = String(row["part_type"])
		f.labor = int(row["labor"])
		f.difficulty = float(row["difficulty"])
		f.needs_cleaning = bool(row["needs_cleaning"])
		f.badge = String(row["badge"])
		f.color = Color(String(row["color"]))
		faults.append(f)
		faults_by_id[f.id] = f


func _build_qualities() -> void:
	for row in Catalog.QUALITIES:
		var q := PartQuality.new()
		q.id = String(row["id"])
		q.title = String(row["title"])
		q.cost_mul = float(row["cost_mul"])
		q.reliability = float(row["reliability"])
		q.warranty_days = int(row["warranty_days"])
		q.color = Color(String(row["color"]))
		qualities.append(q)
		qualities_by_id[q.id] = q


func _build_clients() -> void:
	for row in Catalog.CLIENTS:
		var c := ClientType.new()
		c.id = String(row["id"])
		c.title = String(row["title"])
		c.description = String(row["description"])
		c.pay_bonus = float(row["pay_bonus"])
		c.patience = int(row["patience"])
		c.scam_chance = float(row["scam_chance"])
		c.rep_mul = float(row["rep_mul"])
		c.color = Color(String(row["color"]))
		clients.append(c)
		clients_by_id[c.id] = c


func phone(id: String) -> PhoneModel:
	return phones_by_id.get(id)


func fault(id: String) -> Fault:
	return faults_by_id.get(id)


func quality(id: String) -> PartQuality:
	return qualities_by_id.get(id)


func client(id: String) -> ClientType:
	return clients_by_id.get(id)