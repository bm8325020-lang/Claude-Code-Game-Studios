# PROTOTYPE - NOT FOR PRODUCTION
# The pause menu: character sheet (attributes, level up and respec at a bonfire), talent tree, equipment
# (reinforcement at a bonfire, bestiary of weaknesses), quest log and options. Built in code, big touch targets.
extends Control

const Rpg = preload("res://rpg.gd")
const HeroBody = preload("res://hero_body.gd")
const TABS := [["look", "APARÊNCIA"], ["status", "PERSONAGEM"], ["talents", "TALENTOS"], ["gear", "EQUIPAMENTO"], ["quests", "MISSÕES"], ["map", "MAPA"], ["options", "OPÇÕES"]]
const OPTIONS_PATH := "user://sementes_options.json"

var main: Node
var tab := "status"
var body: VBoxContainer
var tab_buttons := {}
var bg: ColorRect
var margin: MarginContainer
var options := {"shadows": true, "res": 0.7, "fps": 60, "show_fps": true, "sens": 1.0, "api_key": "", "ai_model": "claude-opus-5-5"}

func setup(m: Node) -> void:
	main = m
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	theme = Theme.new()
	theme.default_font_size = 34
	bg = ColorRect.new()
	bg.color = Color(0.02, 0.015, 0.015, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	col.add_child(bar)
	for t in TABS:
		var b := _button(t[1], func(): _show(t[0]))
		b.custom_minimum_size = Vector2(200, 90)
		bar.add_child(b)
		tab_buttons[t[0]] = b
	var close := _button("FECHAR", close_menu)
	close.custom_minimum_size = Vector2(200, 90)
	bar.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	_load_options()

func open(which := "status") -> void:
	visible = true
	main.get_tree().paused = true
	main.ui.visible = false
	main.on_pause_ui("menu")
	_show(which)

func close_menu() -> void:
	main.mirror(false)
	main.smith_open = false
	visible = false
	main.get_tree().paused = false
	main.ui.visible = true
	main.on_pause_ui("close")
	_save_options()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("menu"):
		close_menu()
		get_viewport().set_input_as_handled()

func _show(which: String) -> void:
	tab = which
	bg.color.a = 0.35 if tab == "look" else 0.9  # the mirror: see the hero while you dress them
	margin.add_theme_constant_override("margin_right", int(get_viewport_rect().size.x * 0.42) if tab == "look" else 40)
	main.mirror(tab == "look")
	for k in tab_buttons:
		tab_buttons[k].modulate = Color(1, 0.75, 0.4) if k == tab else Color.WHITE
	for c in body.get_children():
		c.queue_free()
	call("_tab_" + tab)

func _refresh() -> void:
	_show(tab)

# ------------------------------------------------------------------ helpers
func _button(text: String, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(0, 80)
	b.pressed.connect(cb)
	return b

func _label(text: String, size := 34, col := Color(0.92, 0.88, 0.8)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 20)
	body.add_child(r)
	return r

func _at_bonfire() -> bool:
	return main._near_bonfire(3.0) != null or main.smith_open

# ------------------------------------------------------------------ tabs
# make your hero: every piece and colour; the better ones unlock with your level (hero_body.gd LOCKS)
func _tab_look() -> void:
	body.add_child(_label("Seu herói  ·  peças e cores novas liberam com o nível", 34, Color(1, 0.75, 0.4)))
	var lk: Dictionary = HeroBody.DEFAULT.merged(main.look, true)
	var yes_no := [[false, "Não"], [true, "Sim"]]
	var styles := [["Peasant", "Camponês"], ["Ranger", "Patrulheiro"]]
	var idx := func(n: int, names: Array) -> Array:
		var out := []
		for i in n:
			out.append([i, names[i]])
		return out
	var hairs := []
	for i in HeroBody.HAIRS.size():
		hairs.append([HeroBody.HAIRS[i], HeroBody.HAIR_NAMES[i]])
	var rows := [["Corpo", "sex", [["Male", "Masculino"], ["Female", "Feminino"]]], ["Tronco", "body", styles], ["Braços", "arms", styles],
		["Pernas", "legs", styles], ["Pés", "feet", styles], ["Ombreira", "pauldron", yes_no], ["Capuz", "hood", yes_no],
		["Cabelo", "hair", hairs], ["Barba", "beard", yes_no],
		["Cor da roupa", "cloth", idx.call(HeroBody.CLOTH.size(), HeroBody.CLOTH_NAMES)], ["Pele", "skin", idx.call(HeroBody.SKIN.size(), HeroBody.SKIN_NAMES)],
		["Cor do cabelo", "hair_col", idx.call(HeroBody.HAIR_COL.size(), HeroBody.HAIR_COL_NAMES)]]
	for row in rows:
		var vals: Array = row[2]
		var cur := 0
		for i in vals.size():
			if vals[i][0] == lk[row[1]]:
				cur = i
		var r := _row()
		var l := _label(row[0], 32)
		l.custom_minimum_size = Vector2(250, 0)
		r.add_child(l)
		for step in [-1, 1]:
			var b := _button("◀" if step < 0 else "▶", func():
				var i: int = cur
				for k in vals.size():  # the next value you have unlocked
					i = posmod(i + step, vals.size())
					if HeroBody.level_needed(row[1], vals[i][0]) <= main.level:
						break
				main.look[row[1]] = vals[i][0]
				main._make_hero()
				main.mirror(true)
				_refresh())
			b.custom_minimum_size = Vector2(90, 76)
			if step < 0:
				r.add_child(b)
				var v := _label(vals[cur][1], 32, Color(1, 0.9, 0.6))
				v.custom_minimum_size = Vector2(240, 0)
				v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				r.add_child(v)
			else:
				r.add_child(b)
	var locked := []
	for lock in HeroBody.LOCKS:
		if lock[2] > main.level:
			locked.append("nível %d: %s" % [lock[2], {"pauldron": "ombreira", "hood": "capuz", "cloth": "roupa " + HeroBody.CLOTH_NAMES[lock[1]] if lock[1] is int else "", "hair_col": "cabelo " + HeroBody.HAIR_COL_NAMES[lock[1]] if lock[1] is int else ""}.get(lock[0], lock[0])])
	if not locked.is_empty():
		body.add_child(_label("A liberar: " + ", ".join(locked), 26, Color(0.75, 0.75, 0.75)))

func _tab_status() -> void:
	var cost := Rpg.level_cost(main.level)
	body.add_child(_label("%s  ·  Nível %d  ·  %d brasas  ·  %d titanita" % [Rpg.CLASSES[main.cls].name, main.level, main.embers, main.titanite], 40, Color(1, 0.75, 0.4)))
	if main.free_points > 0:
		body.add_child(_label("Pontos livres: %d (toque + para colocar)" % main.free_points, 32, Color(0.6, 1, 0.6)))
	elif _at_bonfire():
		body.add_child(_label("Próximo nível: %d brasas. Escolha onde colocar o ponto." % cost, 32, Color(1, 0.85, 0.6)))
	else:
		body.add_child(_label("Suba de nível descansando numa fogueira.", 30, Color(0.7, 0.7, 0.7)))
	for a in Rpg.ATTRS:
		var r := _row()
		var name := _label("%s  %d" % [Rpg.ATTR_NAME[a], main.attrs[a]], 38)
		name.custom_minimum_size = Vector2(380, 0)
		r.add_child(name)
		var can: bool = main.free_points > 0 or (_at_bonfire() and main.embers >= cost)
		var plus := _button("+", func():
			if main.free_points > 0:
				main._place_point(a)
			else:
				main._buy_attr(a)
			_refresh(), can)
		plus.custom_minimum_size = Vector2(100, 80)
		r.add_child(plus)
		var d := _label(Rpg.ATTR_DESC[a], 28, Color(0.7, 0.7, 0.7))
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(d)
	var st: Dictionary = main.stats
	body.add_child(_label("Vida %d   Estamina %d   Essência %d" % [main.max_hp, main.max_stamina, main.max_essence], 32))
	body.add_child(_label("Dano: espada %d%%   espadão %d%%   Sementes %d%%   ·   custo dos golpes %d%%" % [
		st.sword_mult * 100, st.great_mult * 100, main._seed_mult() * 100, st.stamina_cost * 100], 30))
	if _at_bonfire():
		var rc: int = main._respec_cost()
		body.add_child(_button("RENASCER: refazer atributos e talentos (%s)" % ("grátis" if rc == 0 else "%d brasas" % rc), func():
			main._respec()
			_refresh(), main.embers >= rc))

func _tab_talents() -> void:
	body.add_child(_label("Pontos de talento: %d   (1 a cada 2 níveis, +1 por sino e por chefe)" % main._talent_points_left(), 34, Color(1, 0.75, 0.4)))
	var r := _row()
	for br in Rpg.TALENTS:
		var colm := VBoxContainer.new()
		colm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		colm.add_theme_constant_override("separation", 10)
		r.add_child(colm)
		colm.add_child(_label(Rpg.BRANCH_NAME[br], 36, Color(1, 0.6, 0.3)))
		for t in Rpg.TALENTS[br]:
			var learnt: bool = main.talents.has(t.id)
			var ok: bool = Rpg.can_learn(t.id, main.talents) and main._talent_points_left() > 0
			var b := _button(("✔ " if learnt else "") + t.name + "\n" + t.desc, func():
				main._learn(t.id)
				_refresh(), ok)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.add_theme_font_size_override("font_size", 26)
			b.custom_minimum_size = Vector2(0, 150)
			if learnt:
				b.modulate = Color(0.6, 1, 0.6)
			colm.add_child(b)

func _tab_gear() -> void:
	var w: String = main.weapon
	var lv: int = main.upgrades[w]
	var wname := "Espada e escudo" if w == "sword" else "Espadão"
	body.add_child(_label("%s +%d   (dano x%.1f)" % [wname, lv, Rpg.upgrade_mult(lv)], 40, Color(1, 0.75, 0.4)))
	if lv < Rpg.MAX_UPGRADE:
		var c: Array = Rpg.upgrade_cost(lv)
		var can: bool = _at_bonfire() and main.titanite >= c[0] and main.embers >= c[1]
		body.add_child(_button("REFORÇAR para +%d: %d titanita + %d brasas%s" % [lv + 1, c[0], c[1], "" if _at_bonfire() else " (numa fogueira)"], func():
			main._reinforce()
			_refresh(), can))
	body.add_child(_label("Titanita: %d  (cai dos inimigos; as Sentinelas sempre deixam 2)" % main.titanite, 28, Color(0.7, 0.85, 1)))
	body.add_child(_label("Equipamento", 36, Color(1, 0.6, 0.3)))
	for slot in ["sword", "great", "ring", "amulet"]:
		if main.gear.has(slot):
			var it: Dictionary = main.gear[slot]
			body.add_child(_label("%s (%s)  %s" % [it.name, main.RARITY[it.rarity][0], main.ITEMS[slot].fmt % int(it.val)], 30, main.RARITY[it.rarity][1]))
	body.add_child(_label("Bestiário: fraquezas", 36, Color(1, 0.6, 0.3)))
	for k in Rpg.WEAK:
		var parts := []
		for el in Rpg.WEAK[k]:
			var m: float = Rpg.WEAK[k][el]
			parts.append("%s %s" % [{"fis": "físico", "fogo": "fogo", "gelo": "gelo", "raio": "raio"}[el], "fraco" if m > 1.0 else "resiste"])
		body.add_child(_label("%s: %s" % [Rpg.FOES[k].name, ", ".join(parts)], 28))

func _tab_quests() -> void:
	var q: Dictionary = Rpg.quests(main._quest_state())
	body.add_child(_label("Missão principal: o primeiro Sino", 38, Color(1, 0.75, 0.4)))
	for m in q.main:
		body.add_child(_label(("✔  " if m[1] else "•  ") + m[0], 32, Color(0.55, 0.85, 0.55) if m[1] else Color(0.95, 0.9, 0.8)))
	body.add_child(_label("Missões secundárias", 38, Color(1, 0.75, 0.4)))
	for m in q.side:
		body.add_child(_label(("✔  " if m[1] else "•  ") + m[0], 32, Color(0.55, 0.85, 0.55) if m[1] else Color(0.95, 0.9, 0.8)))
	body.add_child(_label("Inimigos derrotados: %d" % main.kills, 28, Color(0.7, 0.7, 0.7)))

# the 20 km world: biomes, roads, every town (named once found), lit bonfires and where you stand
func _tab_map() -> void:
	var w: Node = main.world
	body.add_child(_label("Cidades encontradas: %d de %d  ·  fogueiras acesas brilham em laranja" % [w.found.size(), w.towns.size()], 30, Color(1, 0.75, 0.4)))
	var map := Control.new()
	map.custom_minimum_size = Vector2(0, 760)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.draw.connect(func():
		var side := minf(map.size.x, 760.0)
		var o := Vector2((map.size.x - side) / 2.0, 0)
		var k: float = side / (w.HALF * 2.0)
		var to_map := func(p: Vector2) -> Vector2: return o + (p + Vector2(w.HALF, w.HALF)) * k
		map.draw_texture_rect(w.map_texture(), Rect2(o, Vector2(side, side)), false)
		map.draw_rect(Rect2(o, Vector2(side, side)), Color(0.5, 0.4, 0.3), false, 3.0)
		for rd in w.roads:
			map.draw_line(to_map.call(rd[0]), to_map.call(rd[1]), Color(0.55, 0.4, 0.25), 2.0)
		map.draw_circle(to_map.call(Vector2.ZERO), 10.0, Color(1, 0.55, 0.15))
		map.draw_string(ThemeDB.fallback_font, to_map.call(Vector2.ZERO) + Vector2(14, 6), "Santuário", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.8, 0.5))
		for t in w.towns:
			var p: Vector2 = to_map.call(t.pos)
			var known: bool = w.found.has(t.name) or main.lit.has(t.name)
			var col := Color(1, 0.55, 0.15) if main.lit.has(t.name) else (Color(1, 1, 1) if known else Color(0.25, 0.22, 0.2))
			map.draw_circle(p, 6.0 if t.city else 4.0, col)
			if known:  # 96 towns: only the ones you found get a name
				map.draw_string(ThemeDB.fallback_font, p + Vector2(9, 6), t.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
		var pp: Vector2 = to_map.call(Vector2(main.player.position.x, main.player.position.z))
		map.draw_circle(pp, 8.0, Color(0.9, 0.15, 0.1))
		map.draw_arc(pp, 14.0, 0, TAU, 20, Color(1, 1, 1), 2.0))
	body.add_child(map)

func _tab_options() -> void:
	body.add_child(_label("Se o jogo travar, desligue as sombras e baixe a resolução.", 30, Color(0.8, 0.8, 0.8)))
	_choice("Sombras", "shadows", [[true, "LIGADAS"], [false, "DESLIGADAS"]])
	_choice("Resolução 3D", "res", [[0.5, "50%"], [0.7, "70%"], [0.85, "85%"], [1.0, "100%"]])
	_choice("Limite de FPS", "fps", [[30, "30"], [60, "60"]])
	_choice("Mostrar FPS", "show_fps", [[true, "SIM"], [false, "NÃO"]])
	_choice("Sensibilidade da câmera", "sens", [[0.6, "BAIXA"], [1.0, "MÉDIA"], [1.5, "ALTA"]])
	body.add_child(_label("Conversa com IA: os NPCs respondem qualquer pergunta usando a API do Claude (Anthropic). Precisa de internet e da SUA chave de API (console.anthropic.com); cada conversa é cobrada na sua conta. A chave fica só neste aparelho.", 28, Color(0.8, 0.8, 0.8)))
	var r := _row()
	var key := LineEdit.new()
	key.secret = true
	key.placeholder_text = "sk-ant-..."
	key.text = options.api_key
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key.custom_minimum_size = Vector2(0, 80)
	key.text_changed.connect(func(t): options.api_key = t.strip_edges())
	r.add_child(_label("Chave da API", 34))
	r.add_child(key)
	_choice("Modelo da IA", "ai_model", [["claude-opus-5-5", "OPUS 5.5 (melhor)"], ["claude-haiku-5-5", "HAIKU 5.5 (mais barato)"]])

func _choice(title: String, key: String, values: Array) -> void:
	var r := _row()
	var l := _label(title, 34)
	l.custom_minimum_size = Vector2(460, 0)
	r.add_child(l)
	for v in values:
		var b := _button(v[1], func():
			options[key] = v[0]
			apply_options()
			_refresh())
		b.custom_minimum_size = Vector2(190, 80)
		if options[key] == v[0]:
			b.modulate = Color(1, 0.75, 0.4)
		r.add_child(b)

# ------------------------------------------------------------------ options
func apply_options() -> void:
	for l in main.find_children("*", "DirectionalLight3D", true, false):
		l.shadow_enabled = options.shadows
	main.get_viewport().scaling_3d_scale = options.res
	Engine.max_fps = options.fps

func _load_options() -> void:
	if FileAccess.file_exists(OPTIONS_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(OPTIONS_PATH))
		if d is Dictionary:
			for k in options:
				if d.has(k):
					options[k] = d[k]
	options.fps = int(options.fps)

func _save_options() -> void:
	var f := FileAccess.open(OPTIONS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(options))
