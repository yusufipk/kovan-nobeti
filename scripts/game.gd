extends Node
# Endless run controller: cycle clock, deterministic scaling, spawning, upgrades, champions and Queen loops.

const CYCLE_TIME := 600.0
# a build is five weapons out of seven: once the belt is full, no new weapon is offered
const MAX_WEAPONS := 5

# kind "w" = weapon (desc per level), "p" = player trait (one desc, repeated per level)
const UPG := [
	{"id": "ari", "name": "Arı Sürüsü", "icon": 0, "max": 6, "kind": "w", "desc": ["En yakın düşmana güdümlü arı yollar", "+1 arı", "+5 hasar", "+1 arı, arılar bir düşmanı delip geçer", "%28 daha sık ateş eder", "+2 arı, +7 hasar, bir delme daha"]},
	{"id": "tutsu", "name": "Tütsü Halkası", "icon": 1, "max": 6, "kind": "w", "desc": ["Çevrendeki düşmanlar sürekli hasar alır", "Halka %22 genişler", "+3 hasar", "Halkadaki düşmanlar yavaşlar", "Halka %25 daha genişler", "+6 hasar, daha sık vurur"]},
	{"id": "bomba", "name": "Bal Bombası", "icon": 2, "max": 6, "kind": "w", "desc": ["Kalabalığın ortasına patlayan kavanoz atar", "+12 hasar", "+1 bomba", "Patlama %30 genişler", "%25 daha sık atılır", "+1 bomba, +22 hasar"]},
	{"id": "igne", "name": "İğne Çarkı", "icon": 3, "max": 6, "kind": "w", "desc": ["Etrafında dönen 2 iğne düşmanları biçer", "+1 iğne", "+5 hasar", "+1 iğne, çark hızlanır", "Çark %25 genişler", "+2 iğne, +9 hasar"]},
	{"id": "kivilcim", "name": "Polen Kıvılcımı", "icon": 4, "max": 6, "kind": "w", "desc": ["Düşmandan düşmana seken kıvılcım çakar", "+2 sekme", "+8 hasar", "%20 daha sık çakar", "+3 sekme", "Çift çakar, +14 hasar"]},
	{"id": "kule", "name": "Nöbetçi Kovan", "icon": 20, "max": 6, "kind": "w", "desc": ["Bastığın yere iğne atan bir kovan diker", "+5 hasar", "+1 kovan", "Kovanlar %30 daha sık atar", "Menzil %30 genişler, +6 hasar", "+1 kovan, +8 hasar"]},
	{"id": "iz", "name": "Bal İzi", "icon": 21, "max": 6, "kind": "w", "desc": ["Koşarken ardında bal bırakırsın, ize basan yavaşlar ve yanar", "+2 hasar", "İz 1,5 saniye daha kalır", "İz %30 genişler", "+3 hasar", "İz 1,5 saniye daha kalır, +4 hasar"]},
	{"id": "kalp", "name": "Bal Kalbi", "icon": 5, "max": 5, "kind": "p", "desc": "+20 can, 20 can iyileşir"},
	{"id": "cizme", "name": "Kanatlı Çizme", "icon": 6, "max": 5, "kind": "p", "desc": "+%8 koşu hızı"},
	{"id": "miknatis", "name": "Mıknatıs", "icon": 7, "max": 5, "kind": "p", "desc": "+%35 toplama menzili"},
	{"id": "ofke", "name": "Öfke", "icon": 8, "max": 5, "kind": "p", "desc": "Bütün silahlara +%14 hasar"},
	{"id": "saat", "name": "Çabuk El", "icon": 9, "max": 5, "kind": "p", "desc": "Silahlar %9 daha sık ateş eder"},
	{"id": "menzil", "name": "Geniş Etki", "icon": 10, "max": 5, "kind": "p", "desc": "+%12 etki alanı"},
	{"id": "cogalt", "name": "Çoğalt", "icon": 11, "max": 2, "kind": "p", "desc": "Her silaha +1 mermi"},
	{"id": "tulum", "name": "Kalın Tulum", "icon": 12, "max": 4, "kind": "p", "desc": "Her vuruştan 1,5 daha az hasar"},
	{"id": "yaprak", "name": "Şifalı Yaprak", "icon": 13, "max": 5, "kind": "p", "desc": "Saniyede +0,5 can yenilenir"},
	{"id": "kitap", "name": "Arıcı Defteri", "icon": 14, "max": 5, "kind": "p", "desc": "+%12 tecrübe"},
	{"id": "nisan", "name": "Keskin Göz", "icon": 15, "max": 5, "kind": "p", "desc": "+%8 kritik şansı, kritik 2 kat vurur"},
	{"id": "inis", "name": "Ezici İniş", "icon": 16, "max": 5, "kind": "p", "desc": "Zıplayıp inince şok dalgası, +12 hasar"},
	{"id": "kayis", "name": "Dikenli Kayış", "icon": 17, "max": 5, "kind": "p", "desc": "Kayarken çarptığın düşman +14 hasar alır, kayma sıklaşır"},
]

