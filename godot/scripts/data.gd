class_name GameData
extends RefCounted

# Denge sayıları ve oyuncuya görünen metinler. Temel değerler tarayıcı sürümündeki src/data'dan gelir;
# kaynaklar, Yemekhane, Sofiler, hastaneye dönüş ve dalga dalga artan zorluk Godot sürümüne eklenmiştir.
# Mesafeler kare, süreler saniye.

const MAP := {
	"cols": 9,
	"rows": 16,
	"wall_row": 12,
	"path": [[1, -1], [1, 2], [6, 2], [6, 5], [2, 5], [2, 8], [7, 8], [7, 10], [4, 10], [4, 12]],
	"seed": 1453,
	# okçu askerlerinin surların önündeki yerleri (kare biriminde x, y)
	# Odun-Demir Ocağı işçilerinin çalıştığı yerler: sol kapı önünde kesim alanı, sağda demir madeni (kule kurulamaz)
	"lumber_site": [0, 11],
	"mine_site": [8, 11],
	"archer_posts": [[3.3, 11.25], [5.7, 11.25], [2.5, 11.5], [6.5, 11.5], [1.7, 11.5], [7.3, 11.5]],
}

const RULES := {
	"start_gold": 400,
	"start_wall": 20,
	# kaynaklar: askerler akçenin yanında odun, demir ve yemekle yetişir
	"start_res": {"wood": 60, "iron": 40, "food": 80},
	# her dalgada düşman canı hp_growth ile, kalabalık birliklerin sayısı count_growth ile, hızı speed_growth ile artar
	"count_growth": 0.06,
	"speed_growth": 0.015,
	"wave_bonus_base": 40,
	"wave_bonus_per_wave": 10,
	# düşman ödülleri bu çarpanla verilir (tarayıcı sürümünden bol)
	"reward_mult": 1.5,
	"sell_ratio": 0.7,
	"hp_growth": 1.2,
	"first_spawn_delay": 0.3,
	"max_step": 0.03,
	"max_frame": 0.1,
	"speeds": [1, 2, 3],
	"muzzle_offset": 0.3,
	"hit_flash": 0.08,
	"shake_time": 0.25,
}

const RAID := {
	"first_wave": 2,
	"min_delay": 45.0,
	"max_delay": 70.0,
	"base_count": 4,
	"count_per_wave": 0.5,
	"unit": "light",
	"gap": 0.45,
	"bonus": 25,
}

const TOWERS := {
	"archer": {"cost": 50, "range": 2.6, "damage": 11, "rate": 0.55, "speed": 10.0, "color": "#e0503c"},
	"tar": {"cost": 70, "range": 2.2, "damage": 5, "rate": 0.9, "speed": 8.0, "slow": 0.45, "slow_time": 1.6, "color": "#8a6cff"},
	"cannon": {"cost": 90, "range": 2.3, "damage": 28, "rate": 1.5, "speed": 6.0, "splash": 0.95, "color": "#f2a33a", "unlock": "science"},
	"musket": {"cost": 120, "range": 3.2, "damage": 46, "rate": 1.7, "speed": 0.0, "pierce": true, "color": "#3fb6d9", "unlock": "barracks"},
}
const TOWER_ORDER := ["archer", "tar", "cannon", "musket"]

const UPGRADE := {"max_level": 3, "cost_factor": 0.75, "damage_mult": 1.6, "range_add": 0.35, "rate_mult": 0.9, "slow_add": 0.1, "slow_max": 0.7}

# hız: kare/sn, radius: yarıçap. mount: atlı, siege: kuşatma aracı (askerler durduramaz).
const ENEMIES := {
	"infantry": {"hp": 42, "speed": 1.1, "armor": 0, "reward": 5, "damage": 1, "radius": 0.22, "melee": 6},
	"light": {"hp": 28, "speed": 2.0, "armor": 0, "reward": 6, "damage": 1, "radius": 0.2, "melee": 5, "mount": true},
	"knight": {"hp": 150, "speed": 0.7, "armor": 4, "reward": 12, "damage": 2, "radius": 0.27, "melee": 12},
	"horseArcher": {"hp": 36, "speed": 1.8, "armor": 1, "reward": 7, "damage": 1, "radius": 0.21, "melee": 5, "mount": true},
	"ram": {"hp": 260, "speed": 0.6, "armor": 6, "reward": 20, "damage": 3, "radius": 0.32, "melee": 0, "siege": true},
	"siegeTower": {"hp": 1100, "speed": 0.5, "armor": 3, "reward": 70, "damage": 6, "radius": 0.38, "melee": 0, "siege": true, "warning": true},
	"commander": {"hp": 2400, "speed": 0.42, "armor": 6, "reward": 150, "damage": 10, "radius": 0.42, "melee": 30, "mount": true, "warning": true},
}
const ENEMY_MELEE := {"rate": 1.0, "growth": 0.08}

