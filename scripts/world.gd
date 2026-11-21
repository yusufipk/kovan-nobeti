extends Node3D
# The meadow: ground, light, scenery, obstacles and cycling rewards.

const ARENA_R := 74.0
# the great hive tree in the middle: Vector3(x, z, trunk radius)
const GREAT := Vector3(0.0, 0.0, 6.2)

# The day runs from afternoon through sunset into a moonlit night on every endless cycle.
const DAY := [
	{"t": 0.00, "elev": 54.0, "yaw": 38.0, "sun_col": Color(1.0, 0.96, 0.86), "sun_e": 1.15, "sky_top": Color(0.20, 0.48, 0.95), "sky_hor": Color(0.70, 0.86, 1.0), "amb_col": Color(0.78, 0.86, 1.0), "amb_e": 0.5, "fog": Color(0.72, 0.86, 1.0), "night": 0.0},
	{"t": 0.33, "elev": 38.0, "yaw": 62.0, "sun_col": Color(1.0, 0.95, 0.82), "sun_e": 1.15, "sky_top": Color(0.20, 0.45, 0.92), "sky_hor": Color(0.80, 0.86, 0.92), "amb_col": Color(0.82, 0.85, 0.95), "amb_e": 0.5, "fog": Color(0.80, 0.86, 0.95), "night": 0.0},
	{"t": 0.52, "elev": 17.0, "yaw": 84.0, "sun_col": Color(1.0, 0.8, 0.56), "sun_e": 1.2, "sky_top": Color(0.22, 0.36, 0.78), "sky_hor": Color(1.0, 0.72, 0.45), "amb_col": Color(0.95, 0.78, 0.70), "amb_e": 0.5, "fog": Color(1.0, 0.75, 0.55), "night": 0.0},
	{"t": 0.66, "elev": 6.0, "yaw": 98.0, "sun_col": Color(1.0, 0.45, 0.28), "sun_e": 1.0, "sky_top": Color(0.16, 0.18, 0.50), "sky_hor": Color(0.95, 0.45, 0.35), "amb_col": Color(0.75, 0.60, 0.85), "amb_e": 0.6, "fog": Color(0.80, 0.50, 0.55), "night": 0.35},
	{"t": 0.76, "elev": -5.0, "yaw": 106.0, "sun_col": Color(1.0, 0.40, 0.30), "sun_e": 0.0, "sky_top": Color(0.06, 0.08, 0.28), "sky_hor": Color(0.40, 0.30, 0.55), "amb_col": Color(0.50, 0.55, 0.95), "amb_e": 0.7, "fog": Color(0.30, 0.30, 0.55), "night": 0.85},
	{"t": 1.00, "elev": -20.0, "yaw": 120.0, "sun_col": Color(1.0, 0.40, 0.30), "sun_e": 0.0, "sky_top": Color(0.03, 0.05, 0.20), "sky_hor": Color(0.16, 0.22, 0.45), "amb_col": Color(0.50, 0.60, 1.0), "amb_e": 0.68, "fog": Color(0.14, 0.20, 0.42), "night": 1.0},
]

var main
var env: Environment
var obstacles: Array = []   # Vector3(x, z, radius)
var static_obstacles: Array = []
var chests: Array[Dictionary] = []
var shrines: Array[Dictionary] = []
var jars: Array[Dictionary] = []
var chest_timer := 0.0
var hive_mat: StandardMaterial3D
var poi_root: Node3D
var shrine_progress := -1.0
var time := 0.0
var rng := RandomNumberGenerator.new()
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var lantern: OmniLight3D
var sky_mat: ProceduralSkyMaterial
var ground_mat: ShaderMaterial
var deco_hive_mat: StandardMaterial3D
var cloud_mat: StandardMaterial3D
var cloud_root: Node3D
var firefly_mat: ShaderMaterial
var fireflies: MultiMeshInstance3D
var flora_mats: Array = []
var great_mat: ShaderMaterial
var great_light: OmniLight3D
# time of day last applied (0 afternoon .. 1 night) and smooth dawn transition value
var day := -1.0
var day_visual := 0.0
var night := 0.0

