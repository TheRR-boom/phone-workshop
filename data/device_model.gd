class_name DeviceModel
extends RefCounted
## Модель внутренностей телефона: слои, зависимости, винты, дефект, улики.
##
## Сцена только рисует и принимает тач — вся «физика разборки» здесь.
## Порядок как в реальном ремонте: винты → крышка → экран/щит → батарея →
## шлейфы → плата → модули. Нарушение порядка и неверный инструмент портят детали.

const W := 1000.0
const H := 2000.0

var phone: PhoneModel
var defect: Defect

var components: Array[Dictionary] = []
var by_id: Dictionary = {}
var done: Dictionary = {}          # id -> снят/отключён
var screws_left: Dictionary = {}   # id -> сколько винтов осталось
var test_points: Array[Dictionary] = []

var damage := 0
var torn_flex := false
var evidence: Array[String] = []
var diagnosed := false
var inspected: Array[String] = []


func setup(p_phone: PhoneModel, p_defect: Defect) -> void:
	phone = p_phone
	defect = p_defect
	_build_layout()
	_build_test_points()


func _build_layout() -> void:
	components.clear()
	by_id.clear()
	done.clear()
	screws_left.clear()

	# --- винты корпуса (снаружи, доступны сразу) ---
	var bottom := _comp("bottom_screws", "Винты корпуса", "screwgroup", Rect2(200, 1840, 600, 120), [], 110)
	bottom["screws"] = _screws([Vector2(285, 1885), Vector2(715, 1885)], "pentalobe")
	_add(bottom)

	# --- задняя крышка: снимается присоской и свайпом ---
	var cover := _comp("back_cover", "Задняя крышка", "cover", Rect2(90, 50, 820, 1900), ["bottom_screws"], 100)
	cover["removal"] = "suction"
	cover["swipe"] = true
	_add(cover)

	# --- экранирующая пластина: Torx ---
	var shield := _comp("shield_plate", "Экранирующая пластина", "shield", Rect2(120, 120, 760, 520), ["back_cover"], 90)
	var shield_screws: Array[Vector2] = [Vector2(160, 160), Vector2(840, 160), Vector2(160, 600), Vector2(840, 600)]
	if phone.tier == 0:
		shield_screws = [Vector2(160, 160), Vector2(840, 600)]
	elif phone.tier == 1:
		shield_screws = [Vector2(160, 160), Vector2(840, 160), Vector2(500, 610)]
	shield["screws"] = _screws(shield_screws, "torx")
	shield["removal"] = "spudger"
	_add(shield)

	# --- шлейф дисплея ---
	var disp := _comp("display_flex", "Шлейф дисплея", "flex", Rect2(120, 760, 70, 520), ["back_cover"], 60)
	disp["disconnect"] = true
	disp["view_requires"] = ["back_cover"]
	_add(disp)

	# --- шлейф разъёма зарядки ---
	var port := _comp("port_flex", "Шлейф разъёма зарядки", "flex", Rect2(410, 1740, 180, 150), ["back_cover"], 60)
	port["disconnect"] = true
	port["view_requires"] = ["back_cover"]
	_add(port)

	# --- разъём батареи ---
	var conn := _comp("battery_connector", "Разъём аккумулятора", "connector", Rect2(420, 860, 160, 100), ["shield_plate"], 65)
	conn["disconnect"] = true
	conn["view_requires"] = ["shield_plate"]
	_add(conn)

	# --- аккумулятор ---
	var battery := _comp("battery", "Аккумулятор", "battery", Rect2(130, 980, 740, 780), ["battery_connector"], 70)
	battery["removal"] = "spudger"
	battery["view_requires"] = ["back_cover"]
	_add(battery)

	# --- материнская плата ---
	var board := _comp("board", "Материнская плата", "board", Rect2(120, 140, 760, 740), ["shield_plate", "display_flex", "port_flex", "battery_connector"], 50)
	board["removal"] = "spudger"
	board["view_requires"] = ["shield_plate"]
	_add(board)

	# --- камеры ---
	var cam := _comp("camera_main", "Основная камера", "camera", Rect2(560, 150, 260, 240), ["back_cover"], 95)
	cam["removal"] = "spudger"
	cam["view_requires"] = ["back_cover"]
	_add(cam)

	# --- динамик и вибромотор ---
	var spk := _comp("speaker", "Динамик", "speaker", Rect2(640, 1690, 190, 140), ["back_cover"], 80)
	spk["removal"] = "spudger"
	spk["view_requires"] = ["back_cover"]
	_add(spk)

	var vibro := _comp("vibro", "Вибромотор", "vibro", Rect2(220, 1700, 160, 120), ["back_cover"], 80)
	vibro["removal"] = "spudger"
	vibro["view_requires"] = ["back_cover"]
	_add(vibro)