# A weapon at its last level evolves once its partner trait is high enough: weapon id -> [trait id, trait level, name, text]
const EVO := {
	"ari": ["cogalt", 2, "Kraliyet Sürüsü", "+2 arı, +10 hasar, bir delme daha"],
	"tutsu": ["menzil", 3, "Kara Duman", "Halka %45 genişler, +10 hasar"],
	"bomba": ["ofke", 3, "Bal Yağmuru", "+2 bomba, +30 hasar, patlama %25 genişler"],
	"igne": ["cizme", 3, "Diken Fırtınası", "+4 iğne, +14 hasar, çark hızlanır"],
	"kivilcim": ["saat", 3, "Polen Fırtınası", "+6 sekme, +20 hasar, %40 daha sık çakar"],
	"kule": ["tulum", 2, "Kovan Kalesi", "+1 kovan, +12 hasar, sönen kovan patlar"],
	"iz": ["miknatis", 3, "Alev Balı", "İz tutuşur: +8 hasar, izde ölen düşman patlar"],
}

# Beekeeping permanent upgrades bought with honey between runs. cost[n] buys level n + 1.
const META := [
	{"id": "can", "name": "Sağlam Tulum", "icon": 36, "cost": [15, 40, 80, 130, 200], "desc": "+8 can"},
	{"id": "guc", "name": "Keskin İğne", "icon": 31, "cost": [15, 40, 80, 130, 200], "desc": "+%4 hasar"},
	{"id": "hiz", "name": "Hafif Çizme", "icon": 6, "cost": [15, 40, 80, 130, 200], "desc": "+%2 koşu hızı"},
	{"id": "kepce", "name": "Geniş Kepçe", "icon": 7, "cost": [15, 40, 80, 130, 200], "desc": "+%8 toplama menzili"},
	{"id": "bilgi", "name": "Bilge Arı", "icon": 30, "cost": [15, 40, 80, 130, 200], "desc": "+%4 tecrübe"},
	{"id": "boru", "name": "Gür Boru", "icon": 22, "cost": [15, 40, 80, 130, 200], "desc": "Kovan Çağrısı %8 hızlı dolar"},
	{"id": "zar", "name": "Zar", "icon": 23, "cost": [40, 100, 180], "desc": "+1 kart yenileme"},
	{"id": "nefes", "name": "İkinci Nefes", "icon": 25, "cost": [200], "desc": "Turda bir kez ölümden dönersin"},
]

const HEAL_CARD := {"id": "sifa", "name": "Bal Kavanozu", "icon": 18, "max": 999, "kind": "p", "desc": "40 can iyileşir"}
const SRC_NAMES := {
	"ari": "Arı Sürüsü", "tutsu": "Tütsü Halkası", "bomba": "Bal Bombası", "igne": "İğne Çarkı",
	"kivilcim": "Polen Kıvılcımı", "inis": "Ezici İniş", "kayis": "Dikenli Kayış", "sunak": "Sunak",
	"patlak": "Patlak Zinciri", "kule": "Nöbetçi Kovan", "iz": "Bal İzi", "cagri": "Kovan Çağrısı", "nefes": "İkinci Nefes",
}
const KILL_COL := [
	Color(0.6, 0.25, 0.8), Color(0.95, 0.25, 0.2), Color(0.4, 0.3, 0.8), Color(1.0, 0.4, 0.7), Color(1.0, 0.2, 0.2),
	Color(1.0, 0.6, 0.15), Color(0.65, 0.85, 0.2), Color(0.9, 0.2, 0.15), Color(0.2, 0.75, 0.7),
]
# when the two champions arrive within each cycle, and what each is called
const CHAMP_TIMES := [200.0, 400.0]
const CHAMP_NAMES := ["MAKAS", "AKREP"]

var main
var active := false
var time := 0.0
var loop := 1
var loop_time := 0.0
var boss_kills := 0
var kills := 0
var level := 1
var xp := 0
var xp_need := 6
var xp_mult := 1.0
var passives := {}
var bonus_honey := 0
# permanent shrine blessings accumulated during this run
var shrine_dmg := 0.0
var shrine_cd := 1.0
var shrine_speed := 0.0
var shrine_area := 0.0
var queue: Array[String] = []
# champion/boss prizes not opened yet: each turns the next chest into an evolution
var evo_chests := 0
var last_magnet := 0.0
var stats := {"taken": 0.0, "dealt": 0.0, "by": {}, "chests": 0, "shrines": 0, "champs": 0, "bosses": 0}
var spawn_acc := 0.0
var next_wave := 60.0
var next_elite := 110.0
var boss_spawned := false
var over := false
var victory := false
var end_t := 0.0
var recycle_i := 0
var champs_sent := 0
# the hive call fills with kills (0..1); card rerolls and revives left in this run
var ult := 0.0
var ult_bank := 0.0
var rerolls := 2
var revives := 0
# staged moments, timed in real seconds: [{"t": float, "kind": String, "pos": Vector3, "size": float}]
var cues: Array[Dictionary] = []
# slow motion for a staged moment: real seconds left and the factor
var slow_t := 0.0
var slow_k := 1.0
var quiet_kills := false
# one-time hints, shown the first time each threat appears in a run
var hinted := {}
# bot telemetry fields
var last_event := ""
var last_event_ms := 0
var hits := {}
var next_log := 30.0
var last_dealt := 0.0
var last_kills := 0
var prof := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var prof_max := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var prof_n := 0

