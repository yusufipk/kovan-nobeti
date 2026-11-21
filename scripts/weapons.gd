extends Node3D
# Auto-firing weapons. The player never aims; everything targets by itself.

const PMAX := 200
const IDS := ["ari", "tutsu", "bomba", "igne", "kivilcim", "kule", "iz"]
const SWARM_N := 190

var main
var levels := {}
var timers := {}
var dmg_mult := 1.0
var cd_mult := 1.0
var area_mult := 1.0
var extra_proj := 0
var crit := 0.05
var shrine_mult := 1.0

# bees (homing projectiles)
var qx := PackedFloat32Array()
var qz := PackedFloat32Array()
var qy := PackedFloat32Array()
var qvx := PackedFloat32Array()
var qvz := PackedFloat32Array()
var qlife := PackedFloat32Array()
var qdmg := PackedFloat32Array()
var qtu := PackedInt32Array()
var qhint := PackedInt32Array()
var qpierce := PackedInt32Array()
var qlast := PackedInt32Array()
var qn := 0
var bee_mm: MultiMesh

var aura: MeshInstance3D
var aura_mat: ShaderMaterial
var aura_pulse := 0.0
var orbit_nodes: Array[MeshInstance3D] = []
var orbit_angle := 0.0
var bombs: Array[Dictionary] = []
var bomb_nodes: Array[MeshInstance3D] = []
var bolt_nodes: Array[MeshInstance3D] = []
var bolt_t: Array[float] = []
var bolt_i := 0
# sentry hives: {"x", "z", "life", "cd"}
var turrets: Array[Dictionary] = []
var turret_nodes: Array[MeshInstance3D] = []
# honey trail: {"x", "z", "life"}
var trail: Array[Dictionary] = []
var trail_last := Vector3(1e6, 0, 1e6)
# the hive call: seconds of swarm left, its damage tick and the bees circling the keeper
var ult_t := 0.0
var ult_tick := 0.0
var swarm_mm: MultiMesh
var swarm: MultiMeshInstance3D
var swarm_seed := PackedFloat32Array()
var wtime := 0.0

func setup(m) -> void:
	main = m
	for arr in [qx, qz, qy, qvx, qvz, qlife, qdmg]:
		arr.resize(PMAX)
	for arr in [qtu, qhint, qpierce, qlast]:
		arr.resize(PMAX)
	bee_mm = MultiMesh.new()
	bee_mm.transform_format = MultiMesh.TRANSFORM_3D
	bee_mm.mesh = main.assets.bee_mesh()
	bee_mm.instance_count = PMAX
	bee_mm.visible_instance_count = 0
	var bi := MultiMeshInstance3D.new()
	bi.multimesh = bee_mm
	bi.custom_aabb = AABB(Vector3(-200, -5, -200), Vector3(400, 40, 400))
	bi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bi)
	aura = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	q.orientation = PlaneMesh.FACE_Y
	aura.mesh = q
	aura_mat = ShaderMaterial.new()
	aura_mat.shader = main.assets.aura_shader()
	aura.material_override = aura_mat
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.visible = false
	add_child(aura)
	for k in 12:
		var n := MeshInstance3D.new()
		n.mesh = main.assets.stinger_mesh()
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.visible = false
		add_child(n)
		orbit_nodes.append(n)
	for k in 6:
		var n2 := MeshInstance3D.new()
		n2.mesh = main.assets.prop_mesh("kavanoz")
		n2.material_override = main.assets.prop_material("kavanoz")
		n2.visible = false
		add_child(n2)
		bomb_nodes.append(n2)
	for k in 40:
		var n3 := MeshInstance3D.new()
		n3.mesh = main.assets.bolt_mesh()
		n3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n3.visible = false
		add_child(n3)
		bolt_nodes.append(n3)
		bolt_t.append(0.0)
	var tmat: StandardMaterial3D = main.assets.prop_material("kovan")
	tmat.emission_enabled = true
	tmat.emission = Color(1.0, 0.75, 0.2)
	tmat.emission_energy_multiplier = 0.45
	for k in 4:
		var n4 := MeshInstance3D.new()
		n4.mesh = main.assets.prop_mesh("kovan")
		n4.material_override = tmat
		n4.visible = false
		add_child(n4)
		turret_nodes.append(n4)
	swarm_mm = MultiMesh.new()
	swarm_mm.transform_format = MultiMesh.TRANSFORM_3D
	swarm_mm.mesh = main.assets.bee_mesh()
	swarm_mm.instance_count = SWARM_N
	swarm_seed.resize(SWARM_N)
	for k in SWARM_N:
		swarm_seed[k] = randf()
	swarm = MultiMeshInstance3D.new()
	swarm.multimesh = swarm_mm
	swarm.custom_aabb = AABB(Vector3(-200, -5, -200), Vector3(400, 40, 400))
	swarm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	swarm.visible = false
	add_child(swarm)