const NATIONS := {
	"ottoman": {"primary": "#c41e2a", "secondary": "#f4f1e8", "metal": "#c9a86a"},
	"byzantium": {"primary": "#6b2d8f", "secondary": "#e8c547", "metal": "#c9b26a"},
	"serbia": {"primary": "#b8323a", "secondary": "#2f5fa8", "metal": "#a9adb8"},
	"hungary": {"primary": "#c0392b", "secondary": "#f4f1e8", "metal": "#a9adb8"},
	"venice": {"primary": "#8e1b24", "secondary": "#e3b341", "metal": "#c9b26a"},
	"mamluk": {"primary": "#e2b33c", "secondary": "#7a4a24", "metal": "#c9a86a"},
	"safavid": {"primary": "#2f8f4e", "secondary": "#c0392b", "metal": "#a9adb8"},
	"poland": {"primary": "#d23c3c", "secondary": "#f4f1e8", "metal": "#b3b7c2"},
	"habsburg": {"primary": "#2b2b2b", "secondary": "#e3b341", "metal": "#8f939e"},
	"spain": {"primary": "#c0392b", "secondary": "#f1c40f", "metal": "#b3b7c2"},
	"russia": {"primary": "#f0eee8", "secondary": "#2f5fa8", "metal": "#a9adb8"},
	"france": {"primary": "#2b4fa0", "secondary": "#f1d36b", "metal": "#b3b7c2"},
	"holyLeague": {"primary": "#f4f1e8", "secondary": "#c0392b", "metal": "#c3c7d0"},
}

# Her dalga bir devletin seferidir. Gruplar sırayla çıkar: [birlik, adet, aralık]
const WAVES := [
	{"nation": "byzantium", "groups": [["infantry", 10, 0.9]]},
	{"nation": "serbia", "groups": [["infantry", 14, 0.75]]},
	{"nation": "hungary", "groups": [["infantry", 8, 0.8], ["light", 8, 0.5]]},
	{"nation": "venice", "groups": [["knight", 5, 1.2], ["infantry", 10, 0.6], ["horseArcher", 6, 0.6]]},
	{"nation": "mamluk", "groups": [["light", 20, 0.4], ["siegeTower", 1, 2.0]]},
	{"nation": "safavid", "groups": [["knight", 10, 1.0], ["horseArcher", 8, 0.5], ["infantry", 12, 0.5]]},
	{"nation": "poland", "groups": [["light", 14, 0.4], ["knight", 10, 0.9], ["ram", 3, 1.5]]},
	{"nation": "habsburg", "groups": [["knight", 18, 0.8], ["siegeTower", 1, 2.0], ["ram", 4, 1.4]]},
	{"nation": "spain", "groups": [["light", 22, 0.35], ["horseArcher", 10, 0.4], ["knight", 12, 0.7]]},
	{"nation": "russia", "groups": [["knight", 16, 0.8], ["horseArcher", 8, 0.4], ["ram", 5, 1.2], ["siegeTower", 1, 2.0]]},
	{"nation": "france", "groups": [["infantry", 24, 0.3], ["knight", 14, 0.7], ["siegeTower", 2, 2.5]]},
	{"nation": "holyLeague", "groups": [["knight", 10, 0.9], ["siegeTower", 2, 2.5], ["commander", 1, 2.0], ["light", 16, 0.35], ["ram", 5, 1.2]]},
]

