extends Node3D

const FL := 80.0   # saha boyu (x)
const FW := 50.0   # saha eni (z)
const GW := 10.0   # kale genisligi
const MATCH_TIME := 120.0

# Oyuncu sirasi: 0 kaleci, 1-4 defans, 5-7 orta saha, 8-10 forvet
# Isimleri buradan istedigin gibi degistirebilirsin.
const TEAMS := [
	{"name": "Galatasaray", "color": Color(0.8, 0.1, 0.1),
	 "names": ["Muslera", "Sallai", "Sanchez", "Abdülkerim", "Jakobs", "Torreira", "Lemina", "Yunus", "Barış", "Osimhen", "Mertens"]},
	{"name": "Fenerbahçe", "color": Color(0.1, 0.2, 0.7),
	 "names": ["Livakovic", "Osayi", "Skriniar", "Djiku", "Oosterwolde", "Fred", "Szymanski", "Tadic", "Kerem", "Dzeko", "En-Nesyri"]},
	{"name": "Beşiktaş", "color": Color(0.12, 0.12, 0.12),
	 "names": ["Ersin", "Gabriel", "Uduokhai", "Svensson", "Rashica", "Gedson", "Rafa", "Salih", "Cenk", "Semih", "Ndidi"]},
]

# Formasyonlar: x = kendi kalesinden rakip kaleye 0..1, y = saha eni -1..1
const F_DEF := [Vector2(0.03, 0), Vector2(0.17, -0.7), Vector2(0.15, -0.25), Vector2(0.15, 0.25), Vector2(0.17, 0.7),
	Vector2(0.30, -0.5), Vector2(0.28, 0.0), Vector2(0.30, 0.5), Vector2(0.42, -0.45), Vector2(0.44, 0.0), Vector2(0.42, 0.45)]
const F_ATT := [Vector2(0.05, 0), Vector2(0.38, -0.7), Vector2(0.36, -0.25), Vector2(0.36, 0.25), Vector2(0.38, 0.7),
	Vector2(0.58, -0.5), Vector2(0.55, 0.0), Vector2(0.58, 0.5), Vector2(0.82, -0.5), Vector2(0.86, 0.0), Vector2(0.82, 0.5)]

class Pl:
	var node: Node3D
	var team := 0
	var idx := 0
	var face := Vector3.RIGHT
	var cd := 0.0
	var tackle_t := 0.0
	var dash_t := 0.0
	var dash_dir := Vector3.RIGHT
	var hold_t := 0.0

var players: Array = []
var chasers: Array = [null, null]
var carrier: Pl = null
var ctrl: Pl = null
var ball: Node3D
var ball_vel := Vector3.ZERO
var state := "menu"
var score := [0, 0]
var time_left := MATCH_TIME
var att := [0.0, 0.0]
var conceded := 0
var pause_t := 0.0
var dribble_cd := 0.0
var cam: Camera3D
var cam_h := 24.0
var sun: DirectionalLight3D
var env: Environment
var rain: CPUParticles3D
var marker: MeshInstance3D
var hud: CanvasLayer
var lbl_score: Label
var lbl_msg: Label
var menu: Control
var menu_title: Label
var b_team: Button
var b_tod: Button
var b_wx: Button
var b_go: Button
var joy_base: ColorRect
var joy_knob: ColorRect
var js_id := -1
var js_origin := Vector2.ZERO
var js_vec := Vector2.ZERO
var btn_rects := {}
var play_ui: Array = []
var sel_team := 0
var sel_tod := 0
var sel_wx := 0
var team_idx := [0, 1]


func _ready() -> void:
	await get_tree().process_frame
	build_world()
	build_hud()
	show_menu()


# ---------------------------------------------------------------- dunya
func box(size: Vector3, p: Vector3, c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	m.material_override = mat
	m.position = p
	return m


func build_world() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -30, 0)
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 55
	add_child(cam)
	cam.position = Vector3(0, cam_h, cam_h * 0.75)
	cam.look_at(Vector3.ZERO)

	add_child(box(Vector3(FL + 16, 0.2, FW + 16), Vector3(0, -0.1, 0), Color(0.12, 0.45, 0.15)))
	for i in range(10):
		if i % 2 == 0:
			add_child(box(Vector3(FL / 10.0, 0.02, FW), Vector3(-FL / 2.0 + FL / 10.0 * (i + 0.5), 0.01, 0), Color(0.16, 0.52, 0.19)))
	var lc := Color(1, 1, 1)
	add_child(box(Vector3(FL, 0.03, 0.2), Vector3(0, 0.03, -FW / 2.0), lc))
	add_child(box(Vector3(FL, 0.03, 0.2), Vector3(0, 0.03, FW / 2.0), lc))
	add_child(box(Vector3(0.2, 0.03, FW), Vector3(-FL / 2.0, 0.03, 0), lc))
	add_child(box(Vector3(0.2, 0.03, FW), Vector3(FL / 2.0, 0.03, 0), lc))
	add_child(box(Vector3(0.2, 0.03, FW), Vector3(0, 0.03, 0), lc))
	for s in [-1.0, 1.0]:
		var gx: float = s * FL / 2.0
		add_child(box(Vector3(0.3, 3, 0.3), Vector3(gx, 1.5, -GW / 2.0), lc))
		add_child(box(Vector3(0.3, 3, 0.3), Vector3(gx, 1.5, GW / 2.0), lc))
		add_child(box(Vector3(0.3, 0.3, GW + 0.3), Vector3(gx, 3, 0), lc))

	ball = box(Vector3(0.5, 0.5, 0.5), Vector3(0, 0.3, 0), Color(1, 1, 1))
	add_child(ball)
	marker = box(Vector3(0.4, 0.4, 0.4), Vector3(0, 3.5, 0), Color(1, 0.9, 0.1))
	add_child(marker)
	marker.hide()

	rain = CPUParticles3D.new()
	rain.amount = 700
	rain.lifetime = 1.0
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(50, 1, 35)
	rain.direction = Vector3(0, -1, 0)
	rain.spread = 0.0
	rain.gravity = Vector3.ZERO
	rain.initial_velocity_min = 28.0
	rain.initial_velocity_max = 28.0
	rain.position = Vector3(0, 26, 0)
	var rm := BoxMesh.new()
	rm.size = Vector3(0.04, 0.8, 0.04)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.7, 0.8, 1.0)
	rm.material = rmat
	rain.mesh = rm
	rain.emitting = false
	add_child(rain)


func apply_env() -> void:
	var bg: Color = [Color(0.5, 0.75, 1.0), Color(0.95, 0.55, 0.3), Color(0.02, 0.03, 0.1)][sel_tod]
	var energy: float = [1.1, 0.8, 0.3][sel_tod]
	sun.light_color = [Color(1, 1, 1), Color(1, 0.7, 0.5), Color(0.6, 0.7, 1)][sel_tod]
	env.ambient_light_energy = [0.5, 0.45, 0.35][sel_tod]
	if sel_wx == 1:
		bg = bg * 0.6
		energy *= 0.7
	sun.light_energy = energy
	env.background_color = bg
	env.fog_enabled = (sel_wx == 2)
	env.fog_light_color = Color(0.75, 0.78, 0.8)
	env.fog_density = 0.02
	rain.emitting = (sel_wx == 1)