func reset() -> void:
	levels = {"ari": 1, "tutsu": 0, "bomba": 0, "igne": 0, "kivilcim": 0, "kule": 0, "iz": 0}
	timers = {"ari": 0.5, "tutsu": 0.0, "bomba": 1.0, "kivilcim": 1.0, "kule": 0.5, "iz": 0.0}
	turrets.clear()
	trail.clear()
	trail_last = Vector3(1e6, 0, 1e6)
	ult_t = 0.0
	swarm.visible = false
	for n in turret_nodes:
		n.visible = false
	dmg_mult = 1.0
	cd_mult = 1.0
	area_mult = 1.0
	extra_proj = 0
	crit = 0.05
	shrine_mult = 1.0
	qn = 0
	bombs.clear()
	for n in orbit_nodes:
		n.visible = false
	for n in bomb_nodes:
		n.visible = false
	for n in bolt_nodes:
		n.visible = false
	aura.visible = false
	bee_mm.visible_instance_count = 0

func b(v: bool) -> int:
	return 1 if v else 0

func deal(i: int, base: float, kx: float, kz: float, src: String) -> bool:
	var c := randf() < crit
	var a := base * dmg_mult * shrine_mult * randf_range(0.9, 1.1)
	if c:
		a *= 2.0
	return main.enemies.hurt(i, a, kx, kz, src, c)