func setup(m) -> void:
	main = m

func mark(ev: String) -> void:
	last_event = ev
	last_event_ms = Time.get_ticks_msec()

func start() -> void:
	active = true
	time = 0.0
	loop = 1
	loop_time = 0.0
	boss_kills = 0
	kills = 0
	level = 1
	xp = 0
	xp_need = _need(1)
	xp_mult = 1.0
	passives = {}
	bonus_honey = 0
	shrine_dmg = 0.0
	shrine_cd = 1.0
	shrine_speed = 0.0
	shrine_area = 0.0
	queue.clear()
	evo_chests = 0
	last_magnet = 0.0
	stats = {"taken": 0.0, "dealt": 0.0, "by": {}, "chests": 0, "shrines": 0, "champs": 0, "bosses": 0}
	spawn_acc = 3.0
	hits = {}
	hinted = {}
	next_wave = 60.0
	next_elite = 110.0
	boss_spawned = false
	over = false
	victory = false
	end_t = 0.0
	next_log = 30.0
	champs_sent = 0
	cues.clear()
	slow_t = 0.0
	slow_k = 1.0
	last_dealt = 0.0
	last_kills = 0
	Engine.time_scale = main.debug_speed
	main.enemies.clear()
	main.weapons.reset()
	main.pickups.reset()
	main.world.reset()
	main.player.reset()
	main.fx.reset()
	main.audio.music("oyun1")
	ult = 0.0
	ult_bank = 0.0
	rerolls = 2 + main.meta_lv("zar")
	revives = main.meta_lv("nefes")
	main.player.max_hp = 100.0 + 8.0 * main.meta_lv("can")
	main.player.hp = main.player.max_hp
	_recalc()

func _need(l: int) -> int:
	return 4 + 5 * l + int(0.7 * l * l)

# Fixed, deterministic scaling: per-minute progression + cycle multiplier.
func hp_scale() -> float:
	var m := time / 60.0
	return (1.0 + m * 0.3 + m * m * 0.045) * pow(1.35, float(loop - 1))

func dmg_scale() -> float:
	var m := time / 60.0
	return (1.0 + 0.08 * m + 0.004 * m * m) * pow(1.30, float(loop - 1))

func atk_rate_scale() -> float:
	var m := time / 60.0
	return minf(1.8, 1.0 + 0.04 * m + 0.15 * float(loop - 1))

func speed_scale() -> float:
	return minf(1.45, 1.0 + 0.06 * float(loop - 1))

func boss_hp_for_loop() -> float:
	return 90000.0 * pow(2.3, float(loop - 1))

func champ_hp_for_loop(is_scorp: bool) -> float:
	if is_scorp:
		return 32500.0 * pow(2.2, float(loop - 1))
	return 9000.0 * pow(2.1, float(loop - 1))

func upg(id: String) -> Dictionary:
	for u in UPG:
		if u.id == id:
			return u
	return HEAL_CARD

func evo_ready(id: String) -> bool:
	var e: Array = EVO[id]
	return passives.get(e[0], 0) >= e[1]

func evo_partner(id: String) -> String:
	if EVO.has(id):
		return EVO[id][0]
	for w in EVO:
		if EVO[w][0] == id and main.weapons.levels[w] > 0:
			return w
	return ""

func level_of(id: String) -> int:
	if main.weapons.levels.has(id):
		return main.weapons.levels[id]
	return passives.get(id, 0)

func choices() -> Array:
	var pool: Array = []
	var weights: Array = []
	var evos: Array = []
	var owned := 0
	for wid in main.weapons.IDS:
		if main.weapons.levels[wid] > 0:
			owned += 1
	for u in UPG:
		var l := level_of(u.id)
		if u.kind == "w" and l == 0 and owned >= MAX_WEAPONS:
			continue
		if l >= u.max:
			if u.kind == "w" and l == u.max and evo_ready(u.id) and evos.size() < 2:
				var e: Array = EVO[u.id]
				evos.append({"id": u.id, "name": e[2], "icon": u.icon, "max": u.max + 1, "kind": "e", "desc": e[3]})
			continue
		pool.append(u)
		if u.kind == "w":
			weights.append((1.7 if l >= 3 else 1.5) if l > 0 else 1.3)
		else:
			var pw := evo_partner(u.id)
			var feeds: bool = pw != "" and main.weapons.levels[pw] > 0 and main.weapons.levels[pw] <= upg(pw).max and l < int(EVO[pw][1])
			weights.append(1.6 if feeds else 1.0)
	var out: Array = evos
	while out.size() < 3 and not pool.is_empty():
		var total := 0.0
		for w in weights:
			total += w
		var r := randf() * total
		var k := 0
		while k < pool.size() - 1 and r > weights[k]:
			r -= weights[k]
			k += 1
		out.append(pool[k])
		pool.remove_at(k)
		weights.remove_at(k)
	if level <= 2:
		var has_new := false
		for u in out:
			if u.kind == "w" and level_of(u.id) == 0:
				has_new = true
		if not has_new and out.size() == 3:
			var ws: Array = []
			for u in UPG:
				if u.kind == "w" and level_of(u.id) == 0:
					ws.append(u)
			if not ws.is_empty():
				out[0] = ws[randi() % ws.size()]
	while out.size() < 3:
		out.append(HEAL_CARD)
	return out