# Oyuncunun seçebileceği devletler. Her devletin bir hükümdarı vardır; hükümdar menüde "şeref" ile
# geliştirilir ve her seviyede devletin üstünlüğü (bonus) artar. Seçilen devlet düşman dalgalarında
# görünürse o seferi Osmanlı yapar. bonus: tower_damage | wall | gold | troops | range | rate
const COUNTRIES := {
	"ottoman": {"short": "OSMANLI", "ruler": "Fatih Sultan Mehmed", "title": "Padişah", "bonus": "tower_damage",
		"text": "Kuleler daha sert vurur"},
	"byzantium": {"short": "BİZANS", "ruler": "XI. Konstantinos", "title": "İmparator", "bonus": "wall",
		"text": "Surlar daha sağlam, dalga sonu onarım"},
	"venice": {"short": "VENEDİK", "ruler": "Francesco Foscari", "title": "Doç", "bonus": "gold",
		"text": "Bol akçe: başlangıç akçesi ve düşman ödülü artar"},
	"safavid": {"short": "SAFEVÎ", "ruler": "Şah İsmail", "title": "Şah", "bonus": "troops",
		"text": "Askerler daha güçlü ve dayanıklı"},
	"habsburg": {"short": "HABSBURG", "ruler": "V. Karl", "title": "İmparator", "bonus": "range",
		"text": "Kulelerin menzili uzun"},
	"mamluk": {"short": "MEMLÜK", "ruler": "Kayıtbay", "title": "Sultan", "bonus": "rate",
		"text": "Kuleler daha hızlı atar"},
}
const COUNTRY_ORDER := ["ottoman", "byzantium", "venice", "safavid", "habsburg", "mamluk"]

# Hükümdar: 1. seviyeden başlar. Bir üst seviyenin bedeli cost_per_level × şimdiki seviye şereftir.
# Şeref her püskürtülen dalgada dalga × honor_per_wave, zaferde ayrıca honor_win kazanılır.
# per_level: bonus türüne göre seviye başına artış (1. seviyede de bir kez uygulanır).
const KING := {
	"max_level": 5,
	"cost_per_level": 120,
	"honor_per_wave": 10,
	"honor_win": 250,
	"per_level": {"tower_damage": 0.06, "wall": 3, "gold": 0.07, "troops": 0.08, "range": 0.08, "rate": 0.05},
	"start_gold": 40,  # gold bonusunda seviye başına ek başlangıç akçesi
}


static func king_text(country: String, level: int) -> String:
	if level <= 0:
		return ""
	var b: String = COUNTRIES[country].bonus
	var v = KING.per_level[b] * level
	match b:
		"tower_damage":
			return "Kule hasarı +%s" % pct(v)
		"wall":
			return "Sur +%d · dalga sonu Sur +%d" % [v, ceili(level / 2.0)]
		"gold":
			return "Başlangıç +%d akçe · ödül +%s" % [KING.start_gold * level, pct(v)]
		"troops":
			return "Asker canı ve hasarı +%s" % pct(v)
		"range":
			return "Kule menzili +%s kare" % num(v, 2)
		"rate":
			return "Kule atış hızı +%s" % pct(v)
	return ""


# "Doç Francesco Foscari", "Şah İsmail" (unvan adın içindeyse tekrarlanmaz)
static func ruler_name(country: String) -> String:
	var c: Dictionary = COUNTRIES[country]
	return c.ruler if c.ruler.begins_with(c.title) else "%s %s" % [c.title, c.ruler]


static func king_cost(level: int) -> int:
	return KING.cost_per_level * level