func update(dt: float) -> void:
	var pl = main.player
	var en = main.enemies
	var p: Vector3 = pl.pos
	var boss: int = en.boss_index()
	if boss >= 0 and Vector2(en.px[boss] - p.x, en.pz[boss] - p.z).length() > 20.0:
		boss = -1
	# --- bees
	var l: int = levels.ari
	if l > 0:
		timers.ari -= dt
		if timers.ari <= 0.0:
			var n := 1 + b(l >= 2) + b(l >= 4) + 2 * b(l >= 6) + 2 * b(l >= 7) + extra_proj
			var skip := {}
			var fired := false
			for k in n:
				var t: int = boss if (boss >= 0 and k % 2 == 0) else en.nearest(p.x, p.z, 12.5, skip)
				if t < 0 and k > 0:
					t = en.nearest(p.x, p.z, 12.5)
				if t < 0:
					t = boss
				if t < 0:
					break
				skip[en.uid[t]] = true
				_fire_bee(p, t, 10.0 + 5.0 * b(l >= 3) + 7.0 * b(l >= 6) + 10.0 * b(l >= 7), b(l >= 4) + b(l >= 6) + b(l >= 7), k, n)
				fired = true
			if fired:
				main.audio.play("shoot", -6.0, randf_range(0.9, 1.2))
				timers.ari = 0.62 * (0.72 if l >= 5 else 1.0) * cd_mult
			else:
				timers.ari = 0.15
	_update_bees(dt)
	# --- smoke aura
	l = levels.tutsu
	if l > 0:
		var r := 3.1 * (1.0 + 0.22 * b(l >= 2) + 0.25 * b(l >= 5) + 0.45 * b(l >= 7)) * area_mult
		aura.visible = true
		aura.position = Vector3(p.x, 0.12, p.z)
		aura.scale = Vector3(r, 1, r)
		aura_pulse = maxf(0.0, aura_pulse - dt * 3.0)
		aura_mat.set_shader_parameter("pulse", aura_pulse)
		timers.tutsu -= dt
		if timers.tutsu <= 0.0:
			timers.tutsu = (0.45 if l < 6 else 0.33) * maxf(0.5, cd_mult)
			aura_pulse = 1.0
			var d := 4.0 + 3.0 * b(l >= 3) + 6.0 * b(l >= 6) + 10.0 * b(l >= 7)
			for i in en.query(p.x, p.z, r):
				if p.y < 2.5 or en.height_of(i) > 0.5:
					deal(i, d, 0.0, 0.0, "tutsu")
					if l >= 4:
						en.slow(i, 0.7)
	# --- honey bombs
	l = levels.bomba
	if l > 0:
		timers.bomba -= dt
		if timers.bomba <= 0.0:
			var nb := 1 + b(l >= 3) + b(l >= 6) + 2 * b(l >= 7) + extra_proj
			var any := false
			for k in nb:
				var t2: int = boss if (boss >= 0 and k == 0) else en.random_near(p.x, p.z, 12.5)
				if t2 < 0:
					break
				any = true
				bombs.append({
					"from": p + Vector3(0, 1.4, 0),
					"to": Vector3(en.px[t2], 0, en.pz[t2]),
					"t": -0.08 * k,
					"dmg": 28.0 + 12.0 * b(l >= 2) + 22.0 * b(l >= 6) + 30.0 * b(l >= 7),
					"r": 3.3 * (1.3 if l >= 4 else 1.0) * (1.25 if l >= 7 else 1.0) * area_mult,
				})
			timers.bomba = (3.2 * (0.75 if l >= 5 else 1.0) * cd_mult) if any else 0.3
	_update_bombs(dt)
	# --- orbiting stingers
	l = levels.igne
	var n_orb := 0
	if l > 0:
		n_orb = mini(orbit_nodes.size(), 2 + b(l >= 2) + b(l >= 4) + 2 * b(l >= 6) + 4 * b(l >= 7) + extra_proj)
		var orr := 2.7 * (1.25 if l >= 5 else 1.0) * (0.6 + 0.4 * area_mult)
		orbit_angle += dt * (3.4 if l < 4 else (4.4 if l < 7 else 5.6))
		var od := 8.0 + 5.0 * b(l >= 3) + 9.0 * b(l >= 6) + 14.0 * b(l >= 7)
		for k in n_orb:
			var a := orbit_angle + TAU * k / n_orb
			var ox := p.x + cos(a) * orr
			var oz := p.z + sin(a) * orr
			var node := orbit_nodes[k]
			node.visible = true
			node.position = Vector3(ox, p.y + 0.9, oz)
			node.rotation = Vector3(PI * 0.5, -a, 0)
			for i in en.query(ox, oz, 0.75):
				if en.orb_cd[i] <= 0.0:
					en.orb_cd[i] = 0.4
					deal(i, od, cos(a) * 5.0, sin(a) * 5.0, "igne")
	for k in range(n_orb, orbit_nodes.size()):
		orbit_nodes[k].visible = false
	# --- chain spark
	l = levels.kivilcim
	if l > 0:
		timers.kivilcim -= dt
		if timers.kivilcim <= 0.0:
			var strikes := 1 + b(l >= 6)
			var hit_any := false
			for s in strikes:
				if _chain(p, 16.0 + 8.0 * b(l >= 3) + 14.0 * b(l >= 6) + 20.0 * b(l >= 7), 3 + 2 * b(l >= 2) + 3 * b(l >= 5) + 6 * b(l >= 7) + extra_proj, boss if s == 0 else -1):
					hit_any = true
			if hit_any:
				main.audio.play("zap", -4.0, randf_range(0.9, 1.15))
				timers.kivilcim = 2.2 * (0.8 if l >= 4 else 1.0) * (0.6 if l >= 7 else 1.0) * cd_mult
			else:
				timers.kivilcim = 0.2
	_update_turrets(dt, p)
	_update_trail(dt, p)
	_update_swarm(dt, p)
	for k in bolt_nodes.size():
		if bolt_t[k] > 0.0:
			bolt_t[k] -= dt
			if bolt_t[k] <= 0.0:
				bolt_nodes[k].visible = false