func apply(id: String) -> void:
	if id == "sifa":
		main.player.heal(40.0)
	elif main.weapons.levels.has(id):
		main.weapons.levels[id] += 1
		if main.weapons.levels[id] == upg(id).max + 1:
			_evo_moment(id)
	else:
		passives[id] = passives.get(id, 0) + 1
		if id == "kalp":
			main.player.max_hp += 20.0
			main.player.heal(20.0)
	_recalc()

func _recalc() -> void:
	var pl = main.player
	var w = main.weapons
	pl.move_speed = 8.2 * (1.0 + 0.08 * passives.get("cizme", 0) + shrine_speed) * (1.0 + 0.02 * main.meta_lv("hiz"))
	pl.pickup_r = 3.2 * (1.0 + 0.35 * passives.get("miknatis", 0)) * (1.0 + 0.08 * main.meta_lv("kepce"))
	pl.armor = 1.5 * passives.get("tulum", 0)
	pl.regen = 0.5 * passives.get("yaprak", 0)
	pl.stomp_lv = passives.get("inis", 0)
	pl.slide_lv = passives.get("kayis", 0)
	w.dmg_mult = (1.0 + 0.14 * passives.get("ofke", 0)) * (1.0 + 0.04 * main.meta_lv("guc"))
	w.shrine_mult = 1.0 + shrine_dmg
	w.cd_mult = pow(0.91, passives.get("saat", 0)) * shrine_cd
	w.area_mult = (1.0 + 0.12 * passives.get("menzil", 0)) * (1.0 + shrine_area)
	w.extra_proj = passives.get("cogalt", 0)
	w.crit = 0.05 + 0.08 * passives.get("nisan", 0)
	xp_mult = (1.0 + 0.12 * passives.get("kitap", 0)) * (1.0 + 0.04 * main.meta_lv("bilgi"))

func add_xp(v: int) -> void:
	xp += int(ceil(float(v) * xp_mult))
	while xp >= xp_need:
		xp -= xp_need
		level += 1
		xp_need = _need(level)
		queue.append("level")

func open_chest() -> void:
	stats.chests += 1
	if evo_chests > 0 and not _evo_ids().is_empty():
		evo_chests -= 1
		queue.append("evo")
	else:
		queue.append("chest")

func _evo_ids() -> Array:
	var ids: Array = []
	for wid in main.weapons.IDS:
		var l: int = main.weapons.levels[wid]
		if l > 0 and l <= upg(wid).max:
			ids.append(wid)
	ids.sort_custom(func(a, b): return main.weapons.levels[a] > main.weapons.levels[b])
	return ids

func cards_for(kind: String) -> Array:
	if kind != "evo":
		return choices()
	var out: Array = []
	for wid in _evo_ids():
		if out.size() < 3:
			var u: Dictionary = upg(wid)
			var e: Array = EVO[wid]
			out.append({"id": wid, "name": e[2], "icon": u.icon, "max": u.max + 1, "kind": "e", "desc": "%s evrilir\n%s" % [u.name, e[3]]})
	if out.is_empty():
		return choices()
	for u2 in choices():
		if out.size() < 3 and u2.kind != "e":
			out.append(u2)
	return out

func evolve(id: String) -> void:
	main.weapons.levels[id] = upg(id).max + 1
	_evo_moment(id)
	_recalc()

func _evo_moment(id: String) -> void:
	main.ui.banner("EVRİM", EVO[id][2])
	main.audio.play("shrine", 0.0, 1.2)
	main.fx.shake(0.6)
	main.weapons.explode(main.player.pos, 9.0, 60.0, id)
	stats.evos = stats.get("evos", 0) + 1
	if main.bot_mode:
		print("T EVO %s t=%d lv=%d" % [id, int(time), level])

