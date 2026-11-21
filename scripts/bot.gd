extends RefCounted
# Demo bot used for testing: it steers the player, jumps and slides. It cannot be enabled from inside the game.

const DIRS := 16

var main
var last_dir := Vector2(1, 0)
var think_t := 0.0

func setup(m) -> void:
	main = m

func _goal(p: Vector2) -> Variant:
	var pl = main.player
	var best = null
	var best_d := 1e9
	if pl.hp < pl.max_hp * 0.5:
		for j in main.world.jars:
			var d := p.distance_to(Vector2(j.pos.x, j.pos.z))
			if d < best_d:
				best_d = d
				best = Vector2(j.pos.x, j.pos.z)
		if best != null:
			return best
	for it in main.pickups.items:
		if it.kind == "heal" and pl.hp >= pl.max_hp:
			continue
		var d2 := p.distance_to(Vector2(it.pos.x, it.pos.z))
		if d2 < 25.0 and d2 < best_d:
			best_d = d2
			best = Vector2(it.pos.x, it.pos.z)
	if best != null:
		return best
	var pk = main.pickups
	var n: int = mini(pk.gn, 200)
	for i in n:
		var d3 := p.distance_to(Vector2(pk.gx[i], pk.gz[i]))
		if d3 < 13.0 and d3 < best_d:
			best_d = d3
			best = Vector2(pk.gx[i], pk.gz[i])
	if best != null:
		return best
	for c in main.world.chests:
		var d4 := p.distance_to(Vector2(c.pos.x, c.pos.z))
		if d4 < best_d:
			best_d = d4
			best = Vector2(c.pos.x, c.pos.z)
	for s in main.world.shrines:
		if not s.done:
			var d5 := p.distance_to(Vector2(s.pos.x, s.pos.z)) - 3.0
			if d5 < best_d:
				best_d = d5
				best = Vector2(s.pos.x + 2.5, s.pos.z)
	return best

func update(dt: float) -> void:
	var pl = main.player
	var en = main.enemies
	var p := Vector2(pl.pos.x, pl.pos.z)
	var near: PackedInt32Array = en.query(p.x, p.y, 16.0)
	var close := 0
	for i in near:
		if p.distance_to(Vector2(en.px[i], en.pz[i])) - en.rad[i] < 1.8:
			close += 1
	think_t -= dt
	if think_t <= 0.0:
		think_t = 0.08
		var goal = _goal(p)
		var goal_dir := Vector2.ZERO
		if goal != null and p.distance_to(goal) > 0.6:
			goal_dir = (goal - p).normalized()
		var bi: int = en.boss_index()
		if bi < 0:
			bi = en.champ_index()
		if bi >= 0 and pl.hp > pl.max_hp * 0.35:
			var tb := Vector2(en.px[bi], en.pz[bi]) - p
			var bd := tb.length()
			if bd > 0.1:
				var radial := tb / bd
				goal_dir = (radial.orthogonal() + radial * clampf((bd - 9.0) / 4.0, -1.5, 1.5)).normalized() * 1.6
		var best_s := -1e9
		var best_dir := Vector2.ZERO
		for k in DIRS:
			var dir := Vector2.from_angle(TAU * k / DIRS)
			var q := p + dir * 3.0
			var q0 := p + dir * 1.3
			var danger := 0.0
			var crowd := 0.0
			for i in near:
				var e := Vector2(en.px[i], en.pz[i])
				var l: float = maxf(0.5, q.distance_to(e) - en.rad[i])
				var l0: float = maxf(0.4, q0.distance_to(e) - en.rad[i])
				var w := 1.0 / (l * l) + 0.6 / (l0 * l0)
				if en.typ[i] == en.T_BOSS or en.typ[i] >= en.T_STAG:
					w *= 3.0
				elif en.typ[i] == en.T_BOOM:
					w *= 2.5
				danger += w
				var to := e - p
				var dl := maxf(1.0, to.length())
				var c := dir.dot(to) / dl
				if c > 0.0:
					crowd += c * c / dl
			var s := -danger * 3.0 - crowd * 0.55 + dir.dot(goal_dir) * 0.9 + dir.dot(last_dir) * 0.3
			var far: float = (p + dir * 6.0).length() - (float(main.world.ARENA_R) - 20.0)
			if far > 0.0:
				s -= far * 0.5
			for wz in main.fx.warns:
				var wc := Vector2(wz.x, wz.z)
				var wd := 0.0
				if wz.kind == 0:
					wd = minf(q.distance_to(wc), q0.distance_to(wc)) - float(wz.r)
				else:
					var wdir := Vector2(sin(wz.yaw), cos(wz.yaw))
					var along := clampf((q - wc).dot(wdir), 0.0, float(wz.length))
					wd = q.distance_to(wc + wdir * along) - float(wz.r)
				if wd < 1.0:
					s -= 5.0 * (1.0 - wd)
			var gh: Vector3 = main.world.GREAT
			var into: float = gh.z + 2.5 - (p + dir * 4.0).distance_to(Vector2(gh.x, gh.y))
			if into > 0.0:
				s -= into * 1.2
			if s > best_s:
				best_s = s
				best_dir = dir
		last_dir = best_dir
	pl.bot_move = last_dir
	if main.game.ult >= 1.0:
		var big: int = en.boss_index() if en.boss_index() >= 0 else en.champ_index()
		var big_near: bool = big >= 0 and p.distance_to(Vector2(en.px[big], en.pz[big])) < 12.0
		if close >= 5 or pl.hp < pl.max_hp * 0.45 or big_near:
			main.game.try_ult()
	if pl.on_ground and close >= 2 and randf() < dt * 2.5:
		pl.bot_jump = true
	if close >= 4 and randf() < dt * 2.0:
		pl.bot_slide = true
	if pl.on_ground:
		for bi in en.bcount:
			var bd := Vector2(en.bx[bi] - p.x, en.bz[bi] - p.y)
			if bd.length() < 2.8 and bd.dot(Vector2(en.bvx[bi], en.bvz[bi])) < 0.0:
				pl.bot_jump = true
				break
	for r in en.rings:
		var rd: float = absf(p.distance_to(Vector2(r.x, r.z)) - r.r)
		if rd < 2.2 and pl.on_ground:
			pl.bot_jump = true
	if pl.bot_move.length() > 0.1:
		var want := atan2(-pl.bot_move.x, -pl.bot_move.y)
		pl.cam_yaw = lerp_angle(pl.cam_yaw, want, minf(1.0, dt * 0.8))