func _update_turrets(dt: float, p: Vector3) -> void:
	var en = main.enemies
	var l: int = levels.kule
	if l > 0:
		var most := mini(turret_nodes.size(), 1 + b(l >= 3) + b(l >= 6) + b(l >= 7))
		var life := 11.0
		timers.kule -= dt
		if timers.kule <= 0.0 and main.player.on_ground:
			timers.kule = life / most * maxf(0.6, cd_mult)
			if turrets.size() >= most:
				_turret_gone(turrets.pop_front())
			turrets.append({"x": p.x, "z": p.z, "life": life, "cd": 0.3})
			main.fx.burst(Vector3(p.x, 0.6, p.z), Color(1.0, 0.8, 0.3), 10, 4.0)
			main.audio.play("land", -4.0, 1.4)
	var range_m := 10.0 * (1.3 if l >= 5 else 1.0)
	var d := 9.0 + 5.0 * b(l >= 2) + 6.0 * b(l >= 5) + 8.0 * b(l >= 6) + 12.0 * b(l >= 7)
	var gap := 0.55 * (0.7 if l >= 4 else 1.0) * maxf(0.5, cd_mult)
	var keep: Array[Dictionary] = []
	for t in turrets:
		t.life -= dt
		if t.life <= 0.0:
			_turret_gone(t)
			continue
		keep.append(t)
		t.cd -= dt
		if t.cd <= 0.0:
			var e: int = en.nearest(t.x, t.z, range_m)
			if e >= 0:
				t.cd = gap
				var from := Vector3(t.x, 1.7, t.z)
				var to := Vector3(en.px[e], en.height_of(e) + 0.5, en.pz[e])
				_tracer(from, to)
				var dir := (to - from).normalized()
				deal(e, d, dir.x * 3.0, dir.z * 3.0, "kule")
				main.audio.play("shoot", -10.0, randf_range(1.4, 1.7))
			else:
				t.cd = 0.15
	turrets = keep
	for k in turret_nodes.size():
		var node := turret_nodes[k]
		node.visible = k < turrets.size()
		if node.visible:
			var tt: Dictionary = turrets[k]
			var grow := clampf((11.0 - float(tt.life)) * 5.0, 0.0, 1.0) * clampf(float(tt.life) * 2.0, 0.3, 1.0)
			node.position = Vector3(tt.x, 0.0, tt.z)
			node.scale = Vector3.ONE * 1.7 * grow * (1.0 + 0.06 * maxf(0.0, 0.12 - float(tt.cd)) / 0.12)

func _turret_gone(t: Dictionary) -> void:
	var at := Vector3(t.x, 0.3, t.z)
	if levels.kule >= 7:
		explode(at, 4.6 * area_mult, 55.0, "kule")
	else:
		main.fx.burst(at, Color(1.0, 0.8, 0.3), 12, 5.0)

func _tracer(a: Vector3, c: Vector3) -> void:
	var n := bolt_nodes[bolt_i]
	bolt_t[bolt_i] = 0.07
	bolt_i = (bolt_i + 1) % bolt_nodes.size()
	var dist := a.distance_to(c)
	if dist < 0.05:
		return
	n.visible = true
	var up := Vector3.UP if absf((c - a).normalized().y) < 0.95 else Vector3.RIGHT
	n.look_at_from_position((a + c) * 0.5, c, up)
	n.scale = Vector3(1, 1, dist)

