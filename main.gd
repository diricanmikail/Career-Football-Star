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
# ---------------------------------------------------------------- arayuz
func make_btn(key: String, r: Rect2, txt: String, col: Color) -> void:
	var c := ColorRect.new()
	c.color = Color(col.r, col.g, col.b, 0.55)
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 22)
	l.position = Vector2(8, r.size.y / 2.0 - 16.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(l)
	hud.add_child(c)
	btn_rects[key] = r
	play_ui.append(c)


func menu_btn(parent: Control) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(520, 80)
	b.add_theme_font_size_override("font_size", 32)
	parent.add_child(b)
	return b


func build_hud() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	hud = CanvasLayer.new()
	add_child(hud)

	lbl_score = Label.new()
	lbl_score.position = Vector2(vp.x / 2.0 - 250, 10)
	lbl_score.size = Vector2(500, 50)
	lbl_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_score.add_theme_font_size_override("font_size", 38)
	lbl_score.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_score.add_theme_constant_override("outline_size", 8)
	hud.add_child(lbl_score)
	play_ui.append(lbl_score)

	lbl_msg = Label.new()
	lbl_msg.position = Vector2(vp.x / 2.0 - 350, vp.y / 2.0 - 120)
	lbl_msg.size = Vector2(700, 90)
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.add_theme_font_size_override("font_size", 64)
	lbl_msg.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	lbl_msg.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_msg.add_theme_constant_override("outline_size", 12)
	hud.add_child(lbl_msg)
	lbl_msg.hide()

	joy_base = ColorRect.new()
	joy_base.color = Color(1, 1, 1, 0.2)
	joy_base.size = Vector2(160, 160)
	joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(joy_base)
	joy_base.hide()
	joy_knob = ColorRect.new()
	joy_knob.color = Color(1, 1, 1, 0.5)
	joy_knob.size = Vector2(70, 70)
	joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(joy_knob)
	joy_knob.hide()

	make_btn("shoot", Rect2(vp.x - 190, vp.y - 200, 160, 160), "ŞUT", Color(0.9, 0.2, 0.2))
	make_btn("pass", Rect2(vp.x - 360, vp.y - 140, 130, 110), "PAS", Color(0.2, 0.6, 0.9))
	make_btn("dribble", Rect2(vp.x - 340, vp.y - 290, 130, 110), "DRİBLİNG", Color(0.9, 0.7, 0.1))
	make_btn("far", Rect2(vp.x - 230, 20, 100, 60), "UZAK", Color(0.5, 0.5, 0.5))
	make_btn("near", Rect2(vp.x - 120, 20, 100, 60), "YAKIN", Color(0.5, 0.5, 0.5))

	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(menu)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(dim)
	var vb := VBoxContainer.new()
	vb.position = Vector2(vp.x / 2.0 - 260, 40)
	vb.custom_minimum_size = Vector2(520, 0)
	vb.add_theme_constant_override("separation", 14)
	menu.add_child(vb)
	menu_title = Label.new()
	menu_title.text = "MİNİ FUTBOL"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_font_size_override("font_size", 48)
	vb.add_child(menu_title)
	b_team = menu_btn(vb)
	b_tod = menu_btn(vb)
	b_wx = menu_btn(vb)
	b_go = menu_btn(vb)
	b_team.pressed.connect(_on_team)
	b_tod.pressed.connect(_on_tod)
	b_wx.pressed.connect(_on_wx)
	b_go.pressed.connect(start_match)


func _on_team() -> void:
	sel_team = (sel_team + 1) % TEAMS.size()
	refresh_menu()


func _on_tod() -> void:
	sel_tod = (sel_tod + 1) % 3
	refresh_menu()


func _on_wx() -> void:
	sel_wx = (sel_wx + 1) % 3
	refresh_menu()


func refresh_menu() -> void:
	b_team.text = "Takımın: " + TEAMS[sel_team]["name"]
	b_tod.text = "Saat: " + ["Gündüz", "Akşam", "Gece"][sel_tod]
	b_wx.text = "Hava: " + ["Açık", "Yağmurlu", "Sisli"][sel_wx]
	b_go.text = "MAÇA BAŞLA"


func show_menu() -> void:
	state = "menu"
	menu.show()
	for c in play_ui:
		c.hide()
	marker.hide()
	refresh_menu()