# Şehir binaları. slot: surların içindeki arsa [sütun, satır]. costs: seviye 1/2/3 maliyeti.
const BUILDINGS := {
	"palace": {"slot": [4, 14], "costs": [0, 260, 480], "start": 1, "color": "#e0b24a"},
	"school": {"slot": [1, 13], "costs": [80, 160, 240], "color": "#5aa0d8"},
	"barracks": {"slot": [7, 13], "costs": [100, 200, 300], "color": "#c23b32"},
	"archery": {"slot": [0, 14], "costs": [70, 150, 240], "color": "#e0503c"},
	# up_requires: 2. seviyeden itibaren gereken bina (Darüşşifa'yı geliştirmek için Bilimhane)
	"hospital": {"slot": [2, 15], "costs": [90, 180, 270], "color": "#5cc48a", "up_requires": {"science": 1}},
	"cavalry": {"slot": [8, 14], "costs": [140, 240, 340], "requires": {"barracks": 1}, "color": "#b5793a"},
	"science": {"slot": [1, 15], "costs": [120, 220, 320], "requires": {"school": 1}, "color": "#f2a33a"},
	"religion": {"slot": [6, 15], "costs": [110, 210, 310], "requires": {"mosque": 1}, "color": "#e8d48a"},
	"court": {"slot": [5, 13], "costs": [100, 200, 300], "color": "#9b7bd1"},
	"mosque": {"slot": [7, 15], "costs": [120, 240, 360], "color": "#7fc8c0"},
	"kitchen": {"slot": [6, 14], "costs": [70, 140, 220], "color": "#d9893b"},
	"market": {"slot": [3, 13], "costs": [60, 130, 220], "color": "#e0a030"},
	"workshop": {"slot": [8, 13], "costs": [80, 160, 240], "color": "#8a6a48"},
}
const BUILDING_ORDER := ["palace", "school", "barracks", "archery", "hospital", "cavalry", "science", "religion", "court", "mosque", "kitchen", "workshop", "market"]
# Saray yükseltmesi akçeye ek olarak odun ve demir ister (indeks = kurulacak seviye)
const PALACE_RES := [{}, {}, {"wood": 60, "iron": 30}, {"wood": 120, "iron": 60}]
# Binalar Saray'ın bir üst seviyesine kadar çıkar: Saray 1 iken en fazla 2, Saray 2 iken 3
const FREE_LEVELS := 1
const MAX_BUILDING_LEVEL := 3

const CITY := {
	"school_discount": 0.1,
	"archery_damage": 0.2,
	"archery_range": 0.15,
	"hospital_repair": 1,
	"science_cannon": 0.15,
	"science_tar": 0.05,
	"court_tax": 12,
	"court_raid_delay": 0.2,
	"mosque_endowment": 10,
	# dalga sonu kaynak geliri: Saray seviyesi başına odun ve demir, Yemekhane seviyesi başına yemek
	"palace_wood": 25,
	"palace_iron": 15,
	"kitchen_food": 40,
	# Çarşı: her market_interval saniyede seviye başına market_gold akçe; Saray dalga sonu seviye başına vergi
	"market_interval": 5.0,
	"market_gold": 4,
	"palace_tax": 20,
	# Odun-Demir Ocağı: seviye başına işçi; her işçi bir yük getirir (oduncu odun, madenci demir)
	"workers_per_level": 2,
	"wood_load": 3,
	"iron_load": 2,
	# Darüşşifa: canı bu oranın altına düşen asker hastaneye gider; hastanede sn'de taban + seviye başına iyileşir
	"wounded_ratio": 0.35,
	"ward_heal": 18.0,
	"ward_heal_level": 12.0,
	"minarets": [0, 1, 2, 4],
}

# "Allah Allah!" hücumu (Meşihat seviyesine göre; indeks = seviye)
const CHARGE := {"boost": [0.0, 0.3, 0.45, 0.6], "duration": [0, 6, 8, 10], "cooldown": [0, 60, 50, 40]}

# res: akçe dışındaki eğitim bedeli. Yeniçeri en güçlü askerdir.
const TROOPS := {
	"janissary": {"building": "barracks", "role": "melee", "cost": 60, "res": {"food": 15, "iron": 10}, "train": 5.0, "per_level": 2,
		"hp": 230, "damage": 19, "rate": 0.65, "range": 0.6, "block": 2, "speed": 1.3},
	"archer": {"building": "archery", "role": "ranged", "cost": 35, "res": {"food": 10, "wood": 10}, "train": 3.5, "per_level": 2,
		"hp": 60, "damage": 8, "rate": 0.9, "range": 2.4, "block": 0, "speed": 1.2, "projectile": 10.0},
	"sipahi": {"building": "cavalry", "role": "melee", "cost": 70, "res": {"food": 20, "iron": 8, "wood": 6}, "train": 6.0, "per_level": 1,
		"hp": 170, "damage": 14, "rate": 0.8, "range": 0.65, "block": 2, "speed": 2.2},
	# Sofiler camiden çıkar; savaşırken yanındaki askerlere can verir
	"sufi": {"building": "mosque", "role": "melee", "cost": 30, "res": {"food": 15}, "train": 4.0, "per_level": 2,
		"hp": 90, "damage": 7, "rate": 0.8, "range": 0.6, "block": 1, "speed": 1.2, "heal": 3.0, "heal_range": 1.3},
}
const TROOP_ORDER := ["janissary", "archer", "sipahi", "sufi"]
const RES_ORDER := ["wood", "iron", "food"]
const RES_NAMES := {"wood": "odun", "iron": "demir", "food": "yemek"}