func _update_trail(dt: float, p: Vector3) -> void:
	var en = main.enemies
	var l: int = levels.iz
	if l > 0:
		var r := 1.25 * (1.3 if l >= 4 else 1.0) * (0.7 + 0.3 * area_mult)
		var life := 3.0 + 1.5 * b(l >= 3) + 1.5 * b(l >= 6)
		if Vector2(p.x - trail_last.x, p.z - trail_last.z).length() > r * 0.9 and p.y < 0.6:
			trail_last = p
			trail.append({"x": p.x, "z": p.z, "life": life})
			var col := Color(1.0, 0.42, 0.08, 0.8) if l >= 7 else Color(1.0, 0.72, 0.12, 0.75)
			main.fx.splat(p.x, p.z, r * 1.1, col, life)
		timers.iz -= dt
		if timers.iz <= 0.0:
			timers.iz = 0.4
			var d := 5.0 + 2.0 * b(l >= 2) + 3.0 * b(l >= 5) + 4.0 * b(l >= 6) + 8.0 * b(l >= 7)
			var seen := {}
			var bursts := 0
			for t in trail:
				for i in en.query(t.x, t.z, r):
					var u: int = en.uid[i]
					if seen.has(u) or en.height_of(i) > 0.5:
						continue
					seen[u] = true
					en.slow(i, 0.6)
					var ex: float = en.px[i]
					var ez: float = en.pz[i]
					if deal(i, d, 0.0, 0.0, "iz") and l >= 7 and bursts < 3:
						bursts += 1
						explode(Vector3(ex, 0.3, ez), 2.6 * area_mult, 26.0, "iz")
	if trail.is_empty():
		return
	var keep: Array[Dictionary] = []
	for t in trail:
		t.life -= dt
		if t.life > 0.0:
			keep.append(t)
	trail = keep

func call_hive() -> void:
	var pl = main.player
	var en = main.enemies
	var p: Vector3 = pl.pos
	ult_t = 4.0
	ult_tick = 0.2
	var hs: float = main.game.hp_scale()
	for i in en.query(p.x, p.z, 13.0):
		var dx: float = en.px[i] - p.x
		var dz: float = en.pz[i] - p.z
		var dl := sqrt(dx * dx + dz * dz) + 0.01
		var big: bool = en.typ[i] == en.T_BOSS or en.typ[i] >= en.T_STAG
		en.hurt(i, en.maxhp[i] * 0.02 if big else 20.0 * hs, dx / dl * 20.0, dz / dl * 20.0, "cagri")
	main.fx.explosion(p, 13.0, Color(1.0, 0.8, 0.2))
	main.fx.explosion(p, 7.0, Color(1.0, 0.95, 0.6))
	main.fx.shake(0.9)
	main.audio.play("horn", 0.0, 1.25)
	main.audio.play("shrine", -2.0, 1.4)
	pl.inv_t = maxf(pl.inv_t, 0.8)
	main.game.slow(0.4, 0.3)
	main.game.mark("ult")

func _update_swarm(dt: float, p: Vector3) -> void:
	wtime += dt
	if ult_t <= 0.0:
		swarm.visible = false
		return
	var en = main.enemies
	ult_t -= dt
	ult_tick -= dt
	if ult_tick <= 0.0:
		ult_tick = 0.2
		var hs: float = main.game.hp_scale()
		var near: PackedInt32Array = en.query(p.x, p.z, 11.0)
		for k in mini(near.size(), 8):
			var i: int = near[randi() % near.size()]
			if en.dead[i] == 0:
				var big: bool = en.typ[i] == en.T_BOSS or en.typ[i] >= en.T_STAG
				en.hurt(i, en.maxhp[i] * 0.001 if big else 7.0 * hs, 0.0, 0.0, "cagri")
	swarm.visible = true
	var open := clampf((4.0 - ult_t) * 3.0, 0.0, 1.0)
	var fade := clampf(ult_t * 1.6, 0.0, 1.0)
	for k in SWARM_N:
		var s := swarm_seed[k]
		var a := s * 40.0 + wtime * (2.5 + 3.5 * fmod(s * 7.0, 1.0)) * (1.0 if k % 2 == 0 else -1.0)
		var r := (1.5 + 9.5 * fmod(s * 13.0, 1.0)) * open
		var y := 0.7 + 2.2 * fmod(s * 29.0, 1.0) + sin(wtime * 6.0 + s * 20.0) * 0.4
		var sb := Basis(Vector3.UP, -a).scaled_local(Vector3(0.32, 0.32, 1.0) * fade)
		swarm_mm.set_instance_transform(k, Transform3D(sb, Vector3(p.x + cos(a) * r, p.y + y, p.z + sin(a) * r)))