func setup(m) -> void:
	main = m
	rng.seed = 20261116
	_build_environment()
	_build_ground()
	_build_scenery()
	poi_root = Node3D.new()
	add_child(poi_root)

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.5, 0.95)
	sky_mat.sky_horizon_color = Color(0.72, 0.87, 1.0)
	sky_mat.ground_horizon_color = Color(0.6, 0.8, 0.7)
	sky_mat.ground_bottom_color = Color(0.35, 0.55, 0.3)
	sky_mat.sun_angle_max = 12.0
	var star_img := Image.create(1024, 512, false, Image.FORMAT_RGB8)
	star_img.fill(Color.BLACK)
	for i in 1500:
		var sx := rng.randi_range(1, 1022)
		var sy := rng.randi_range(1, 300)
		var sb := rng.randf_range(0.25, 1.0)
		star_img.set_pixel(sx, sy, Color(sb, sb, sb * 1.1))
		if sb > 0.9:
			star_img.set_pixel(sx + 1, sy, Color(sb, sb, sb) * 0.6)
			star_img.set_pixel(sx, sy + 1, Color(sb, sb, sb) * 0.6)
	sky_mat.sky_cover = ImageTexture.create_from_image(star_img)
	sky_mat.sky_cover_modulate = Color.BLACK
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.ambient_light_color = Color(0.78, 0.86, 1.0)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.86, 1.0)
	env.fog_density = 0.0007
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.06
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 38, 0)
	sun.light_color = Color(1.0, 0.96, 0.86)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_opacity = 0.65
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-56, -140, 0)
	moon.light_color = Color(0.62, 0.76, 1.0)
	moon.light_energy = 0.0
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 60.0
	moon.shadow_opacity = 0.55
	moon.visible = false
	add_child(moon)
	lantern = OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.8, 0.5)
	lantern.omni_range = 13.0
	lantern.omni_attenuation = 1.3
	lantern.light_energy = 0.0
	lantern.shadow_enabled = false
	lantern.visible = false
	add_child(lantern)

# f = 0 is the afternoon each cycle starts in, f = 1 the night the Queen arrives in.
func set_daytime(f: float) -> void:
	f = clampf(f, 0.0, 1.0)
	if absf(f - day) < 0.0015:
		return
	day = f
	var i := 0
	while i < DAY.size() - 2 and f > float(DAY[i + 1].t):
		i += 1
	var a: Dictionary = DAY[i]
	var b: Dictionary = DAY[i + 1]
	var k := clampf((f - float(a.t)) / (float(b.t) - float(a.t)), 0.0, 1.0)
	var elev := lerpf(a.elev, b.elev, k)
	night = lerpf(a.night, b.night, k)
	sun.rotation_degrees = Vector3(-elev, lerpf(a.yaw, b.yaw, k), 0)
	sun.light_color = (a.sun_col as Color).lerp(b.sun_col, k)
	sun.light_energy = lerpf(a.sun_e, b.sun_e, k) * smoothstep(-3.0, 4.0, elev)
	sun.visible = sun.light_energy > 0.01
	moon.light_energy = 0.7 * smoothstep(0.3, 0.9, night)
	moon.visible = moon.light_energy > 0.01
	var top := (a.sky_top as Color).lerp(b.sky_top, k)
	var hor := (a.sky_hor as Color).lerp(b.sky_hor, k)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor.lerp(Color(0.5, 0.75, 0.6), 0.45 * (1.0 - night))
	sky_mat.ground_bottom_color = Color(0.35, 0.55, 0.3).lerp(top, 0.3 + 0.6 * night)
	sky_mat.sky_cover_modulate = Color(night, night, night)
	env.ambient_light_color = (a.amb_col as Color).lerp(b.amb_col, k)
	env.ambient_light_energy = lerpf(a.amb_e, b.amb_e, k)
	env.fog_light_color = (a.fog as Color).lerp(b.fog, k)
	env.fog_density = lerpf(0.0007, 0.0015, night)
	env.glow_intensity = lerpf(0.5, 0.72, night)
	lantern.light_energy = 1.5 * night
	lantern.visible = night > 0.02
	if ground_mat != null:
		ground_mat.set_shader_parameter("night", night)
	for m in flora_mats:
		m.set_shader_parameter("night", night)
	if firefly_mat != null:
		firefly_mat.set_shader_parameter("night", night)
		fireflies.visible = night > 0.02
	if cloud_mat != null:
		cloud_mat.albedo_color = Color.WHITE.lerp(hor, 0.5) * lerpf(1.0, 0.34, night)
	if deco_hive_mat != null:
		deco_hive_mat.emission_energy_multiplier = 0.55 * night
	if great_mat != null:
		great_mat.set_shader_parameter("night", night)
		great_light.light_energy = 0.4 + 2.4 * night
	main.assets.set_night(night)

func set_brightness(v: float) -> void:
	env.adjustment_brightness = v