# Shrines grant one of 4 random permanent blessings upon awakening.
func shrine_done(at: Vector3) -> void:
	stats.shrines += 1
	var roll := randi() % 4
	var msg := ""
	match roll:
		0:
			shrine_dmg += 0.15
			main.player.heal(25.0)
			msg = "Güç Sunağı uyandı: kalıcı +%15 hasar"
		1:
			shrine_cd *= 0.90
			main.player.heal(25.0)
			msg = "Hız Sunağı uyandı: kalıcı +%10 saldırı hızı"
		2:
			main.player.max_hp += 30.0
			main.player.heal(main.player.max_hp)
			msg = "Can Sunağı uyandı: +30 maks. can ve tam şifa"
		3:
			shrine_speed += 0.10
			shrine_area += 0.15
			main.player.heal(25.0)
			msg = "Rüzgar Sunağı uyandı: +%10 hız ve +%15 etki alanı"
	_recalc()
	mark("shrine")
	quiet_kills = true
	main.weapons.explode(at, 11.0, 70.0, "sunak")
	quiet_kills = false
	main.fx.shake(0.6)
	main.audio.play("shrine")
	main.ui.toast(msg)

func boss_rage(at: Vector3) -> void:
	main.ui.banner("KRALİÇE ÖFKELENDİ", "Zırhı sertleşti, zehir yağdırıyor")
	main.audio.play("boss_roar", 0.0, 0.8)
	main.fx.shake(0.9)
	main.fx.explosion(at, 12.0, Color(1.0, 0.3, 0.2))
	main.player.focus_on(at, 1.3)
	slow(0.9, 0.35)
	if main.bot_mode:
		print("T BOSS rage loop=%d t=%d" % [loop, int(time)])

func hint(key: String, text: String) -> void:
	if not hinted.has(key):
		hinted[key] = true
		main.ui.toast(text)

func note_hit(k: String) -> void:
	hits[k] = hits.get(k, 0) + 1

func on_damage_dealt(a: float, src: String) -> void:
	stats.dealt += a
	stats.by[src] = stats.by.get(src, 0.0) + a

func honey_for_run(_won := false) -> int:
	return int(kills / 30.0 + time / 60.0 * 4.0) + 15 * int(stats.get("champs", 0)) + bonus_honey

func _by_str() -> String:
	var by: Dictionary = stats.by
	var keys: Array = by.keys()
	keys.sort_custom(func(a, b): return by[a] > by[b])
	var s := ""
	for k in keys:
		s += "%s=%d%% " % [k, int(100.0 * by[k] / maxf(1.0, stats.dealt))]
	return s

func try_ult() -> bool:
	if ult < 1.0 or over or not main.player.alive:
		return false
	ult = 0.0
	stats.ults = stats.get("ults", 0) + 1
	main.weapons.call_hive()
	return true

func on_enemy_killed(t: int, at: Vector3, elite: bool, s: float) -> void:
	kills += 1
	if ult < 1.0:
		ult_bank = minf(0.5, ult_bank + (1.0 + 0.08 * main.meta_lv("boru")) / (50.0 * (1.0 + time / 45.0)))
	main.audio.play("kill", 0.0, randf_range(0.85, 1.2))
	main.fx.burst(at + Vector3(0, 0.4, 0), KILL_COL[t], 8 + int(s * 3.0), 5.0 + s)
	if t == main.enemies.T_BOSS:
		main.stop_for(0.22, true)
		_on_boss_defeated(at)
		return
	if t >= main.enemies.T_STAG:
		main.stop_for(0.16, true)
		main.fx.shake(0.8)
		main.fx.explosion(at, 8.0, KILL_COL[t])
		main.audio.play("boss_slam", 0.0, 0.8)
		main.pickups.drop_item("chest", at)
		for k in 10:
			var ga := TAU * k / 10.0
			main.pickups.drop_gem(at + Vector3(cos(ga) * 2.2, 0, sin(ga) * 2.2), 6)
		main.player.heal(20.0)
		var prize := not _evo_ids().is_empty()
		if prize:
			evo_chests += 1
		main.ui.banner(CHAMP_NAMES[t - main.enemies.T_STAG] + " DEVRİLDİ", "Sandığı bir silahını evriltir" if prize else "Sandığını al")
		stats.champs = stats.get("champs", 0) + 1
		return
	var v: int = main.enemies.TYPES[t].xp
	if elite:
		main.pickups.drop_gem(at, 25)
		main.pickups.drop_item("chest", at)
		main.fx.shake(0.5)
		main.fx.explosion(at, 4.0, KILL_COL[t])
		if not quiet_kills:
			main.stop_for(0.09, true)
	else:
		if t == main.enemies.T_BRUTE:
			main.fx.shake(0.36)
			if not quiet_kills:
				main.stop_for(0.045)
		else:
			main.fx.shake(0.2)
		main.pickups.drop_gem(at, v)
		var roll := randf()
		if roll < 0.004:
			if time - last_magnet > 100.0 and main.pickups.count_of("magnet") < 1:
				last_magnet = time
				main.pickups.drop_item("magnet", at)
		elif roll < (0.16 if t == main.enemies.T_BRUTE else 0.013) and main.pickups.count_of("heal") < 4:
			main.pickups.drop_item("heal", at)