func _fire_bee(p: Vector3, t: int, d: float, pierce: int, k: int, n: int) -> void:
	if qn >= PMAX:
		return
	var en = main.enemies
	var i := qn
	qn += 1
	var a := atan2(en.pz[t] - p.z, en.px[t] - p.x) + (float(k) - float(n - 1) * 0.5) * 0.35
	qx[i] = p.x
	qz[i] = p.z
	qy[i] = p.y + 1.2
	qvx[i] = cos(a) * 15.0
	qvz[i] = sin(a) * 15.0
	qlife[i] = 2.2
	qdmg[i] = d
	qtu[i] = en.uid[t]
	qhint[i] = t
	qpierce[i] = pierce
	qlast[i] = -1

func _update_bees(dt: float) -> void:
	var en = main.enemies
	var i := 0
	var turn := minf(1.0, dt * 9.0)
	while i < qn:
		qlife[i] -= dt
		var gone := qlife[i] <= 0.0
		var t: int = en.index_of(qtu[i], qhint[i])
		if t < 0 and not gone:
			var found := -1
			for j in en.count:
				if en.uid[j] == qtu[i] and en.dead[j] == 0:
					found = j
					break
			if found < 0:
				found = en.nearest(qx[i], qz[i], 12.0, {qlast[i]: true})
				if found >= 0:
					qtu[i] = en.uid[found]
			t = found
			qhint[i] = t
		var ty := 0.9
		if t >= 0:
			var dx: float = en.px[t] - qx[i]
			var dz: float = en.pz[t] - qz[i]
			var d := sqrt(dx * dx + dz * dz) + 0.001
			qvx[i] = lerpf(qvx[i], dx / d * 19.0, turn)
			qvz[i] = lerpf(qvz[i], dz / d * 19.0, turn)
			ty = en.height_of(t) + 0.6
			if d < en.rad[t] + 0.45:
				deal(t, qdmg[i], qvx[i] * 0.25, qvz[i] * 0.25, "ari")
				qlast[i] = en.uid[t]
				qpierce[i] -= 1
				if qpierce[i] < 0:
					gone = true
				else:
					var nt: int = en.nearest(qx[i], qz[i], 10.0, {qlast[i]: true})
					if nt >= 0:
						qtu[i] = en.uid[nt]
						qhint[i] = nt
					else:
						gone = true
		qx[i] += qvx[i] * dt
		qz[i] += qvz[i] * dt
		qy[i] = lerpf(qy[i], ty, minf(1.0, dt * 6.0))
		if gone:
			var l := qn - 1
			qx[i] = qx[l]; qz[i] = qz[l]; qy[i] = qy[l]; qvx[i] = qvx[l]; qvz[i] = qvz[l]
			qlife[i] = qlife[l]; qdmg[i] = qdmg[l]; qtu[i] = qtu[l]; qhint[i] = qhint[l]
			qpierce[i] = qpierce[l]; qlast[i] = qlast[l]
			qn = l
		else:
			var yw := atan2(qvx[i], qvz[i])
			bee_mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yw), Vector3(qx[i], qy[i], qz[i])))
			i += 1
	bee_mm.visible_instance_count = qn

