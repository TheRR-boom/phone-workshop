class_name Econ
extends RefCounted
## Экономика и вероятности. Только чистые функции: их удобно проверять
## headless-тестами и балансировать, не запуская игру.

const RENT := 300           ## аренда мастерской за день
const START_MONEY := 3000
const START_REP := 50

## Рыночная цена работы «как в среднем по району» — от неё торгуется клиент.
static func market_price(phone: PhoneModel, fault: Fault) -> int:
	var labor := float(fault.labor) * (1.0 + phone.tier * 0.12) * fault.difficulty
	var part := float(Catalog.part_cost(fault.part_type, phone.tier, "original"))
	return int(round(labor + part))


## Себестоимость: запчасть выбранного качества + работа.
static func cost_price(phone: PhoneModel, fault: Fault, quality_id: String) -> int:
	var labor := float(fault.labor) * (1.0 + phone.tier * 0.12) * fault.difficulty
	var part := 0.0
	if quality_id != "":
		part = float(Catalog.part_cost(fault.part_type, phone.tier, quality_id))
	return int(round(labor + part))


## Потолок, который клиент готов заплатить. Зависит от характера и репутации.
static func client_ceiling(phone: PhoneModel, fault: Fault, client: ClientType, rep: int) -> int:
	var market := float(market_price(phone, fault))
	var mood := 1.0 + client.pay_bonus
	var rep_bonus := 0.9 + float(rep) / 300.0
	return int(round(market * mood * rep_bonus))


## Рекомендованная цена — с наценкой 10–15 %.
static func suggested_price(phone: PhoneModel, fault: Fault, rep: int) -> int:
	var market := float(market_price(phone, fault))
	return int(round(market * (1.05 + float(rep) / 1000.0)))


## Реакция клиента на названную цену: текст и цвет для UI.
static func reaction(price: int, ceiling: int) -> Dictionary:
	if price <= int(ceiling * 0.7):
		return {"text": "Подозрительно дёшево", "color": UI.WARN, "ok": true}
	if price <= ceiling:
		return {"text": "Клиент согласен", "color": UI.ACCENT, "ok": true}
	if price <= int(ceiling * 1.15):
		return {"text": "Дороговато, но можно", "color": UI.WARN, "ok": false}
	return {"text": "Слишком дорого", "color": UI.DANGER, "ok": false}


## Вероятность успешного ремонта.
static func success_chance(order: Order, upgrades: Dictionary) -> float:
	var base := 0.90
	if order.quality != null:
		base = order.quality.reliability
	if order.fault.needs_cleaning:
		base = 0.86
		if upgrades.has("ultrasonic"):
			base += 0.12
	if upgrades.has("heatgun") and (order.fault.part_type == "screen" or order.fault.part_type == "battery"):
		base += 0.06
	base *= order.phone.repairability
	return clampf(base, 0.4, 0.995)


## Шанс, что выставленный на витрину телефон купят сегодня.
static func sale_chance(price: int, base_value: int, rep: int, upgrades: Dictionary) -> float:
	var ratio := float(price) / maxf(1.0, float(base_value) * 1.1)
	var chance := clampf(1.1 - ratio, 0.15, 0.9) * (0.9 + float(rep) / 250.0)
	if upgrades.has("showcase_light"):
		chance += 0.15
	return clampf(chance, 0.05, 0.95)


## Отзыв клиента после ремонта. Немного юмора, но без абсурда.
static func review_text(success: bool, scam: bool, quality: PartQuality) -> String:
	if scam:
		return "«Верните деньги! Вчера всё работало, а сегодня нет!» — 1★"
	if not success:
		return "«Отдал телефон, забрал конструктор» — 1★"
	if quality != null and quality.id == "original":
		return "«Сделали как с завода, даже пыль вычистили» — 5★"
	if quality != null and quality.id == "used":
		return "«Работает, но корпус поцарапан. За эти деньги нормально» — 3★"
	return "«Экран как новый, спасибо!» — 5★"


## Сколько репутации принесёт заказ.
static func rep_delta(success: bool, scam: bool, order: Order) -> int:
	if scam:
		return -3
	if not success:
		return -5
	var delta := 3
	if order.quality != null:
		if order.quality.id == "original":
			delta += 1
		elif order.quality.id == "used":
			delta -= 1
	return int(round(delta * order.client_type.rep_mul))


## Опыт за заказ (уровень открывает современные телефоны).
static func xp_reward(order: Order, success: bool) -> int:
	if not success:
		return 10
	return 40 + int(round(order.fault.difficulty * 25.0))