func on_player_dead() -> void:
	if over:
		return
	if revives > 0:
		revives -= 1
		var pl = main.player
		pl.alive = true
		pl.hp = pl.max_hp * 0.5
		pl.inv_t = 2.5
		main.weapons.explode(pl.pos, 10.0, 60.0 * hp_scale(), "nefes")
		main.weapons.push_back(pl.pos, 12.0, 22.0, false)
		main.ui.banner("İKİNCİ NEFES", "Kovan seni geri çağırdı")
		main.audio.play("shrine", 0.0, 0.9)
		slow(0.6, 0.3)
		return
	if main.bot_mode:
		print("T DEAD loop=%d t=%d lv=%d kills=%d alive=%d edge=%d hits=%s w=%s p=%s" % [loop, int(time), level, kills, main.enemies.count, int(main.world.ARENA_R - Vector2(main.player.pos.x, main.player.pos.z).length()), str(hits), str(main.weapons.levels.values()), str(passives)])
		print("T BY %s" % _by_str())
	over = true
	victory = false
	end_t = 2.1
	Engine.time_scale = 0.35
	main.audio.play("defeat")

func _on_boss_defeated(at: Vector3) -> void:
	if over:
		return
	boss_kills += 1
	stats.bosses = boss_kills
	var reward := 60 * loop
	bonus_honey += reward
	if main.bot_mode:
		print("T LOOP_CLEAR loop=%d t=%d lv=%d kills=%d hp=%d" % [loop, int(time), level, kills, int(main.player.hp)])
	main.fx.shake(1.0)
	main.fx.explosion(at, 12.0, Color(1.0, 0.8, 0.2))
	main.audio.play("victory")
	main.player.focus_on(at, 2.0)
	slow(1.4, 0.35)
	for k in 4:
		var oa := randf() * TAU
		cues.append({"t": 0.25 + 0.25 * k, "kind": "boom", "pos": at + Vector3(cos(oa) * 2.5, 0, sin(oa) * 2.5), "size": 5.0 + k})
	cues.append({"t": 1.35, "kind": "final", "pos": at, "size": 16.0})
	var en = main.enemies
	en.rings.clear()
	en.pops.clear()
	en.lobs.clear()
	main.fx.warns.clear()
	en.bcount = 0
	for i in en.count:
		if en.dead[i] == 0:
			en.dead[i] = 1
			en.dead_any = true
			main.pickups.drop_gem(Vector3(en.px[i], 0, en.pz[i]), 2)
	main.pickups.pull_all()
	main.pickups.drop_item("chest", at)
	if not _evo_ids().is_empty():
		evo_chests += 1
	main.player.heal(main.player.max_hp * 0.5)
	main.player.inv_t = maxf(main.player.inv_t, 2.0)
	loop += 1
	loop_time = 0.0
	boss_spawned = false
	champs_sent = 0
	next_wave = time + 60.0
	next_elite = time + 90.0
	main.world.next_cycle()
	main.audio.music("oyun1")
	main.ui.banner("DÖNGÜ %d" % loop, "Kraliçe devrildi (+%d bal) · Sürü güçlendi" % reward)

func slow(secs: float, k: float) -> void:
	if slow_t > secs:
		return
	slow_t = secs
	slow_k = k

func pop_choice() -> void:
	var kind: String = queue.pop_front()
	if kind == "evo" and _evo_ids().is_empty():
		kind = "chest"
	main.ui.show_choice(kind, cards_for(kind))

func _run_cues(real: float) -> void:
	if slow_t > 0.0:
		slow_t -= real
		if not over:
			Engine.time_scale = main.debug_speed * (slow_k if slow_t > 0.0 else 1.0)
	if cues.is_empty():
		return
	var keep: Array[Dictionary] = []
	for c in cues:
		c.t -= real
		if c.t > 0.0:
			keep.append(c)
			continue
		var at: Vector3 = c.pos
		var size: float = c.size
		match c.kind:
			"boom":
				main.fx.explosion(at, size, Color(1.0, 0.5, 0.25))
				main.fx.shake(0.45)
				main.audio.play("explosion", -3.0, randf_range(0.8, 1.1))
			"rise":
				main.fx.explosion(at, size, Color(1.0, 0.3, 0.25))
				main.fx.burst(at + Vector3(0, 1.0, 0), Color(0.45, 0.3, 0.15), 40, 14.0)
				main.weapons.push_back(at, size, 20.0, false)
				main.fx.shake(1.0)
				main.audio.play("boss_slam", 0.0, 0.8)
			"final":
				main.fx.explosion(at, size, Color(1.0, 0.85, 0.3))
				main.fx.burst(at + Vector3(0, 2.0, 0), Color(1.0, 0.8, 0.2), 48, 16.0)
				main.fx.shake(1.0)
				main.audio.play("explosion", 0.0, 0.6)
				for k in 24:
					var ga := randf() * TAU
					var gr := randf_range(1.0, 7.0)
					main.pickups.drop_gem(at + Vector3(cos(ga) * gr, 0, sin(ga) * gr), 3)
				main.pickups.pull_all()
	cues = keep

