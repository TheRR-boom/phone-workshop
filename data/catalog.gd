class_name Catalog
extends RefCounted
## Единый источник контента MVP: телефоны, неисправности, качества запчастей,
## типы клиентов и таблица цен. Здесь только чистые данные и формулы-хелперы,
## чтобы контент можно было вынести в .tres/JSON без правки игровой логики.

# --- Цены запчастей по типу и классу устройства (база «оригинал») ---
const PART_BASE := {
	"screen": {0: 900, 1: 3800, 2: 12000},
	"battery": {0: 700, 1: 1900, 2: 4200},
	"port": {0: 400, 1: 900, 2: 1800},
	"speaker": {0: 300, 1: 700, 2: 1200},
}

const PART_BADGES := {
	"screen": "Э",
	"battery": "Б",
	"port": "З",
	"speaker": "Д",
}

const PART_COLORS := {
	"screen": "#4aa8ff",
	"battery": "#38e8a0",
	"port": "#ffb020",
	"speaker": "#c07af0",
}

const PART_TITLES := {
	"screen": "Экран",
	"battery": "Аккумулятор",
	"port": "Разъём зарядки",
	"speaker": "Динамик",
}

# --- Качества запчастей ---
const QUALITIES := [
	{
		"id": "original", "title": "Оригинал", "cost_mul": 1.0,
		"reliability": 0.99, "warranty_days": 365, "color": "#38e8a0",
	},
	{
		"id": "copy", "title": "Копия", "cost_mul": 0.55,
		"reliability": 0.92, "warranty_days": 90, "color": "#ffb020",
	},
	{
		"id": "used", "title": "Б/У", "cost_mul": 0.30,
		"reliability": 0.78, "warranty_days": 14, "color": "#ff5a5f",
	},
]

# --- Устройства ---
const PHONES := [
	{
		"id": "k1", "title": "Volt K1", "tier": 0, "base_value": 900,
		"repairability": 1.0, "screws": 2, "color": "#4a5563",
	},
	{
		"id": "s3", "title": "Volt S3", "tier": 1, "base_value": 3800,
		"repairability": 0.92, "screws": 4, "color": "#3d5a7a",
	},
	{
		"id": "x20", "title": "Volt X20", "tier": 2, "base_value": 24000,
		"repairability": 0.78, "screws": 6, "color": "#5a4a6e",
	},
]

# --- Неисправности ---
const FAULTS := [
	{
		"id": "screen", "title": "Разбит экран",
		"symptom": "«Уронил, экран в трещинах и не реагирует»",
		"part_type": "screen", "labor": 600, "difficulty": 1.0,
		"needs_cleaning": false, "badge": "Э", "color": "#4aa8ff",
	},
	{
		"id": "battery", "title": "Сел аккумулятор",
		"symptom": "«Держит полдня и выключается на холоде»",
		"part_type": "battery", "labor": 400, "difficulty": 1.0,
		"needs_cleaning": false, "badge": "Б", "color": "#38e8a0",
	},
	{
		"id": "port", "title": "Не заряжается",
		"symptom": "«Зарядка идёт, только если держать провод боком»",
		"part_type": "port", "labor": 500, "difficulty": 1.2,
		"needs_cleaning": false, "badge": "З", "color": "#ffb020",
	},
	{
		"id": "liquid", "title": "Залитие",
		"symptom": "«Уронил в воду, теперь не включается»",
		"part_type": "", "labor": 800, "difficulty": 1.4,
		"needs_cleaning": true, "badge": "В", "color": "#4ac8d8",
	},
	{
		"id": "speaker", "title": "Не слышно собеседника",
		"symptom": "«Меня не слышно при звонке, на громкой — нормально»",
		"part_type": "speaker", "labor": 450, "difficulty": 1.1,
		"needs_cleaning": false, "badge": "Д", "color": "#c07af0",
	},
]

# --- Клиенты ---
const CLIENTS := [
	{
		"id": "regular", "title": "Обычный", "description": "Спокойный, платит по рынку",
		"pay_bonus": 0.0, "patience": 2, "scam_chance": 0.0, "rep_mul": 1.0,
		"color": "#8fa3b8",
	},
	{
		"id": "urgent", "title": "Срочный", "description": "Готов доплатить за скорость",
		"pay_bonus": 0.15, "patience": 0, "scam_chance": 0.05, "rep_mul": 1.0,
		"color": "#ffb020",
	},
	{
		"id": "karen", "title": "Скандальный", "description": "Торгуется до последнего",
		"pay_bonus": -0.10, "patience": 3, "scam_chance": 0.15, "rep_mul": 1.5,
		"color": "#ff5a5f",
	},
	{
		"id": "loyal", "title": "Постоянник", "description": "Платит чуть больше, ценит качество",
		"pay_bonus": 0.07, "patience": 1, "scam_chance": 0.0, "rep_mul": 1.2,
		"color": "#38e8a0",
	},
	{
		"id": "scammer", "title": "Мошенник", "description": "Любит «возврат после ремонта»",
		"pay_bonus": 0.10, "patience": 1, "scam_chance": 0.5, "rep_mul": 1.0,
		"color": "#c07af0",
	},
]

const CLIENT_NAMES := [
	"Алексей", "Марина", "Игорь", "Ольга", "Дмитрий",
	"Света", "Ринат", "Юля", "Пётр", "Анна", "Костя", "Лена",
]

# --- Улучшения мастерской ---
const UPGRADES := [
	{
		"id": "heatgun", "title": "Фен для клея", "price": 1500,
		"desc": "Экраны и батареи снимаются аккуратнее: +6% к успеху",
		"bonus": "+6% успех",
	},
	{
		"id": "ultrasonic", "title": "Ультразвуковая ванна", "price": 2500,
		"desc": "Залития чистятся лучше: +12% к успеху на воде",
		"bonus": "+12% залитие",
	},
	{
		"id": "advertising", "title": "Реклама в районе", "price": 1200,
		"desc": "+1 клиент в день",
		"bonus": "+1 клиент",
	},
	{
		"id": "showcase_light", "title": "Подсветка витрины", "price": 2000,
		"desc": "Телефоны продаются охотнее: +15% к шансу продажи",
		"bonus": "+15% продажи",
	},
]


## Цена запчасти в рублях для конкретного класса устройства.
static func part_cost(part_type: String, tier: int, quality_id: String) -> int:
	if part_type == "":
		return 0
	var by_tier: Dictionary = PART_BASE.get(part_type, {})
	var base: int = int(by_tier.get(clampi(tier, 0, 2), 500))
	return int(round(base * float(quality_by_id(quality_id).get("cost_mul", 1.0))))


static func quality_by_id(quality_id: String) -> Dictionary:
	for q in QUALITIES:
		if q["id"] == quality_id:
			return q
	return QUALITIES[0]


static func part_title(part_type: String) -> String:
	return String(PART_TITLES.get(part_type, "Деталь"))


static func part_badge(part_type: String) -> String:
	return String(PART_BADGES.get(part_type, "?"))


static func part_color(part_type: String) -> Color:
	return Color(String(PART_COLORS.get(part_type, "#8fa3b8")))


static func tier_title(tier: int) -> String:
	match tier:
		0:
			return "Кнопочные"
		1:
			return "Старые смартфоны"
		_:
			return "Современные"