func _comp(id: String, title: String, kind: String, rect: Rect2, requires: Array, layer: int) -> Dictionary:
	return {
		"id": id,
		"title": title,
		"kind": kind,
		"rect": rect,
		"requires": requires,
		"view_requires": requires.duplicate(),
		"layer": layer,
		"screws": [],
		"removal": "spudger",
		"disconnect": false,
		"swipe": false,
	}


func _screws(positions: Array, type: String) -> Array:
	var out := []
	for p in positions:
		out.append({"type": type, "pos": p, "removed": false})
	return out


func _add(c: Dictionary) -> void:
	components.append(c)
	by_id[c["id"]] = c
	screws_left[c["id"]] = (c["screws"] as Array).size()


func _build_test_points() -> void:
	test_points = [
		{"id": "BAT", "label": "BAT+", "pos": Vector2(300, 900), "mode": "V",
			"normal": "3.87 В", "faulty": "2.41 В", "component": "board", "requires": ["shield_plate"]},
		{"id": "VBUS", "label": "VBUS", "pos": Vector2(500, 1790), "mode": "V",
			"normal": "5.02 В", "faulty": "0.71 В", "component": "port_flex", "requires": ["back_cover"]},
		{"id": "VDD", "label": "VDD", "pos": Vector2(330, 320), "mode": "R",
			"normal": "12 кОм", "faulty": "0.3 Ом", "component": "board", "requires": ["shield_plate"]},
		{"id": "DISP", "label": "DISP", "pos": Vector2(155, 900), "mode": "C",
			"normal": "есть", "faulty": "обрыв", "component": "display_flex", "requires": ["back_cover"]},
		{"id": "SPK", "label": "SPK", "pos": Vector2(735, 1760), "mode": "R",
			"normal": "8.0 Ом", "faulty": "обрыв", "component": "speaker", "requires": ["back_cover"]},
	]


# ---------------------------------------------------------------- доступ ---

func comp(id: String) -> Dictionary:
	return by_id.get(id, {})


func is_done(id: String) -> bool:
	return bool(done.get(id, false))


func requirements_met(id: String, key: String = "requires") -> bool:
	var c := comp(id)
	if c.is_empty():
		return false
	for req in c[key]:
		if not is_done(String(req)):
			return false
	return true


func is_exposed(id: String) -> bool:
	return requirements_met(id, "view_requires")


func visible_ids() -> Array[String]:
	var out: Array[String] = []
	for c in components:
		if is_done(c["id"]):
			continue
		if c["id"] == "bottom_screws":
			out.append(c["id"])
			continue
		if is_exposed(c["id"]):
			out.append(c["id"])
	return out


func can_remove(id: String) -> bool:
	var c := comp(id)
	if c.is_empty() or is_done(id):
		return false
	if not requirements_met(id):
		return false
	return int(screws_left.get(id, 0)) == 0


func remove(id: String, tool: String) -> Dictionary:
	var c := comp(id)
	if c.is_empty():
		return {"ok": false, "code": "NO_COMPONENT"}
	if is_done(id):
		return {"ok": false, "code": "ALREADY"}
	if not requirements_met(id):
		return {"ok": false, "code": "LOCKED", "text": "Сначала снимите: " + _missing_text(id)}
	if int(screws_left.get(id, 0)) > 0:
		return {"ok": false, "code": "SCREWS", "text": "Сначала выкрутите винты (%d)" % int(screws_left.get(id, 0))}
	if String(c["removal"]) != tool:
		damage += 3
		return {"ok": false, "code": "WRONG_TOOL", "text": "Нужен другой инструмент"}

	if id == "board" and not torn_flex and damage >= 15:
		torn_flex = true
	done[id] = true
	return {"ok": true, "code": "OK"}


func _missing_text(id: String) -> String:
	var names: Array[String] = []
	for req in comp(id)["requires"]:
		if not is_done(String(req)):
			names.append(String(comp(String(req)).get("title", req)))
	return ", ".join(names)


# ---------------------------------------------------------------- винты ---

func screw_at(id: String, point: Vector2, radius: float = 60.0) -> int:
	var c := comp(id)
	if c.is_empty():
		return -1
	var list: Array = c["screws"]
	for i in list.size():
		var s: Dictionary = list[i]
		if bool(s["removed"]):
			continue
		if (s["pos"] as Vector2).distance_to(point) <= radius:
			return i
	return -1