func _build_ground() -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	g.mesh = pm
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform float arena = 74.0;
uniform float night = 0.0;
varying vec3 wp;
const vec2 HS = vec2(1.0, 1.7320508);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float hexd(vec2 p) { p = abs(p); return max(dot(p, HS * 0.5), p.x); }
vec4 hexc(vec2 p) {
	vec4 hc = floor(vec4(p, p - vec2(0.5, 1.0)) / HS.xyxy) + 0.5;
	vec4 h = vec4(p - hc.xy * HS, p - (hc.zw + 0.5) * HS);
	return dot(h.xy, h.xy) < dot(h.zw, h.zw) ? vec4(h.xy, hc.xy) : vec4(h.zw, hc.zw + 0.5);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = vec2(wp.x * 0.30 + wp.z * 0.12, wp.z * 0.30 - wp.x * 0.07);
	vec2 c = floor(p);
	vec2 f = fract(p);
	float tri = step(f.x + f.y, 1.0);
	float h = hash(c + vec2(tri * 7.3, tri * 1.7));
	float big = hash(floor(wp.xz * 0.05 + 3.0));
	float n = vnoise(wp.xz * 0.045) * 0.65 + vnoise(wp.xz * 0.13 + 7.0) * 0.35;
	vec3 deep = mix(vec3(0.20, 0.47, 0.20), vec3(0.27, 0.55, 0.22), h);
	vec3 lush = mix(vec3(0.32, 0.60, 0.19), vec3(0.44, 0.71, 0.25), h);
	vec3 dry = mix(vec3(0.55, 0.70, 0.27), vec3(0.65, 0.77, 0.32), h);
	vec3 col = mix(deep, lush, smoothstep(0.28, 0.46, n));
	col = mix(col, dry, smoothstep(0.62, 0.8, n));
	col *= 0.94 + 0.1 * big;
	float r = length(wp.xz);
	float ang = atan(wp.z, wp.x) + sin(r * 0.19) * 0.1;
	float da = abs(mod(ang + 0.7853982, 1.5707963) - 0.7853982) * r;
	float path = (1.0 - smoothstep(1.1, 2.3, da + (h - 0.5) * 0.8)) * (1.0 - smoothstep(50.0, 64.0, r));
	col = mix(col, mix(vec3(0.60, 0.47, 0.30), vec3(0.69, 0.56, 0.37), h), path);
	vec2 hp = wp.xz / 1.5;
	vec4 hx = hexc(hp);
	float seam = 1.0 - smoothstep(0.03, 0.07, 0.5 - hexd(hx.xy));
	float keep = step(hash(hx.zw * 3.7 + 1.3), 1.0 - smoothstep(11.0, 16.5, length((hp - hx.xy) * 1.5)));
	vec3 tile = mix(vec3(0.74, 0.62, 0.40), vec3(0.86, 0.73, 0.47), hash(hx.zw));
	col = mix(col, mix(tile, vec3(0.95, 0.60, 0.10), seam), keep);
	col = mix(col, vec3(0.27, 0.48, 0.19), smoothstep(arena - 3.0, arena + 4.0, r));
	ALBEDO = pow(col, vec3(2.2));
	EMISSION = vec3(1.0, 0.42, 0.03) * seam * keep * (0.1 + night * 1.4);
	ROUGHNESS = 0.95;
}
"""
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = sh
	ground_mat.set_shader_parameter("arena", ARENA_R)
	g.material_override = ground_mat
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)

func _mm(mesh: Mesh, mat: Material, xfs: Array, cols: Array = [], shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if not cols.is_empty():
			mm.set_instance_color(i, cols[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	if mat != null:
		inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	return inst

func _free_spot(rmin: float, rmax: float, clearance: float) -> Vector2:
	for attempt in 60:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf_range(rmin * rmin, rmax * rmax))
		var p := Vector2(cos(a) * r, sin(a) * r)
		var ok := paved(p.x, p.y) < 0.2
		for o in obstacles:
			if Vector2(o.x, o.y).distance_to(p) < o.z + clearance:
				ok = false
				break
		if ok:
			return p
	return Vector2(rmin, rmin)

func paved(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	if r < 15.0:
		return 1.0
	if r > 64.0:
		return 0.0
	var ang := atan2(z, x) + sin(r * 0.19) * 0.1
	var da := absf(fposmod(ang + PI * 0.25, PI * 0.5) - PI * 0.25) * r
	return 1.0 - smoothstep(1.5, 2.8, da)

func _spindle(st: SurfaceTool, y0: float, y1: float, r: float, sides: int, c0: Color, c1: Color) -> void:
	var ym := lerpf(y0, y1, 0.4)
	for s in sides:
		var a0 := TAU * s / sides
		var a1 := TAU * (s + 1) / sides
		var p0 := Vector3(cos(a0) * r, ym, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, ym, sin(a1) * r)
		var cm := c0.lerp(c1, 0.4)
		for v in [[Vector3(0, y0, 0), c0], [p0, cm], [p1, cm], [p0, cm], [Vector3(0, y1, 0), c1], [p1, cm]]:
			st.set_color(v[1])
			st.add_vertex(v[0])

func _build_flora() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, world_vertex_coords;
uniform vec3 player = vec3(0.0, 100.0, 0.0);
uniform float sway = 1.0;
uniform float night = 0.0;
uniform float glow = 0.0;
varying vec3 vc;
varying float gm;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float h = max(VERTEX.y, 0.0);
	float w = sin(TIME * 1.7 + o.x * 0.35 + o.z * 0.27) * 0.6 + sin(TIME * 3.1 + o.x * 0.9 - o.z * 0.6) * 0.3;
	vec2 away = o.xz - player.xz;
	float d = length(away);
	float press = (1.0 - smoothstep(0.4, 1.6, d)) * (1.0 - step(0.7, player.y));
	vec2 off = vec2(0.2, 0.11) * w * sway + (away / max(d, 0.05)) * press * 0.9;
	VERTEX.xz += off * h;
	VERTEX.y -= dot(off, off) * h * 0.6;
	NORMAL = vec3(0.0, 1.0, 0.0);
	vc = COLOR.rgb;
	gm = COLOR.a;
}
void fragment() {
	vec3 c = pow(vc, vec3(2.2));
	ALBEDO = c;
	ROUGHNESS = 0.95;
	EMISSION = c * glow * night * gm;
}
"""
	var mats: Array = []
	for cfg in [[1.0, 0.0], [0.75, 0.55], [0.75, 0.0]]:
		var fm := ShaderMaterial.new()
		fm.shader = sh
		fm.set_shader_parameter("sway", cfg[0])
		fm.set_shader_parameter("glow", cfg[1])
		mats.append(fm)
	flora_mats = mats
	var grass_mat: ShaderMaterial = mats[0]
	var bloom_mat: ShaderMaterial = mats[1]
	var stem_mat: ShaderMaterial = mats[2]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shade := [0.7, 0.7, 0.86, 0.86, 1.0]
	for k in 3:
		var yaw := TAU * k / 3.0 + 0.4
		var bb := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.34)
		var pts := [Vector3(-0.055, 0, 0), Vector3(0.055, 0, 0), Vector3(-0.035, 0.55, 0), Vector3(0.035, 0.55, 0), Vector3(0, 1.0, 0)]
		for idx in [0, 1, 2, 1, 3, 2, 2, 3, 4]:
			st.set_color(Color(shade[idx], shade[idx], shade[idx]))
			st.add_vertex(bb * pts[idx] + Vector3(sin(yaw), 0, cos(yaw)) * 0.05)
	var clump: ArrayMesh = st.commit()
	var xfs: Array = []
	var cols: Array = []
	var tones := [Color(0.4, 0.7, 0.22), Color(0.52, 0.8, 0.28), Color(0.68, 0.84, 0.34)]
	var spots: Array = []
	for i in 9000:
		var a3 := rng.randf() * TAU
		var r3 := sqrt(rng.randf()) * (ARENA_R + 6.0)
		spots.append(Vector3(cos(a3) * r3, rng.randf_range(0.3, 0.55), sin(a3) * r3))
	for stand in 320:
		var sa := rng.randf() * TAU
		var sr := sqrt(rng.randf()) * (ARENA_R + 2.0)
		for i in rng.randi_range(6, 12):
			spots.append(Vector3(cos(sa) * sr + rng.randf_range(-1.5, 1.5), rng.randf_range(0.55, 0.9), sin(sa) * sr + rng.randf_range(-1.5, 1.5)))
	for sp in spots:
		if paved(sp.x, sp.z) > 0.15:
			continue
		var gs: float = sp.y
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(gs * 1.3, gs, gs * 1.3)), Vector3(sp.x, 0, sp.z)))
		cols.append((tones[rng.randi() % 3] as Color).lerp(tones[rng.randi() % 3], rng.randf()))
	_mm(clump, grass_mat, xfs, cols, false)
	var flower_head := CylinderMesh.new()
	flower_head.top_radius = 0.12
	flower_head.bottom_radius = 0.05
	flower_head.height = 0.05
	flower_head.radial_segments = 6
	flower_head.rings = 1
	var stem := BoxMesh.new()
	stem.size = Vector3(0.03, 1.0, 0.03)
	xfs = []
	cols = []
	var stems: Array = []
	var stem_cols: Array = []
	var palette := [Color(1, 1, 0.95), Color(1.0, 0.85, 0.2), Color(0.66, 0.42, 0.9), Color(1.0, 0.6, 0.75), Color(1.0, 0.45, 0.3)]
	for patch in 230:
		var ca := rng.randf() * TAU
		var cr := sqrt(rng.randf()) * (ARENA_R + 4.0)
		var centre := Vector2(cos(ca) * cr, sin(ca) * cr)
		var col: Color = palette[rng.randi() % palette.size()]
		for i in rng.randi_range(5, 13):
			var p4 := centre + Vector2(rng.randf_range(-1.8, 1.8), rng.randf_range(-1.8, 1.8))
			if paved(p4.x, p4.y) > 0.15:
				continue
			var h4 := rng.randf_range(0.22, 0.48)
			var s4 := rng.randf_range(0.9, 1.5)
			var tilt := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.35, 0.35))
			xfs.append(Transform3D(tilt.scaled(Vector3(s4, s4, s4)), Vector3(p4.x, h4, p4.y)))
			stems.append(Transform3D(Basis.from_scale(Vector3(1, h4, 1)), Vector3(p4.x, h4 * 0.5, p4.y)))
			cols.append(col.lerp(Color.WHITE, rng.randf() * 0.2))
			stem_cols.append(Color(0.25, 0.5, 0.16))
	_mm(flower_head, bloom_mat, xfs, cols, false)
	_mm(stem, stem_mat, stems, stem_cols, false)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_spindle(st, 0.0, 0.62, 0.022, 3, Color(0.24, 0.46, 0.2, 0.0), Color(0.36, 0.56, 0.26, 0.0))
	_spindle(st, 0.5, 1.0, 0.075, 4, Color(0.5, 0.32, 0.86, 1.0), Color(0.74, 0.56, 1.0, 1.0))
	var spike: ArrayMesh = st.commit()
	xfs = []
	cols = []
	for bed in 26:
		var ba := rng.randf() * TAU
		var br := rng.randf_range(17.0, ARENA_R - 2.0)
		var at := Vector2(cos(ba) * br, sin(ba) * br)
		var dir := rng.randf() * TAU
		var bend := rng.randf_range(-0.12, 0.12)
		for bush in rng.randi_range(7, 14):
			at += Vector2(cos(dir), sin(dir)) * 1.05
			dir += bend
			if paved(at.x, at.y) > 0.15 or at.length() > ARENA_R + 3.0:
				continue
			var tint := Color(1, 1, 1).lerp(Color(1.0, 0.8, 0.95), rng.randf())
			for sp2 in rng.randi_range(6, 9):
				var lean := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0.05, 0.5))
				var ls := rng.randf_range(0.75, 1.15)
				xfs.append(Transform3D(lean.scaled(Vector3(ls, ls, ls)), Vector3(at.x + rng.randf_range(-0.18, 0.18), 0, at.y + rng.randf_range(-0.18, 0.18))))
				cols.append(tint)
	_mm(spike, bloom_mat, xfs, cols, false)