const ARMY := {
	"level_bonus": 0.25,
	"regen_build": 10.0,
	"hospital_regen": 2.0,
	"block_gap": 0.38,
	"first_post": 0.75,
	"post_spacing": 0.6,
	"post_side": 0.24,
}


static func wave_bonus(n: int) -> int:
	return RULES.wave_bonus_base + n * RULES.wave_bonus_per_wave


# n. dalgada (1'den başlar) bir grubun gerçek sayısı: kalabalık birlikler her dalgada çoğalır
static func group_count(count: int, n: int) -> int:
	if count < 4:
		return count
	return ceili(count * (1.0 + RULES.count_growth * maxi(0, n - 1)))


static func difficulty(n: int) -> float:
	return pow(RULES.hp_growth, maxi(0, n - 1))


static func sell_value(spent: int) -> int:
	return roundi(spent * RULES.sell_ratio)


static func upgrade_cost(type: String, level: int, discount: float) -> int:
	return roundi(TOWERS[type].cost * UPGRADE.cost_factor * level * (1.0 - discount))


# bonus: şehirden gelen çarpanlar {damage, range, slow}
static func tower_stats(type: String, level: int, bonus: Dictionary) -> Dictionary:
	var d: Dictionary = TOWERS[type]
	var n := level - 1
	var slow := 0.0
	if d.has("slow"):
		slow = minf(UPGRADE.slow_max, d.slow + UPGRADE.slow_add * n + bonus.get("slow", 0.0))
	return {
		"damage": roundi(d.damage * pow(UPGRADE.damage_mult, n) * (1.0 + bonus.get("damage", 0.0))),
		"range": d.range + UPGRADE.range_add * n + bonus.get("range", 0.0),
		"rate": d.rate * pow(UPGRADE.rate_mult, n),
		"slow": slow,
		"slow_time": d.get("slow_time", 0.0),
		"splash": d.get("splash", 0.0),
		"pierce": d.get("pierce", false),
		"speed": d.speed,
	}


# ---------------------------------------------------------------- metinler

const TOWER_NAMES := {
	"archer": ["Okçu Kulesi", "Hızlı, tek hedef"],
	"tar": ["Zift Kazanı", "Yavaşlatır"],
	"cannon": ["Balyemez Topu", "Alan hasarı"],
	"musket": ["Tüfekçi Tabyası", "Zırhı deler"],
}
const ENEMY_NAMES := {
	"infantry": "Piyade", "light": "Hafif Süvari", "knight": "Zırhlı Şövalye", "horseArcher": "Atlı Okçu",
	"ram": "Koçbaşı", "siegeTower": "Kuşatma Kulesi", "commander": "Başkomutan",
}
const NATION_NAMES := {
	"ottoman": "Osmanlı Devleti",
	"byzantium": "Bizans İmparatorluğu", "serbia": "Sırp Despotluğu", "hungary": "Macar Krallığı",
	"venice": "Venedik Cumhuriyeti", "mamluk": "Memlük Sultanlığı", "safavid": "Safevî Devleti",
	"poland": "Lehistan Krallığı", "habsburg": "Habsburg Monarşisi", "spain": "İspanya Krallığı",
	"russia": "Rus Çarlığı", "france": "Fransa Krallığı", "holyLeague": "Kutsal İttifak",
}
const BUILDING_NAMES := {
	"palace": ["Saray", "Padişahın sarayı"], "school": ["Mektep", "Okul"], "barracks": ["Kışla", "Yeniçeri Ocağı"],
	"archery": ["Okçu Ocağı", "Okçu geliştirme"], "hospital": ["Darüşşifa", "Hastane"], "cavalry": ["Sipahi Ocağı", "Atlı birlik"],
	"science": ["Bilimhane", "Bilim"], "religion": ["Meşihat", "Din işleri"], "court": ["Kadı Mahkemesi", "Adalet"],
	"mosque": ["Cami", "Sofiler ve vakıf"], "kitchen": ["Yemekhane", "Ordunun aşı"],
	"workshop": ["Odun-Demir Ocağı", "Oduncular ve madenciler"],
	"market": ["Çarşı", "Esnaf ve tüccar"],
}
const TROOP_NAMES := {"janissary": "Yeniçeri", "archer": "Okçu", "sipahi": "Sipahi", "sufi": "Sofi"}
const WARNINGS := {"siegeTower": "Kuşatma kulesi geliyor!", "commander": "Düşman başkomutanı sahada!"}