func unscrew(id: String, screw_index: int, bit: String) -> Dictionary:
	var c := comp(id)
	if c.is_empty():
		return {"ok": false, "code": "NO_COMPONENT"}
	if is_done(id):
		return {"ok": false, "code": "ALREADY"}
	if not is_exposed(id):
		return {"ok": false, "code": "LOCKED", "text": "Сюда пока не добраться"}
	var list: Array = c["screws"]
	if screw_index < 0 or screw_index >= list.size():
		return {"ok": false, "code": "NO_SCREW"}
	var screw: Dictionary = list[screw_index]
	if bool(screw["removed"]):
		return {"ok": false, "code": "ALREADY"}

	if String(screw["type"]) != bit:
		damage += 2
		return {"ok": false, "code": "WRONG_BIT", "text": "Не та бита: срывается шлиц"}

	screw["removed"] = true
	screws_left[id] = maxi(0, int(screws_left.get(id, 0)) - 1)
	# Группа винтов считается снятой, когда выкручен последний
	if int(screws_left[id]) == 0 and String(c["kind"]) == "screwgroup":
		done[id] = true
	return {"ok": true, "code": "OK", "left": int(screws_left[id])}


func screws_total(id: String) -> int:
	return (comp(id).get("screws", []) as Array).size()


func screws_remaining(id: String) -> int:
	return int(screws_left.get(id, 0))


# ------------------------------------------------------------ шлейфы ---

func disconnect_flex(id: String, tool: String) -> Dictionary:
	var c := comp(id)
	if c.is_empty() or not bool(c.get("disconnect", false)):
		return {"ok": false, "code": "NOT_CONNECTOR"}
	if is_done(id):
		return {"ok": false, "code": "ALREADY"}
	if not is_exposed(id):
		return {"ok": false, "code": "LOCKED", "text": "Узел закрыт"}
	if tool != "spudger":
		damage += 5
		torn_flex = true
		return {"ok": false, "code": "WRONG_TOOL", "text": "Шлейф оторван — нужна лопатка"}
	done[id] = true
	return {"ok": true, "code": "OK"}


# ------------------------------------------------------------ осмотр ---

func inspect(id: String) -> Dictionary:
	var c := comp(id)
	if c.is_empty() or is_done(id):
		return {"ok": false, "code": "NO_COMPONENT"}
	if not is_exposed(id):
		return {"ok": false, "code": "LOCKED", "text": "Узел закрыт"}

	if not inspected.has(id):
		inspected.append(id)

	if id == defect.component_id:
		if not evidence.has(defect.evidence):
			evidence.append(defect.evidence)
		return {"ok": true, "anomaly": true, "text": defect.evidence, "component": c}
	return {"ok": true, "anomaly": false, "text": "Следов неисправности не видно", "component": c}


# --------------------------------------------------------- мультиметр ---

func measure(point_id: String, mode: String) -> Dictionary:
	var point := {}
	for p in test_points:
		if String(p["id"]) == point_id:
			point = p
			break
	if point.is_empty():
		return {"ok": false, "code": "NO_POINT"}
	for req in point["requires"]:
		if not is_done(String(req)):
			return {"ok": false, "code": "LOCKED", "text": "Точка закрыта"}

	if mode != String(point["mode"]):
		return {"ok": false, "code": "WRONG_MODE", "text": "Не тот режим прибора"}

	var faulty := defect.test_point == point_id
	var reading := String(point["faulty"]) if faulty else String(point["normal"])
	var label := String(point["label"])
	if faulty:
		var ev := "%s: %s (%s)" % [label, reading, String(point["mode"])]
		if not evidence.has(ev):
			evidence.append(ev)
	return {"ok": true, "reading": reading, "label": label, "faulty": faulty, "mode": mode}


# ------------------------------------------------------------ диагноз ---

func confirm(id: String) -> Dictionary:
	if evidence.is_empty():
		return {"ok": false, "code": "NO_EVIDENCE", "text": "Нужны улики: осмотр или замер"}
	if id != defect.component_id:
		return {"ok": false, "code": "WRONG", "text": "Этот узел в порядке"}
	diagnosed = true
	return {"ok": true, "code": "OK", "defect": defect}


func success_chance() -> float:
	var chance := 0.97 - float(damage) * 0.02
	if torn_flex:
		chance -= 0.15
	return clampf(chance, 0.35, 0.99)


func hint() -> String:
	if not is_done("bottom_screws"):
		return "Выкрутите нижние винты (Pentalobe) и снимите крышку"
	if not is_done("back_cover"):
		return "Присоска + свайп вверх: снимите заднюю крышку"
	if not is_done("shield_plate"):
		if screws_remaining("shield_plate") > 0:
			return "Открутите Torx-винты экранирующей пластины"
		return "Снимите экранирующую пластину лопаткой"
	if diagnosed:
		return "Диагноз подтверждён — можно согласовать цену"
	if evidence.is_empty():
		return "Осмотрите узлы (лупа) или замерьте мультиметром"
	return "Улик достаточно: подтвердите неисправный узел"