func update(dt: float) -> void:
	if not active:
		return
	_run_cues(dt / maxf(0.05, Engine.time_scale))
	if over:
		end_t -= dt / maxf(0.05, Engine.time_scale)
		if end_t <= 0.0:
			active = false
			Engine.time_scale = 1.0
			main.finish_run(false)
			return
	else:
		time += dt
		if not boss_spawned:
			loop_time = minf(CYCLE_TIME, loop_time + dt)
	if main.bot_mode:
		var order := [main.player, main.enemies, main.weapons, main.pickups, main.world, main.fx]
		for k in order.size():
			var t0 := Time.get_ticks_usec()
			order[k].update(dt)
			var us := float(Time.get_ticks_usec() - t0)
			prof[k] += us
			prof_max[k] = maxf(prof_max[k], us)
		prof_n += 1
	else:
		main.player.update(dt)
		main.enemies.update(dt)
		main.weapons.update(dt)
		main.pickups.update(dt)
		main.world.update(dt)
		main.fx.update(dt)
	if main.bot_mode and time >= next_log:
		print("T loop=%d t=%d lv=%d kills=%d (+%d) alive=%d hp=%d/%d dps=%d taken=%d fps=%d w=%s" % [loop, int(time), level, kills, kills - last_kills, main.enemies.count, int(main.player.hp), int(main.player.max_hp), int((stats.dealt - last_dealt) / 30.0), int(stats.taken), int(Engine.get_frames_per_second()), str(main.weapons.levels.values())])
		next_log = (floor(time / 30.0) + 1.0) * 30.0
		if prof_n > 0:
			var line := "T ms avg/max"
			var names := ["player", "enemies", "weapons", "pickups", "world", "fx"]
			for k in names.size():
				line += " %s=%.2f/%.1f" % [names[k], prof[k] / prof_n / 1000.0, prof_max[k] / 1000.0]
			print(line)
			prof = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
			prof_max = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
			prof_n = 0
		last_dealt = stats.dealt
		last_kills = kills
	if not over:
		if ult < 1.0 and ult_bank > 0.0:
			var pay := minf(ult_bank, dt / 55.0)
			ult_bank -= pay
			ult = minf(1.0, ult + pay)
			if ult >= 1.0:
				main.audio.play("levelup", -6.0, 1.5)
				main.ui.ult_ready()
		_spawn(dt)
		if loop_time >= 220.0 and not boss_spawned and main.audio.current == "oyun1":
			main.audio.music("oyun2")
		elif loop_time >= 430.0 and not boss_spawned and main.audio.current == "oyun2":
			main.audio.music("gece")
		if not queue.is_empty() and not main.ui.choosing:
			pop_choice()
		var pp: Vector3 = main.player.pos
		if time > 60.0 and Vector2(pp.x, pp.z).length() > main.world.ARENA_R - 9.0:
			hint("duvar", "Arena kenarındasın, sürü seni duvara sıkıştırır: ortaya dön")

func _ring_pos(dmin: float, dmax: float) -> Vector2:
	var p: Vector3 = main.player.pos
	var lim: float = main.world.ARENA_R - 2.0
	var best := Vector2(p.x, p.z)
	for attempt in 8:
		var a := randf() * TAU
		var d := randf_range(dmin, dmax)
		best = Vector2(p.x + cos(a) * d, p.z + sin(a) * d)
		if best.length() < lim:
			return best
	return best.normalized() * lim

func _pick_type() -> int:
	var en = main.enemies
	var r := randf()
	if time > 300.0 and r < minf(0.085, (time - 300.0) / 4000.0 + 0.03):
		return en.T_SPIT
	r = randf()
	if time > 250.0 and r < minf(0.09, (time - 250.0) / 3500.0 + 0.03):
		return en.T_HOP
	r = randf()
	if time > 130.0 and r < minf(0.065, (time - 130.0) / 5000.0 + 0.025):
		return en.T_BOOM
	r = randf()
	if time > 170.0 and r < minf(0.14, (time - 170.0) / 2500.0 + 0.04):
		return en.T_BRUTE
	r = randf()
	if time > 70.0 and r < minf(0.34, (time - 70.0) / 500.0 + 0.1):
		return en.T_WASP
	return en.T_BEETLE