static func num(v: float, digits := 1) -> String:
	var s := String.num(v, digits)
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s.replace(".", ",")


static func pct(v: float) -> String:
	return "%" + str(roundi(v * 100))


static func troop_boost(l: int) -> String:
	return ", güç +" + pct(ARMY.level_bonus * (l - 1)) if l > 1 else ""


static func building_effect(id: String, l: int) -> String:
	match id:
		"palace":
			return "Binalar en fazla %d. seviye · dalga sonu +%d akçe vergi, +%d odun, +%d demir" % [mini(MAX_BUILDING_LEVEL, l + FREE_LEVELS), CITY.palace_tax * l, CITY.palace_wood * l, CITY.palace_iron * l]
		"school":
			return "Kule yükseltmeleri %s ucuz" % pct(CITY.school_discount * l)
		"barracks":
			return "Tüfekçi Tabyası açık · en fazla %d Yeniçeri%s" % [TROOPS.janissary.per_level * l, troop_boost(l)]
		"archery":
			return "Okçu Kulesi hasarı +%s, menzil +%s · en fazla %d okçu" % [pct(CITY.archery_damage * l), num(CITY.archery_range * l, 2), TROOPS.archer.per_level * l]
		"hospital":
			return "Yaralı askerler burada iyileşir (sn'de +%d can) · dalga sonu Sur +%d" % [roundi(CITY.ward_heal + CITY.ward_heal_level * l), CITY.hospital_repair * l]
		"cavalry":
			return "En fazla %d Sipahi (ikişer düşman durdurur)%s" % [TROOPS.sipahi.per_level * l, troop_boost(l)]
		"science":
			return "Balyemez açık · top hasarı +%s, zift +%s" % [pct(CITY.science_cannon * l), pct(CITY.science_tar * l)]
		"religion":
			return "\"Allah Allah!\" hücumu: atış hızı +%s, %d sn" % [pct(CHARGE.boost[l]), CHARGE.duration[l]]
		"court":
			return "Dalga sonu +%d akçe vergi, baskınlar seyrek" % (CITY.court_tax * l)
		"mosque":
			return "En fazla %d Sofi (yanındakilere can verir) · dalga sonu +%d akçe vakıf" % [TROOPS.sufi.per_level * l, CITY.mosque_endowment * l]
		"market":
			return "Her %d sn'de +%d akçe" % [roundi(CITY.market_interval), CITY.market_gold * l]
		"workshop":
			return "%d işçi: oduncular ağaçtan +%d odun, madenciler madenden +%d demir taşır" % [CITY.workers_per_level * l, CITY.wood_load, CITY.iron_load]
		"kitchen":
			return "Dalga sonu +%d yemek" % (CITY.kitchen_food * l)
	return ""


static func tower_feature(type: String, s: Dictionary) -> String:
	match type:
		"tar":
			return "%s yavaşlatma, %s sn" % [pct(s.slow), num(s.slow_time)]
		"cannon":
			return "Alan hasarı, yarıçap %s kare" % num(s.splash, 2)
		"musket":
			return "Zırhı tamamen deler"
	return "Hızlı atış, tek hedef"


static func join_list(items: Array) -> String:
	if items.size() < 2:
		return "".join(items)
	return ", ".join(items.slice(0, -1)) + " ve " + items[-1]


# Oyuncunun devleti dalgada düşman olarak çıkıyorsa o seferi Osmanlı yapar
static func wave_nation(i: int, country: String) -> String:
	var n: String = WAVES[i].nation
	return "ottoman" if n == country else n


static func describe_wave(i: int, country := "ottoman") -> String:
	if i >= WAVES.size():
		return ""
	var w: Dictionary = WAVES[i]
	var items := []
	for g in w.groups:
		items.append("%d %s" % [group_count(g[1], i + 1), ENEMY_NAMES[g[0]]])
	var hard := " Düşman canı ×%s." % num(difficulty(i + 1)) if i > 0 else ""
	return "Sıradaki sefer: %s — %s.%s" % [NATION_NAMES[wave_nation(i, country)], join_list(items), hard]