func _update_bombs(dt: float) -> void:
	var keep: Array[Dictionary] = []
	var k := 0
	for n in bomb_nodes:
		n.visible = false
	for bm in bombs:
		bm.t += dt / 0.6
		if bm.t >= 1.0:
			explode(bm.to, bm.r, bm.dmg, "bomba")
			continue
		keep.append(bm)
		if bm.t >= 0.0 and k < bomb_nodes.size():
			var pos: Vector3 = bm.from.lerp(bm.to, bm.t)
			pos.y += sin(bm.t * PI) * 4.0
			var node := bomb_nodes[k]
			node.visible = true
			node.position = pos
			node.rotation = Vector3(bm.t * 9.0, bm.t * 4.0, 0)
			node.scale = Vector3.ONE * 0.75
			k += 1
	bombs = keep

func explode(at: Vector3, r: float, d: float, src: String) -> void:
	var en = main.enemies
	for i in en.query(at.x, at.z, r):
		var dx: float = en.px[i] - at.x
		var dz: float = en.pz[i] - at.z
		var l := sqrt(dx * dx + dz * dz) + 0.01
		deal(i, d, dx / l * 9.0, dz / l * 9.0, src)
	main.fx.explosion(at, r, Color(1.0, 0.72, 0.15))
	main.fx.shake(0.3)
	main.audio.play("explosion", -5.0, randf_range(0.9, 1.1))

func push_back(at: Vector3, r: float, force: float, show := true) -> void:
	var en = main.enemies
	for i in en.query(at.x, at.z, r):
		var dx: float = en.px[i] - at.x
		var dz: float = en.pz[i] - at.z
		var l := sqrt(dx * dx + dz * dz) + 0.01
		var kb: float = en.TYPES[en.typ[i]].kb
		en.vx[i] += dx / l * force * kb
		en.vz[i] += dz / l * force * kb
	if show:
		main.fx.explosion(at, r, Color(1.0, 0.9, 0.5))

func stomp(at: Vector3, lv: int) -> void:
	var r := (3.0 + 0.7 * lv) * area_mult
	var en = main.enemies
	for i in en.query(at.x, at.z, r):
		if en.height_of(i) > 0.5:
			continue
		var dx: float = en.px[i] - at.x
		var dz: float = en.pz[i] - at.z
		var l := sqrt(dx * dx + dz * dz) + 0.01
		deal(i, 12.0 * lv, dx / l * 12.0, dz / l * 12.0, "inis")
	main.fx.explosion(at, r, Color(0.5, 0.95, 0.75))
	main.fx.shake(0.25)
	main.audio.play("boss_slam", -12.0, 1.5)

func _chain(p: Vector3, d: float, jumps: int, first := -1) -> bool:
	var en = main.enemies
	var t: int = first if first >= 0 else en.random_near(p.x, p.z, 13.0)
	if t < 0:
		return false
	var from := p + Vector3(0, 1.3, 0)
	var seen := {}
	for j in jumps:
		if t < 0:
			break
		seen[en.uid[t]] = true
		var to := Vector3(en.px[t], en.height_of(t) + 0.6, en.pz[t])
		_bolt(from, to)
		var tx: float = en.px[t]
		var tz: float = en.pz[t]
		deal(t, d, 0.0, 0.0, "kivilcim")
		from = to
		t = en.nearest(tx, tz, 7.5, seen)
	return true

func _bolt(a: Vector3, c: Vector3) -> void:
	var mid := (a + c) * 0.5 + Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.7), randf_range(-0.5, 0.5))
	for seg in [[a, mid], [mid, c]]:
		var n := bolt_nodes[bolt_i]
		bolt_t[bolt_i] = 0.13
		bolt_i = (bolt_i + 1) % bolt_nodes.size()
		var s: Vector3 = seg[0]
		var e: Vector3 = seg[1]
		var dist := s.distance_to(e)
		if dist < 0.05:
			continue
		n.visible = true
		n.position = (s + e) * 0.5
		var up := Vector3.UP if absf((e - s).normalized().y) < 0.95 else Vector3.RIGHT
		n.look_at_from_position((s + e) * 0.5, e, up)
		n.scale = Vector3(1, 1, dist)
