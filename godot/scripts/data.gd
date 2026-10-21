class_name GameData
extends RefCounted

# Denge sayıları ve oyuncuya görünen metinler. Değerler tarayıcı sürümündeki src/data ile birebir aynıdır.
# Mesafeler kare, süreler saniye.

const MAP := {
	"cols": 9,
	"rows": 16,
	"wall_row": 12,
	"path": [[1, -1], [1, 2], [6, 2], [6, 5], [2, 5], [2, 8], [7, 8], [7, 10], [4, 10], [4, 12]],
	"seed": 1453,
	# okçu askerlerinin surların önündeki yerleri (kare biriminde x, y)
	"archer_posts": [[3.3, 11.25], [5.7, 11.25], [2.5, 11.5], [6.5, 11.5], [1.7, 11.5], [7.3, 11.5]],
}

const RULES := {
	"start_gold": 220,
	"start_wall": 20,
	"wave_bonus_base": 20,
	"wave_bonus_per_wave": 5,
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
	"bonus": 10,
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

# Şehir binaları. slot: surların içindeki arsa [sütun, satır]. costs: seviye 1/2/3 maliyeti.
const BUILDINGS := {
	"palace": {"slot": [4, 14], "costs": [0, 260, 480], "start": 1, "color": "#e0b24a"},
	"school": {"slot": [1, 13], "costs": [80, 160, 240], "color": "#5aa0d8"},
	"barracks": {"slot": [7, 13], "costs": [100, 200, 300], "color": "#c23b32"},
	"archery": {"slot": [0, 14], "costs": [70, 150, 240], "color": "#e0503c"},
	"hospital": {"slot": [2, 15], "costs": [90, 180, 270], "color": "#5cc48a"},
	"cavalry": {"slot": [8, 14], "costs": [140, 240, 340], "requires": {"barracks": 1}, "color": "#b5793a"},
	"science": {"slot": [1, 15], "costs": [120, 220, 320], "requires": {"school": 1}, "color": "#f2a33a"},
	"religion": {"slot": [6, 15], "costs": [110, 210, 310], "requires": {"mosque": 1}, "color": "#e8d48a"},
	"court": {"slot": [5, 13], "costs": [100, 200, 300], "color": "#9b7bd1"},
	"mosque": {"slot": [7, 15], "costs": [120, 240, 360], "color": "#7fc8c0"},
}
const BUILDING_ORDER := ["palace", "school", "barracks", "archery", "hospital", "cavalry", "science", "religion", "court", "mosque"]
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
	"minarets": [0, 1, 2, 4],
}

# "Allah Allah!" hücumu (Meşihat seviyesine göre; indeks = seviye)
const CHARGE := {"boost": [0.0, 0.3, 0.45, 0.6], "duration": [0, 6, 8, 10], "cooldown": [0, 60, 50, 40]}

const TROOPS := {
	"janissary": {"building": "barracks", "role": "melee", "cost": 40, "train": 4.0, "per_level": 2,
		"hp": 120, "damage": 10, "rate": 0.7, "range": 0.6, "block": 1, "speed": 1.3},
	"archer": {"building": "archery", "role": "ranged", "cost": 35, "train": 3.5, "per_level": 2,
		"hp": 60, "damage": 8, "rate": 0.9, "range": 2.4, "block": 0, "speed": 1.2, "projectile": 10.0},
	"sipahi": {"building": "cavalry", "role": "melee", "cost": 70, "train": 6.0, "per_level": 1,
		"hp": 200, "damage": 16, "rate": 0.8, "range": 0.65, "block": 2, "speed": 2.2},
}
const TROOP_ORDER := ["janissary", "archer", "sipahi"]

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
	"byzantium": "Bizans İmparatorluğu", "serbia": "Sırp Despotluğu", "hungary": "Macar Krallığı",
	"venice": "Venedik Cumhuriyeti", "mamluk": "Memlük Sultanlığı", "safavid": "Safevî Devleti",
	"poland": "Lehistan Krallığı", "habsburg": "Habsburg Monarşisi", "spain": "İspanya Krallığı",
	"russia": "Rus Çarlığı", "france": "Fransa Krallığı", "holyLeague": "Kutsal İttifak",
}
const BUILDING_NAMES := {
	"palace": ["Saray", "Padişahın sarayı"], "school": ["Mektep", "Okul"], "barracks": ["Kışla", "Yeniçeri Ocağı"],
	"archery": ["Okçu Ocağı", "Okçu geliştirme"], "hospital": ["Darüşşifa", "Hastane"], "cavalry": ["Sipahi Ocağı", "Atlı birlik"],
	"science": ["Bilimhane", "Bilim"], "religion": ["Meşihat", "Din işleri"], "court": ["Kadı Mahkemesi", "Adalet"],
	"mosque": ["Cami", "İbadet ve vakıf"],
}
const TROOP_NAMES := {"janissary": "Yeniçeri", "archer": "Okçu", "sipahi": "Sipahi"}
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
			return "Binalar en fazla %d. seviyeye çıkabilir" % l
		"school":
			return "Kule yükseltmeleri %s ucuz" % pct(CITY.school_discount * l)
		"barracks":
			return "Tüfekçi Tabyası açık · en fazla %d Yeniçeri%s" % [TROOPS.janissary.per_level * l, troop_boost(l)]
		"archery":
			return "Okçu Kulesi hasarı +%s, menzil +%s · en fazla %d okçu" % [pct(CITY.archery_damage * l), num(CITY.archery_range * l, 2), TROOPS.archer.per_level * l]
		"hospital":
			return "Her dalga sonunda Sur +%d · savaşta askerler sn'de +%s can" % [CITY.hospital_repair * l, num(ARMY.hospital_regen * l)]
		"cavalry":
			return "En fazla %d Sipahi (ikişer düşman durdurur)%s" % [TROOPS.sipahi.per_level * l, troop_boost(l)]
		"science":
			return "Balyemez açık · top hasarı +%s, zift +%s" % [pct(CITY.science_cannon * l), pct(CITY.science_tar * l)]
		"religion":
			return "\"Allah Allah!\" hücumu: atış hızı +%s, %d sn" % [pct(CHARGE.boost[l]), CHARGE.duration[l]]
		"court":
			return "Dalga sonu +%d akçe vergi, baskınlar seyrek" % (CITY.court_tax * l)
		"mosque":
			return "Dalga sonu +%d akçe vakıf geliri" % (CITY.mosque_endowment * l)
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


static func describe_wave(i: int) -> String:
	if i >= WAVES.size():
		return ""
	var w: Dictionary = WAVES[i]
	var items := []
	for g in w.groups:
		items.append("%d %s" % [g[1], ENEMY_NAMES[g[0]]])
	return "Sıradaki sefer: %s — %s." % [NATION_NAMES[w.nation], join_list(items)]
