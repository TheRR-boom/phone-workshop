extends Node
## Headless-тесты: экономика, полный цикл заказа, сохранение и вёрстка экранов
## на трёх соотношениях сторон. Запуск:
##   godot --headless --path . res://tests/smoke.tscn
##
## Это не «декоративные» тесты: они реально инстанцируют сцены и дёргают
## те же методы, что и игрок.

var _failed := 0
var _passed := 0


func _ready() -> void:
	await get_tree().process_frame

	_test_catalog()
	_test_econ()
	_test_flow()
	_test_save_load()
	await _test_order_screen()
	_test_device_model()
	await _test_teardown_scene()
	await _test_cleaning()
	await _test_soldering()
	await _test_ui(720, 1280, "16:9")
	await _test_ui(720, 1560, "19.5:9")
	await _test_ui(720, 1440, "18:9")

	print("\n=== RESULT: passed %d, failed %d ===" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", label)


func _test_catalog() -> void:
	check(DB.phones.size() == 3, "3 модели телефонов")
	check(DB.faults.size() == 5, "5 неисправностей")
	check(DB.qualities.size() == 3, "3 качества запчастей")
	check(DB.clients.size() == 5, "5 типов клиентов")
	check(DB.upgrades.size() == 4, "4 улучшения")

	for fault in DB.faults:
		if fault.part_type == "":
			continue
		check(Catalog.part_cost(fault.part_type, 0, "original") > 0, "цена запчасти %s" % fault.id)


func _test_econ() -> void:
	var phone := DB.phone("s3")
	var fault := DB.fault("screen")
	var client := DB.client("regular")

	var market := Econ.market_price(phone, fault)
	check(market > 0, "рыночная цена > 0")
	check(Econ.cost_price(phone, fault, "copy") < Econ.cost_price(phone, fault, "original"), "копия дешевле оригинала")

	var ceiling := Econ.client_ceiling(phone, fault, client, 50)
	check(ceiling > market * 0.8, "клиент готов платить близко к рынку")

	var r := Econ.reaction(int(ceiling * 1.3), ceiling)
	check(not bool(r["ok"]), "завышенная цена отклоняется")

	var order := Order.new()
	order.phone = phone
	order.fault = fault
	order.client_type = client
	order.quality = DB.quality("used")
	check(Econ.success_chance(order, {}) < 0.9, "б/у деталь снижает шанс успеха")
	order.quality = DB.quality("original")
	check(Econ.success_chance(order, {}) > 0.9, "оригинал даёт высокий шанс")

	check(Econ.rep_delta(true, false, order) > 0, "успех повышает репутацию")
	check(Econ.rep_delta(false, false, order) < 0, "провал снижает репутацию")


## Берём заказ с реальной запчастью (залитие без детали не подходит для теста).
func _pick_repair_order() -> Order:
	for o in Game.clients:
		if o.fault.part_type != "":
			return o
	return Game.clients[0]


func _test_flow() -> void:
	Game._seed_new_game()
	check(Game.money == Econ.START_MONEY, "стартовые деньги")
	check(Game.clients.size() >= 3, "клиенты на старте дня")

	var order: Order = _pick_repair_order()
	order.client_type = DB.client("regular")  # убираем случайного мошенника
	var phone := order.phone
	Game.add_part(order.fault.part_type, "copy", phone.tier, 1)
	var stock_before := Game.count_part(order.fault.part_type, "copy", phone.tier)

	var price := Econ.client_ceiling(phone, order.fault, order.client_type, Game.rep)
	var accepted := Game.accept_order(order, "copy", price)
	check(accepted, "заказ принят")
	check(Game.current_order == order, "текущий заказ установлен")
	check(Game.count_part(order.fault.part_type, "copy", phone.tier) == stock_before, "деталь ещё не списана")

	var money_before := Game.money
	var rep_before := Game.rep
	var report := Game.finish_order(true)
	check(bool(report["success"]), "ремонт успешен")
	check(not bool(report["scam"]), "обычный клиент не мошенник")
	check(Game.money == money_before + price, "оплата начислена")
	check(Game.rep > rep_before, "репутация выросла")
	check(Game.count_part(order.fault.part_type, "copy", phone.tier) == stock_before - 1, "деталь списана")
	check(Game.current_order == null, "заказ закрыт")

	# Неудачный ремонт: денег нет, репутация падает
	Game._seed_new_game()
	var o2: Order = _pick_repair_order()
	o2.client_type = DB.client("regular")
	Game.add_part(o2.fault.part_type, "used", o2.phone.tier, 1)
	Game.accept_order(o2, "used", 1000)
	var rep2 := Game.rep
	var cash2 := Game.money
	var report2 := Game.finish_order(false)
	check(Game.money == cash2, "за провал не платят")
	check(Game.rep < rep2, "за провал снижают репутацию")
	check(int(report2["paid"]) == 0, "в отчёте нет оплаты")

	# Закрытие дня: аренда и новые клиенты
	var day_before := Game.day
	var money_day := Game.money
	Game.close_day()
	check(Game.day == day_before + 1, "день сменился")
	check(Game.money == maxi(0, money_day - Econ.RENT), "аренда списана")
	check(Game.clients.size() >= 3, "новые клиенты пришли")

	# Склад и магазин
	Game.money = 5000
	var stock2 := Game.count_part("battery", "copy", 0)
	check(Game.buy_part("battery", "copy", 0), "запчасть куплена")
	check(Game.count_part("battery", "copy", 0) == stock2 + 1, "запчасть на складе")
	check(Game.buy_upgrade("heatgun"), "улучшение куплено")
	check(Game.upgrades.has("heatgun"), "улучшение активно")

	# Витрина: купил битый → восстановил → продал
	Game.money = 9000
	check(Game.lots.size() > 0, "лоты на витрине есть")
	Game.showcase.clear()
	check(Game.buy_lot(0), "битый телефон куплен")
	check(Game.showcase.size() == 1, "телефон на витрине")
	var item: Dictionary = Game.showcase[0]
	var phone2: PhoneModel = DB.phone(String(item["phone_id"]))
	var fault2: Fault = DB.fault(String(item["fault_id"]))
	Game.add_part(fault2.part_type, "used", phone2.tier, 1)
	check(Game.restore_showcase(0), "телефон восстановлен")
	check(bool(Game.showcase[0]["ready"]), "статус «готов»")
	var sale := Game.sell_showcase(0, int(Game.showcase[0]["price"]))
	check(typeof(sale) == TYPE_DICTIONARY, "продажа обрабатывается")


func _test_save_load() -> void:
	Game.money = 1234
	Game.rep = 77
	Game.save_game()

	Game.money = 0
	Game.rep = 0
	check(Game.load_game(), "сохранение читается")
	check(Game.money == 1234, "деньги восстановлены")
	check(Game.rep == 77, "репутация восстановлена")


func _test_soldering() -> void:
	Game._seed_new_game()
	var o := Order.new()
	o.phone = DB.phone("s3")
	o.fault = DB.fault("port")
	o.client_type = DB.client("regular")
	o.price = 1500
	Game.current_order = o

	var screen = load("res://scenes/repair.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	for i in o.phone.screws:
		screen._tap_screw(i, screen._screw_buttons[i])
	await get_tree().process_frame
	check(screen._stage == 1, "пайка: разборка завершена")

	var pads := []
	for c in screen._phone_area.get_children():
		if c is Button and String(c.text).ends_with("%"):
			pads.append(c)
	check(pads.size() == 4, "пайка: 4 контакта")

	for pad in pads:
		screen._start_solder(pad)
		screen._process(0.8)   # «держим палец» дольше 0.7 с
		await get_tree().process_frame
	check(screen._stage == 2, "пайка: все контакты припаяны")

	Game.current_order = null
	screen.queue_free()
	await get_tree().process_frame


func _test_cleaning() -> void:
	Game._seed_new_game()
	var o := Order.new()
	o.phone = DB.phone("s3")
	o.fault = DB.fault("liquid")
	o.client_type = DB.client("regular")
	o.price = 1200
	Game.current_order = o

	var screen = load("res://scenes/repair.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	for i in o.phone.screws:
		screen._tap_screw(i, screen._screw_buttons[i])
	await get_tree().process_frame
	check(screen._stage == 1, "залитие: разборка завершена")

	var spots := []
	for c in screen._phone_area.get_children():
		if c is Button and c.text == "грязь":
			spots.append(c)
	check(spots.size() == 6, "залитие: 6 пятен на плате")

	for spot in spots:
		screen._clean_spot(spot)
		screen._clean_spot(spot)
	await get_tree().process_frame
	check(screen._stage == 2, "залитие: чистка завершена, можно проверять")

	Game.current_order = null
	screen.queue_free()
	await get_tree().process_frame


func _test_order_screen() -> void:
	Game._seed_new_game()
	var order := _pick_repair_order()
	order.client_type = DB.client("regular")
	Game.pending_order = order

	var screen = load("res://scenes/order.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	check(screen._order == order, "order: заказ открыт")
	var has_fault_menu := false
	for b in screen.find_children("*", "Button", true, false):
		var t := String(b.text)
		if t.contains("Разбит") or t.contains("Залитие") or t.contains("Батарея"):
			has_fault_menu = true
	check(not has_fault_menu, "order: нет меню выбора поломки")

	screen.queue_free()
	await get_tree().process_frame
	Game.pending_order = null
	Game.return_order(order)


func _test_device_model() -> void:
	var phone := DB.phone("s3")
	var defect := DB.defect("battery_swollen")
	var m := DeviceModel.new()
	m.setup(phone, defect)

	check(not m.remove("back_cover", "suction").ok, "device: крышка без снятия винтов запрещена")
	check(m.unscrew("bottom_screws", 0, "torx").code == "WRONG_BIT", "device: не та бита")
	check(m.damage == 2, "device: урон от неверной биты")

	for i in m.screws_total("bottom_screws"):
		check(m.unscrew("bottom_screws", i, "pentalobe").ok, "device: винт корпуса выкручен")
	check(m.is_done("bottom_screws"), "device: группа винтов снята")
	check(m.remove("back_cover", "suction").ok, "device: крышка снята")
	check(m.is_exposed("battery"), "device: аккумулятор виден")

	check(m.remove("shield_plate", "spudger").code == "SCREWS", "device: щит без винтов не снять")
	for i in m.screws_total("shield_plate"):
		check(m.unscrew("shield_plate", i, "torx").ok, "device: винт щита выкручен")
	check(m.remove("shield_plate", "spudger").ok, "device: щит снят")

	var ins := m.inspect("battery")
	check(ins.ok and bool(ins["anomaly"]), "device: вздутие найдено осмотром")
	check(m.evidence.size() == 1, "device: улика записана")

	var meas := m.measure("BAT", "V")
	check(meas.ok and bool(meas["faulty"]), "device: просадка BAT подтверждена")
	check(not m.measure("BAT", "R").ok, "device: неверный режим прибора отклонён")

	check(not m.confirm("board").ok, "device: чужой узел не подтверждается")
	check(m.confirm("battery").ok, "device: диагноз подтверждён")
	check(m.diagnosed, "device: флаг диагноза")


func _test_teardown_scene() -> void:
	Game._seed_new_game()
	var order := _pick_repair_order()
	order.client_type = DB.client("regular")
	order.defect = DB.defect("battery_swollen")
	order.fault = DB.fault("battery")
	Game.current_order = order

	var td = load("res://scenes/teardown.tscn").instantiate()
	add_child(td)
	await get_tree().process_frame
	await get_tree().process_frame
	check(td.model != null, "teardown: модель создана")

	var m: DeviceModel = td.model
	for i in m.screws_total("bottom_screws"):
		m.unscrew("bottom_screws", i, "pentalobe")
	check(m.remove("back_cover", "suction").ok, "teardown: крышка снята")
	for i in m.screws_total("shield_plate"):
		m.unscrew("shield_plate", i, "torx")
	check(m.remove("shield_plate", "spudger").ok, "teardown: щит снят")

	m.inspect("battery")
	td._refresh()
	td._confirm("battery")
	await get_tree().process_frame
	check(td._overlay != null, "teardown: открылась смета")
	td._close_overlay()
	check(td._overlay == null, "teardown: смета закрывается")

	Game.current_order = null
	td.queue_free()
	await get_tree().process_frame


func _test_ui(width: int, height: int, label: String) -> void:
	get_tree().root.size = Vector2i(width, height)
	await get_tree().process_frame
	await get_tree().process_frame

	var viewport := get_viewport().get_visible_rect()
	var screens := {
		"workshop": "res://scenes/workshop.tscn",
		"inventory": "res://scenes/inventory.tscn",
		"shop": "res://scenes/shop.tscn",
		"showcase": "res://scenes/showcase.tscn",
	}
	for key in screens.keys():
		var packed: PackedScene = load(String(screens[key]))
		var inst = packed.instantiate()
		add_child(inst)
		await get_tree().process_frame
		await get_tree().process_frame
		_check_screen(inst, viewport, "%s / %s" % [label, key])
		inst.queue_free()
		await get_tree().process_frame

	# Экран заказа — с реальным клиентом
	Game._seed_new_game()
	Game.pending_order = _pick_repair_order()
	var order_scene = load("res://scenes/order.tscn").instantiate()
	add_child(order_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	_check_screen(order_scene, viewport, "%s / order" % label)
	order_scene.queue_free()
	await get_tree().process_frame

	# Экран ремонта — полный проход мини-игр
	Game._seed_new_game()
	var order: Order = _pick_repair_order()
	order.client_type = DB.client("regular")
	Game.add_part(order.fault.part_type, "copy", order.phone.tier, 1)
	Game.accept_order(order, "copy", 1000)
	var repair = load("res://scenes/repair.tscn").instantiate()
	add_child(repair)
	await get_tree().process_frame
	await get_tree().process_frame
	_check_screen(repair, viewport, "%s / repair" % label)
	await _play_repair(repair)
	repair.queue_free()
	await get_tree().process_frame


func _play_repair(repair) -> void:
	var order: Order = Game.current_order
	if order == null:
		check(false, "repair: нет текущего заказа")
		return

	if not order.teardown_done:
		check(repair._screw_buttons.size() == order.phone.screws, "винтов столько же, сколько у модели")
		for i in order.phone.screws:
			repair._tap_screw(i, repair._screw_buttons[i])
		await get_tree().process_frame
		check(repair._stage == 1, "после винтов начинается этап ремонта")

	if repair._module != null:
		# Замена модуля
		repair._module.global_position = repair._socket.global_position + (repair._socket.size - repair._module.size) * 0.5
		repair._try_snap()
		await get_tree().process_frame
		check(repair._module_placed, "деталь установлена")
	elif repair._spots_left > 0:
		# Чистка
		for c in repair._phone_area.get_children():
			if c is Button and c.text == "грязь":
				repair._clean_spot(c)
				repair._clean_spot(c)
	elif repair._stage == 1:
		# Пайка
		for c in repair._phone_area.get_children():
			if c is Button and String(c.text).ends_with("%"):
				repair._start_solder(c)
				repair._process(0.8)
	await get_tree().process_frame
	check(repair._stage == 2, "этап проверки")

	var money_before := Game.money
	repair._on_action()
	await get_tree().process_frame
	check(Game.current_order == null, "ремонт завершён")
	check(Game.money >= money_before, "деньги не уменьшились")


func _check_screen(root: Control, viewport: Rect2, label: String) -> void:
	# Кнопки не меньше 44 dp (в дизайн-пикселях 88 при ширине 720)
	var buttons := root.find_children("*", "Button", true, false)
	check(buttons.size() > 0, "%s: есть кнопки" % label)
	for b in buttons:
		var min_h: float = b.custom_minimum_size.y
		if min_h > 0 and min_h < 88:
			check(false, "%s: кнопка ниже 88 px (%.0f) «%s»" % [label, min_h, b.text])

	# Крупные элементы интерфейса не вылезают за экран
	for node in root.find_children("*", "Control", true, false):
		if _inside_scroll(node):
			continue
		if node is NavBar or node is TopBar:
			var rect: Rect2 = node.get_global_rect()
			check(rect.position.y >= -2 and rect.end.y <= viewport.size.y + 2, "%s: %s в пределах экрана" % [label, node.get_class()])


func _inside_scroll(node: Node) -> bool:
	var p := node.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false