func _spawn(dt: float) -> void:
	var en = main.enemies
	var boss_alive: bool = en.boss_uid >= 0
	var target := int(clampf(24.0 + time * 0.33 + float(loop - 1) * 28.0, 24.0, 300.0))
	if boss_alive:
		target = mini(140, 90 + (loop - 1) * 15)
	var faucet := 1.7 + minf(time, 300.0) * 0.04 + maxf(0.0, time - 300.0) * 0.03 + float(loop - 1) * 1.2
	var rate := clampf(float(target - en.count) / 3.0, faucet * 0.5, faucet * 1.45)
	spawn_acc += dt * rate
	var hard_cap := mini(en.MAXN - 20, int(target * 1.35))
	var n := 0
	while spawn_acc >= 1.0 and en.count < hard_cap and n < 12:
		spawn_acc -= 1.0
		n += 1
		var p := _ring_pos(17.0, 27.0)
		var st := _pick_type()
		en.spawn(st, p.x, p.y, false, hp_scale())
		if st == en.T_SPIT:
			hint("spit", "Tüküren geldi, tükürüğün üstünden zıpla")
		elif st == en.T_BOOM:
			hint("patlak", "Patlak böcek sürüyü de yakar, uzaktan vur")
	if en.count >= hard_cap:
		spawn_acc = minf(spawn_acc, 1.0)
	var pl: Vector3 = main.player.pos
	for k in 16:
		if en.count == 0:
			break
		recycle_i = (recycle_i + 1) % en.count
		var i := recycle_i
		if en.dead[i] == 0 and en.typ[i] != en.T_BOSS and en.typ[i] < en.T_STAG and en.elite[i] == 0 and en.st[i] == 0:
			var dx: float = en.px[i] - pl.x
			var dz: float = en.pz[i] - pl.z
			if dx * dx + dz * dz > 38.0 * 38.0:
				var p2 := _ring_pos(18.0, 26.0)
				en.px[i] = p2.x
				en.pz[i] = p2.y
				en.born[i] = 0.5
	if time >= next_wave and not boss_spawned:
		next_wave += maxf(35.0, 60.0 - float(loop - 1) * 4.0)
		var wt: int = en.T_WASP if (time > 200.0 and int(time / 60.0) % 2 == 0) else en.T_BEETLE
		var cnt := mini(50, 14 + int(time / 18.0))
		if wt == en.T_WASP:
			cnt = mini(36, 8 + int(time / 30.0))
		var a0 := randf() * TAU
		for k in cnt:
			var a := a0 + TAU * k / cnt
			var q := Vector2(pl.x + cos(a) * 21.0, pl.z + sin(a) * 21.0)
			if q.length() > main.world.ARENA_R - 2.0:
				q = q.normalized() * (main.world.ARENA_R - 2.0)
			en.spawn(wt, q.x, q.y, false, hp_scale())
		main.ui.toast("Sürü geliyor!")
		main.audio.play("horn")
	if time >= next_elite and not boss_spawned:
		next_elite += maxf(55.0, 95.0 - float(loop - 1) * 7.0)
		var p3 := _ring_pos(22.0, 26.0)
		var et: int = en.T_BRUTE if time > 240.0 else en.T_BEETLE
		en.spawn(et, p3.x, p3.y, true, hp_scale() * (2.0 if et == en.T_BEETLE else 1.0))
		main.ui.toast("Elit geldi, sandığı onda")
		main.audio.play("horn", 0.0, 0.8)
	if champs_sent < CHAMP_TIMES.size() and loop_time >= CHAMP_TIMES[champs_sent] and not boss_spawned:
		var ct: int = en.T_STAG + champs_sent
		champs_sent += 1
		var cp := _ring_pos(24.0, 27.0)
		var chp := champ_hp_for_loop(ct == en.T_SCORP)
		if main.bot_mode:
			print("T CHAMP %s loop=%d hp=%d" % [CHAMP_NAMES[ct - en.T_STAG], loop, int(chp)])
		en.spawn(ct, cp.x, cp.y, false, chp / float(en.TYPES[ct].hp))
		main.fx.splat(cp.x, cp.y, 5.0, Color(0.22, 0.15, 0.08, 0.8), 3.0)
		main.ui.banner(CHAMP_NAMES[ct - en.T_STAG], "Sürünün koçbaşı" if ct == en.T_STAG else "Zehirli kuyruk")
		main.audio.play("boss_roar", 0.0, 1.2)
		main.fx.shake(0.5)
	if loop_time >= CYCLE_TIME and not boss_spawned:
		boss_spawned = true
		var p4 := _ring_pos(16.0, 19.0)
		var boss_hp := boss_hp_for_loop()
		if main.bot_mode:
			print("T BOSS loop=%d hp=%d" % [loop, int(boss_hp)])
		var qi: int = en.spawn(en.T_BOSS, p4.x, p4.y, false, boss_hp / float(en.TYPES[en.T_BOSS].hp))
		if qi >= 0:
			en.born[qi] = 1.0
		var qp := Vector3(p4.x, 0, p4.y)
		main.ui.banner("KRALİÇE · DÖNGÜ %d" % loop, "Sürünün anası uyandı")
		main.audio.play("boss_roar")
		main.audio.music("boss")
		main.fx.shake(0.7)
		main.fx.splat(p4.x, p4.y, 9.0, Color(0.2, 0.13, 0.07, 0.85), 8.0)
		main.player.focus_on(qp, 2.8)
		slow(2.0, 0.3)
		cues.append({"t": 0.5, "kind": "boom", "pos": qp, "size": 6.0})
		cues.append({"t": 1.05, "kind": "boom", "pos": qp, "size": 9.0})
		cues.append({"t": 1.65, "kind": "rise", "pos": qp, "size": 13.0})