func _build_sky_life() -> void:
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 1.3
	puff.radial_segments = 8
	puff.rings = 4
	cloud_mat = StandardMaterial3D.new()
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.disable_fog = true
	var xfs: Array = []
	for c in 30:
		var ca := rng.randf() * TAU
		var cr := rng.randf_range(150.0, 340.0)
		var centre := Vector3(cos(ca) * cr, rng.randf_range(75.0, 150.0), sin(ca) * cr)
		var cs := rng.randf_range(14.0, 30.0)
		for p in rng.randi_range(4, 7):
			var ps := cs * rng.randf_range(0.55, 1.0)
			var off := Vector3(rng.randf_range(-1.6, 1.6) * cs, rng.randf_range(-0.12, 0.2) * cs, rng.randf_range(-0.8, 0.8) * cs)
			xfs.append(Transform3D(Basis.from_scale(Vector3(ps * 1.5, ps * 0.62, ps * 1.2)), centre + off))
	cloud_root = Node3D.new()
	add_child(cloud_root)
	var clouds := _mm(puff, cloud_mat, xfs, [], false)
	clouds.reparent(cloud_root)
	var fsh := Shader.new()
	fsh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float night = 0.0;
varying float a;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float ph = o.x * 1.3 + o.z * 0.7;
	vec3 drift = vec3(sin(TIME * 0.6 + ph), sin(TIME * 0.9 + ph * 1.7) * 0.4, cos(TIME * 0.5 + ph * 1.3)) * 1.3;
	a = max(0.0, sin(TIME * 2.2 + ph * 3.0)) * night;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(o + drift, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	float g = pow(max(0.0, 1.0 - length(UV - 0.5) * 2.0), 2.0);
	ALBEDO = vec3(1.0, 0.92, 0.35) * 2.5;
	ALPHA = g * a;
}
"""
	firefly_mat = ShaderMaterial.new()
	firefly_mat.shader = fsh
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	xfs = []
	for i in 320:
		var fa := rng.randf() * TAU
		var fr := sqrt(rng.randf()) * (ARENA_R + 4.0)
		xfs.append(Transform3D(Basis(), Vector3(cos(fa) * fr, rng.randf_range(0.5, 2.6), sin(fa) * fr)))
	fireflies = _mm(quad, firefly_mat, xfs, [], false)
	fireflies.visible = false

func _build_scenery() -> void:
	var tree_mesh: Mesh = main.assets.prop_mesh("agac")
	var tree_mat: Material = main.assets.prop_material("agac", true)
	if ResourceLoader.exists("res://assets/models/anakovan.glb"):
		var gh := MeshInstance3D.new()
		gh.mesh = main.assets.prop_mesh("anakovan")
		great_mat = main.assets.great_hive_material()
		gh.material_override = great_mat
		gh.scale = Vector3.ONE * 17.0
		gh.position = Vector3(GREAT.x, -0.2, GREAT.y)
		add_child(gh)
		great_light = OmniLight3D.new()
		great_light.light_color = Color(1.0, 0.72, 0.3)
		great_light.omni_range = 24.0
		great_light.omni_attenuation = 1.2
		great_light.light_energy = 0.4
		great_light.position = Vector3(GREAT.x, 6.0, GREAT.y + 7.0)
		add_child(great_light)
		obstacles.append(GREAT)
	var xfs: Array = []
	for i in 170:
		var a := TAU * i / 170.0 + rng.randf_range(-0.02, 0.02)
		var r := ARENA_R + rng.randf_range(1.5, 16.0)
		var s := rng.randf_range(8.0, 13.0)
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(cos(a) * r, 0, sin(a) * r)))
	for i in 20:
		var p := _free_spot(18.0, ARENA_R - 6.0, 6.0)
		var s2 := rng.randf_range(6.5, 9.0)
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s2, s2, s2)), Vector3(p.x, 0, p.y)))
		obstacles.append(Vector3(p.x, p.y, 0.75))
	_mm(tree_mesh, tree_mat, xfs)
	var hive_mesh: Mesh = main.assets.prop_mesh("kovan")
	deco_hive_mat = main.assets.prop_material("kovan", true)
	deco_hive_mat.emission_enabled = true
	deco_hive_mat.emission = Color(1.0, 0.72, 0.25)
	deco_hive_mat.emission_energy_multiplier = 0.0
	xfs = []
	for i in 9:
		var p2 := _free_spot(16.0, ARENA_R - 8.0, 5.0)
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(2.6, 2.6, 2.6)), Vector3(p2.x, 0, p2.y)))
		obstacles.append(Vector3(p2.x, p2.y, 1.1))
	_mm(hive_mesh, deco_hive_mat, xfs)
	var rock := SphereMesh.new()
	rock.radius = 1.0
	rock.height = 1.4
	rock.radial_segments = 7
	rock.rings = 3
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.58, 0.58, 0.62)
	rmat.roughness = 0.95
	rmat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	rmat.distance_fade_min_distance = 2.0
	rmat.distance_fade_max_distance = 6.0
	xfs = []
	for i in 34:
		var p3 := _free_spot(15.0, ARENA_R - 3.0, 3.0)
		var s3 := rng.randf_range(0.5, 1.7)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s3 * rng.randf_range(0.8, 1.3), s3 * rng.randf_range(0.6, 1.0), s3))
		xfs.append(Transform3D(b, Vector3(p3.x, s3 * 0.15, p3.y)))
		if s3 > 1.0:
			obstacles.append(Vector3(p3.x, p3.y, s3 * 0.95))
	_mm(rock, rmat, xfs)
	static_obstacles = obstacles.duplicate()
	_build_flora()
	_build_sky_life()
	var cols: Array = []
	var hill := CylinderMesh.new()
	hill.top_radius = 0.0
	hill.bottom_radius = 1.0
	hill.height = 1.0
	hill.radial_segments = 6
	hill.rings = 1
	var hmat := StandardMaterial3D.new()
	hmat.vertex_color_use_as_albedo = true
	hmat.vertex_color_is_srgb = true
	hmat.roughness = 1.0
	xfs = []
	cols = []
	for i in 16:
		var a4 := TAU * i / 16.0 + rng.randf_range(-0.1, 0.1)
		var r4 := rng.randf_range(210.0, 300.0)
		var hh := rng.randf_range(50.0, 110.0)
		var hw := rng.randf_range(70.0, 120.0)
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(hw, hh, hw)), Vector3(cos(a4) * r4, hh * 0.5 - 4.0, sin(a4) * r4)))
		cols.append(Color(0.3, 0.52, 0.45).lerp(Color(0.42, 0.6, 0.62), rng.randf()))
	_mm(hill, hmat, xfs, cols, false)

func _beam(col: Color, height: float) -> MeshInstance3D:
	var b := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.12
	c.bottom_radius = 0.32
	c.height = height
	c.radial_segments = 8
	c.rings = 1
	b.mesh = c
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col.r, col.g, col.b, 0.22)
	m.disable_fog = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	b.material_override = m
	b.position.y = height * 0.5
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return b

func _spawn_shrines() -> void:
	var sh_mesh: Mesh = main.assets.prop_mesh("sunak")
	for i in 4:
		var a2 := TAU * i / 4.0 + rng.randf_range(0.2, 1.2)
		var p2 := _spot_near(a2, rng.randf_range(34.0, 58.0))
		var n2 := Node3D.new()
		n2.position = Vector3(p2.x, 0, p2.y)
		var mi2 := MeshInstance3D.new()
		mi2.mesh = sh_mesh
		mi2.material_override = main.assets.prop_material("sunak")
		mi2.scale = Vector3.ONE * 3.4
		n2.add_child(mi2)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 4.75
		tm.outer_radius = 5.0
		tm.rings = 48
		tm.ring_segments = 4
		ring.mesh = tm
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.albedo_color = Color(0.2, 0.9, 0.8)
		ring.material_override = rm
		ring.position.y = 0.08
		ring.scale.y = 0.3
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n2.add_child(ring)
		var beam := _beam(Color(0.2, 0.95, 0.85), 30.0)
		n2.add_child(beam)
		poi_root.add_child(n2)
		obstacles.append(Vector3(p2.x, p2.y, 1.5))
		shrines.append({"node": n2, "pos": Vector3(p2.x, 0, p2.y), "charge": 0.0, "done": false, "ring": rm, "beam": beam})

func _spawn_jars() -> void:
	var jar_mesh: Mesh = main.assets.prop_mesh("kavanoz")
	for i in 7:
		var p3 := _free_spot(14.0, ARENA_R - 6.0, 3.0)
		var mi3 := MeshInstance3D.new()
		mi3.mesh = jar_mesh
		mi3.material_override = main.assets.prop_material("kavanoz")
		mi3.scale = Vector3.ONE * 1.1
		mi3.position = Vector3(p3.x, 0.2, p3.y)
		poi_root.add_child(mi3)
		jars.append({"node": mi3, "pos": Vector3(p3.x, 0, p3.y)})

# New reward layout every run.
func reset() -> void:
	for c in poi_root.get_children():
		c.queue_free()
	chests.clear()
	shrines.clear()
	jars.clear()
	obstacles = static_obstacles.duplicate()
	rng.randomize()
	shrine_progress = -1.0
	day_visual = 0.0 if main.state == main.PLAY else 0.5
	day = -1.0
	set_daytime(day_visual)
	hive_mat = main.assets.prop_material("kovan")
	hive_mat.emission_enabled = true
	hive_mat.emission = Color(1.0, 0.8, 0.2)
	hive_mat.emission_energy_multiplier = 0.35
	chest_timer = 70.0
	var a0 := rng.randf() * TAU
	spawn_chest(a0, rng.randf_range(44.0, 60.0))
	spawn_chest(a0 + PI + rng.randf_range(-0.6, 0.6), rng.randf_range(44.0, 60.0))
	_spawn_shrines()
	_spawn_jars()

# Refresh shrines, heal jars and chest cadence at the start of every new endless cycle.
func next_cycle() -> void:
	for s in shrines:
		(s.node as Node).queue_free()
	shrines.clear()
	for j in jars:
		(j.node as Node).queue_free()
	jars.clear()
	obstacles = static_obstacles.duplicate()
	shrine_progress = -1.0
	_spawn_shrines()
	_spawn_jars()
	chest_timer = 45.0
	if chests.size() < 2:
		spawn_chest(rng.randf() * TAU, rng.randf_range(40.0, 60.0))

func spawn_chest(angle: float, radius: float) -> void:
	var p := _spot_near(angle, radius)
	var n := Node3D.new()
	n.position = Vector3(p.x, 0, p.y)
	var mi := MeshInstance3D.new()
	mi.mesh = main.assets.prop_mesh("kovan")
	mi.material_override = hive_mat
	mi.scale = Vector3.ONE * 2.0
	n.add_child(mi)
	n.add_child(_beam(Color(1.0, 0.8, 0.2), 30.0))
	poi_root.add_child(n)
	chests.append({"node": n, "mesh": mi, "pos": Vector3(p.x, 0, p.y)})

func _spot_near(angle: float, radius: float) -> Vector2:
	var best := Vector2(cos(angle) * radius, sin(angle) * radius)
	for attempt in 20:
		var p := best + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)) * float(attempt) * 0.3
		var ok := true
		for o in obstacles:
			if Vector2(o.x, o.y).distance_to(p) < o.z + 4.0:
				ok = false
				break
		if ok and p.length() < ARENA_R - 7.0:
			return p
	return best

func update(dt: float) -> void:
	time += dt
	var pl = main.player
	var p: Vector3 = pl.pos
	var target_day: float = main.game.loop_time / main.game.CYCLE_TIME
	if target_day < day_visual:
		# smooth dawn transition when a new cycle begins
		day_visual = maxf(target_day, day_visual - dt * 0.25)
	else:
		day_visual = target_day
	set_daytime(day_visual)
	cloud_root.rotation.y += dt * 0.004
	lantern.position = p + Vector3(0, 1.7, 0)
	for fm in flora_mats:
		fm.set_shader_parameter("player", p)
	chest_timer -= dt
	if chest_timer <= 0.0:
		chest_timer = 70.0
		if chests.size() < 3 and main.game.active and not main.game.boss_spawned:
			var away := atan2(-p.z, -p.x) + rng.randf_range(-0.9, 0.9)
			if Vector2(p.x, p.z).length() < 12.0:
				away = rng.randf() * TAU
			spawn_chest(away, rng.randf_range(40.0, 62.0))
			main.ui.toast("Uzakta bir sandık belirdi")
			main.audio.play("heal", -4.0, 0.8)
	var keep_chests: Array[Dictionary] = []
	for c in chests:
		c.mesh.rotation.y += dt * 0.8
		c.mesh.position.y = 0.15 + sin(time * 2.0) * 0.12
		if Vector2(p.x - c.pos.x, p.z - c.pos.z).length() < 2.4:
			(c.node as Node).queue_free()
			main.fx.burst(c.pos + Vector3(0, 1.2, 0), Color(1.0, 0.85, 0.2), 28, 8.0)
			main.audio.play("chest")
			main.game.open_chest()
		else:
			keep_chests.append(c)
	chests = keep_chests
	shrine_progress = -1.0
	for s in shrines:
		if s.done:
			continue
		var d := Vector2(p.x - s.pos.x, p.z - s.pos.z).length()
		if d < 5.0:
			s.charge = minf(1.0, s.charge + dt / 5.0)
			shrine_progress = s.charge
			s.ring.albedo_color = Color(0.2, 0.9, 0.8).lerp(Color(1.0, 0.9, 0.3), s.charge)
			if s.charge >= 1.0:
				s.done = true
				s.ring.albedo_color = Color(0.4, 0.4, 0.45)
				s.beam.visible = false
				main.game.shrine_done(s.pos)
		else:
			s.charge = maxf(0.0, s.charge - dt * 0.25)
	var keep_jars: Array[Dictionary] = []
	for j in jars:
		j.node.rotation.y += dt * 1.5
		j.node.position.y = 0.3 + sin(time * 2.5 + j.pos.x) * 0.12
		if pl.hp < pl.max_hp and Vector2(p.x - j.pos.x, p.z - j.pos.z).length() < 1.7:
			(j.node as Node).queue_free()
			pl.heal(35.0)
			main.fx.burst(j.pos + Vector3(0, 1.0, 0), Color(1.0, 0.5, 0.5), 14, 5.0)
			main.audio.play("heal")
			main.ui.toast("+35 can")
		else:
			keep_jars.append(j)
	jars = keep_jars
