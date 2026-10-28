extends Control
## TileTales main screen, laid out like the web version (www/index.html): top bar, a board that fills the free space,
## a status line and a thumb-reach action bar. Settings and the picture gallery open as bottom sheets.
## Sizes are the web's CSS pixels × ~1.25, because the 480 px-wide viewport is drawn at about that scale on phones.

const Palette = preload("res://scripts/palette.gd")
const PuzzleBoard = preload("res://scripts/puzzle_board.gd")
const Ads = preload("res://scripts/ads.gd")

const SAVE_PATH := "user://tiletales_save.cfg"
const PHOTO_PATH := "user://custom_photo.png"
const IMAGE_DIR := "res://assets/images/"
const LEVELS := ["Beginner", "Intermediate", "Advanced"]
const TIER_SIZES := [3, 4, 6]
const THEME_MODES := ["System", "Light", "Dark"]
const CATALOG := {
	"Animals": [
		["Sunny Windowsill Cat and Garden", "sunny-windowsill-cat-and-garden.webp"],
		["Whimsical Fox in a Sunlit Forest", "whimsical-fox-in-a-sunlit-forest.webp"],
		["Tropical Reef Adventure", "tropical-reef-adventure.webp"],
	],
	"Food": [
		["Sunny Kitchen Fruit Bowl", "sunny-kitchen-fruit-bowl.webp"],
		["Whimsical Sunlit Bakery Café", "whimsical-sunlit-bakery-cafe.webp"],
		["Colourful European Farmers’ Market Stall", "colourful-european-farmers-market-stall.webp"],
	],
	"Space": [
		["Whimsical Earth, Moon and Stars", "whimsical-earth-moon-and-stars.webp"],
		["Chibi Astronaut on the Moon", "chibi-astronaut-on-the-moon.webp"],
		["Vibrant Alien Waterfall Valley", "vibrant-alien-waterfall-valley.webp"],
	],
	"Architecture": [
		["Sunny Countryside Cottage Garden", "sunny-countryside-cottage-garden.webp"],
		["Sunny Mediterranean Café Street", "sunny-mediterranean-cafe-street.webp"],
		["Sunlit Mediterranean Market Square", "sunlit-mediterranean-market-square.webp"],
	],
	"Nature": [
		["Sunflower in a Sunny Garden", "sunflower-in-a-sunny-garden.webp"],
		["Enchanting Cottage Garden by the Lake", "enchanting-cottage-garden-by-the-lake.webp"],
		["Tropical Waterfall Paradise with Colourful Birds", "tropical-waterfall-paradise-with-colourful-birds.webp"],
	],
	"Transportation": [
		["Red Bicycle in a Sunny Village Garden", "red-bicycle-in-a-sunny-village-garden.webp"],
		["Steam Train Over the Mountain Bridge", "steam-train-over-the-mountain-bridge.webp"],
		["Bustling Mediterranean Harbor Town", "bustling-mediterranean-harbor-town.webp"],
	],
	"Fantasy": [
		["Cheerful Dragon in a Mountain Meadow", "cheerful-dragon-in-a-mountain-meadow.webp"],
		["Enchanted Alchemist’s Mountain Workshop", "enchanted-alchemist-s-mountain-workshop.webp"],
		["Dragonlit Castle Courtyard", "dragonlit-castle-courtyard.webp"],
	],
	"Animal Adventures": [
		["Whimsical Fox Meadow Fairytale", "Whimsical Fox Meadow Fairytale.webp"],
		["Whimsical Woodland Picnic with a Hidden Wolf", "Whimsical Woodland Picnic with a Hidden Wolf.webp"],
		["Woodland Lantern Concert", "Woodland Lantern Concert.webp"],
	],
	"Cozy Kitchens": [
		["Pancakes and Birds by the Cottage Window", "Pancakes and Birds by the Cottage Window.webp"],
		["Enchanted Bakery and Tiny Cobblers", "Enchanted Bakery and Tiny Cobblers.webp"],
		["Wholesome Mouse Chefs’ Cottage Kitchen", "Wholesome Mouse Chefs’ Cottage Kitchen.webp"],
	],
	"Space Stories": [
		["Chibi Moon Friends Under Earthlight", "Chibi Moon Friends Under Earthlight.webp"],
		["Curious Robot in an Alien Valley", "Curious Robot in an Alien Valley.webp"],
		["Stardust Garden Observatory at Night", "Stardust Garden Observatory at Night.webp"],
	],
	"Storybook Places": [
		["Whimsical Rapunzel Cottage by the Lake", "Whimsical Rapunzel Cottage by the Lake.webp"],
		["Sunny Storybook Village Street", "Sunny Storybook Village Street.webp"],
		["Twilight Fairytale Village Square", "Twilight Fairytale Village Square.webp"],
	],
	"Gardens & Nature": [
		["Golden Goose Through the Sunflower Garden", "Golden Goose Through the Sunflower Garden.webp"],
		["Enchanted Garden Princess Reflections", "Enchanted Garden Princess Reflections.webp"],
		["Enchanted Waterfall Forest Valley", "Enchanted Waterfall Forest Valley.webp"],
	],
	"Journeys & Vehicles": [
		["Cheerful Bicycle Ride Through the Countryside", "Cheerful Bicycle Ride Through the Countryside.webp"],
		["Whimsical Valley Steam Train", "Whimsical Valley Steam Train.webp"],
		["Golden Fish at the Storybook Harbour", "Golden Fish at the Storybook Harbour.webp"],
	],
	"Fantasy Worlds": [
		["Baby Dragon and Golden Bird Adventure", "Baby Dragon and Golden Bird Adventure.webp"],
		["The Alchemist’s Cozy Starlit Workshop", "The Alchemist’s Cozy Starlit Workshop.webp"],
		["Sunlit Castle Courtyard with Sleeping Princess and Dragons", "Sunlit Castle Courtyard with Sleeping Princess and Dragons.webp"],
	],
}
const COLLECTIONS := [
	["Original Collection", ["Animals", "Food", "Space", "Architecture", "Nature", "Transportation", "Fantasy"]],
	["Fairy-Tale Collection", ["Animal Adventures", "Cozy Kitchens", "Space Stories", "Storybook Places", "Gardens & Nature", "Journeys & Vehicles", "Fantasy Worlds"]],
]
const LOCKED_SHADER := """
shader_type canvas_item;
void fragment() {
	vec4 col = textureLod(TEXTURE, UV, 4.5);
	float g = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(col.rgb, vec3(g), 0.7) * 0.75, col.a);
}
"""

# Game state (same model as the web version).
var n := 3
var image_id := "Animals-0"
var image_label := ""
var image_tier := 0
var unlocked_tier := 0
var just_unlocked := false
var sound_enabled := true
var haptics_enabled := true
var theme_mode := 0  # Index into THEME_MODES.
var system_dark := false
var elapsed_before := 0
var started_at := 0
var running := false
var pending_action := Callable()
var active_category := "Animals"
var texture: Texture2D

var ads: Node

# UI
var ui_root: Control
var banner_slot: Control
var privacy_row: Control
var unlock: Overlay
var unlock_title: Label
var unlock_status: Label
var unlock_target := []
var board: Control
var image_title: Label
var level_chip: Label
var hint: Label
var shuffle_label: Label
var peek_button: Button
var margin: MarginContainer
var settings: Overlay
var gallery: Overlay
var preview: Overlay
var win: Overlay
var confirm: Overlay
var size_section: Control
var size_buttons := {}
var theme_buttons := {}
var switches := {}
var chip_buttons := {}
var gallery_grid: GridContainer
var preview_image: RoundedImage
var win_image: RoundedImage
var win_sub: Label
var win_moves: Label
var win_time: Label
var win_unlock: PanelContainer
var next_button: Button
var photo_picker: FileDialog
var locked_material: ShaderMaterial
var stack: Array[Overlay] = []
var save_timer := 0.0

# Sound
var move_sounds: Array[AudioStreamWAV] = []
var complete_sound: AudioStreamWAV
var players: Array[AudioStreamPlayer] = []
var next_player := 0

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		theme_mode = clampi(int(cfg.get_value("game", "theme", 0)), 0, THEME_MODES.size() - 1)
	_apply_palette()
	var t := Theme.new()
	t.default_font = Palette.font(400)
	t.default_font_size = 18
	theme = t
	locked_material = ShaderMaterial.new()
	locked_material.shader = Shader.new()
	locked_material.shader.code = LOCKED_SHADER
	_make_sounds()
	ads = Ads.new()
	add_child(ads)
	ads.banner_changed.connect(_apply_safe_area)
	ads.rewarded_finished.connect(_on_rewarded_finished)
	ads.privacy_changed.connect(func(): privacy_row.visible = ads.privacy_options_required)
	_build_ui()
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	if not _restore():
		_select_picture("Animals", 0)
	_update_switches()
	ads.start()

# --- Theme: System follows the device; Light and Dark are fixed ---

func _device_dark() -> bool:
	return DisplayServer.is_dark_mode_supported() and DisplayServer.is_dark_mode()

func _apply_palette() -> void:
	system_dark = _device_dark()
	Palette.use_dark(system_dark if theme_mode == 0 else theme_mode == 2)
	RenderingServer.set_default_clear_color(Palette.c.bg)

func _set_theme_mode(mode: int) -> void:
	if mode == theme_mode:
		return
	theme_mode = mode
	_rebuild_ui(true)

## Colours are baked into the UI when it's built, so a theme change saves the game and rebuilds the UI around it.
func _rebuild_ui(keep_settings_open: bool = false) -> void:
	_save()
	_apply_palette()
	stack.clear()
	ads.set_banner_visible(true)
	switches.clear()
	size_buttons.clear()
	theme_buttons.clear()
	chip_buttons.clear()
	remove_child(ui_root)
	ui_root.queue_free()
	_build_ui()
	_apply_safe_area()
	if not _restore():
		_select_picture("Animals", 0)
	_update_switches()
	if keep_settings_open:
		_open(settings)
		settings.tween.custom_step(1.0)

# --- Game flow ---

func _select_picture(category: String, index: int) -> void:
	image_id = "%s-%d" % [category, index]
	image_label = CATALOG[category][index][0]
	image_tier = index
	n = TIER_SIZES[index]
	active_category = category
	_new_game()

func _new_game() -> void:
	texture = _load_texture()
	board.setup(texture, n)
	_reset_clock()
	_update_size_buttons()
	_render()
	_save()

func _shuffle() -> void:
	board.shuffle()
	_reset_clock()
	_render()
	_save()

func _reset_clock() -> void:
	elapsed_before = 0
	running = false
	just_unlocked = false
	board.time_text = "0:00"

func _load_texture() -> Texture2D:
	if image_id == "custom" and FileAccess.file_exists(PHOTO_PATH):
		var img := Image.load_from_file(PHOTO_PATH)
		if img and not img.is_empty():
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
	if image_id == "custom" or _entry(image_id).is_empty():
		image_id = "Animals-0"
		image_tier = 0
		n = 3
	image_label = _entry(image_id)[0]
	return load(IMAGE_DIR + _entry(image_id)[1]) as Texture2D

func _entry(id: String) -> Array:
	var cut := id.rfind("-")
	if cut < 0:
		return []
	var category := id.substr(0, cut)
	var index := int(id.substr(cut + 1))
	if not CATALOG.has(category) or index < 0 or index >= CATALOG[category].size():
		return []
	return CATALOG[category][index]

func _current_category() -> String:
	return CATALOG.keys()[0] if image_id == "custom" else image_id.substr(0, image_id.rfind("-"))

func _elapsed_ms() -> int:
	return elapsed_before + (Time.get_ticks_msec() - started_at if running else 0)

func _format_time(ms: int) -> String:
	var s := ms / 1000
	return "%d:%02d" % [s / 60, s % 60]

func _has_progress() -> bool:
	return board.move_count > 0 and not board.is_solved

func _request_new_game(action: Callable) -> void:
	if not _has_progress():
		action.call()
		return
	pending_action = action
	_open(confirm)

func _on_moved() -> void:
	if not running and not board.is_solved:
		running = true
		started_at = Time.get_ticks_msec()
	if not board.is_solved:
		_play(move_sounds[board.move_count % 4])
		_buzz(12)
	_render()
	_save()

func _on_solved() -> void:
	elapsed_before = _elapsed_ms()
	running = false
	_play(complete_sound)
	_buzz(120)
	just_unlocked = image_id != "custom" and image_tier == unlocked_tier and unlocked_tier < LEVELS.size() - 1
	if just_unlocked:
		unlocked_tier += 1
	_render()
	_save()
	get_tree().create_timer(0.65).timeout.connect(_show_win)

func _next_target() -> Array:
	var categories := CATALOG.keys()
	if just_unlocked:
		return [_current_category(), unlocked_tier]
	if image_id == "custom":
		return [categories[0], unlocked_tier]
	return [categories[(categories.find(_current_category()) + 1) % categories.size()], mini(image_tier, unlocked_tier)]

func _show_win() -> void:
	if not board.is_solved or not stack.is_empty():
		return
	win_image.texture = texture
	win_sub.text = "Photo puzzle complete" if image_id == "custom" else "%s complete" % LEVELS[image_tier]
	win_moves.text = str(board.move_count)
	win_time.text = _format_time(elapsed_before)
	win_unlock.visible = just_unlocked
	if just_unlocked:
		(win_unlock.get_child(0) as Label).text = "%s pictures unlocked!" % LEVELS[unlocked_tier]
	next_button.text = "Next level" if just_unlocked else "Next picture"
	_open(win)

func _render() -> void:
	image_title.text = image_label
	level_chip.text = ("%s · %d×%d" % ["Your photo" if image_id == "custom" else LEVELS[image_tier], n, n]).to_upper()
	board.time_text = _format_time(_elapsed_ms())
	board.queue_redraw()
	var solved: bool = board.is_solved
	hint.add_theme_color_override("font_color", Palette.c.win if solved else Palette.c.muted)
	hint.add_theme_font_override("font", Palette.font(800 if solved else 400))
	if solved:
		hint.text = "Solved in %d moves · %s" % [board.move_count, _format_time(elapsed_before)]
	elif board.move_count == 0:
		hint.text = "Tap or swipe a piece next to the empty space"
	else:
		hint.text = ""
	shuffle_label.text = "New game" if solved else "Shuffle"

func _process(delta: float) -> void:
	if not running:
		return
	board.time_text = _format_time(_elapsed_ms())
	save_timer += delta
	if save_timer > 5.0:
		save_timer = 0.0
		_save()

# --- Save and restore ---

func _save() -> void:
	var state: Dictionary = board.get_state()
	var cfg := ConfigFile.new()
	cfg.set_value("game", "n", n)
	cfg.set_value("game", "pieces", state.pieces)
	cfg.set_value("game", "moves", state.moves)
	cfg.set_value("game", "elapsed", _elapsed_ms())
	cfg.set_value("game", "solved", state.solved)
	cfg.set_value("game", "image_id", image_id)
	cfg.set_value("game", "image_label", image_label)
	cfg.set_value("game", "image_tier", image_tier)
	cfg.set_value("game", "unlocked_tier", unlocked_tier)
	cfg.set_value("game", "show_numbers", board.show_numbers)
	cfg.set_value("game", "sound", sound_enabled)
	cfg.set_value("game", "haptics", haptics_enabled)
	cfg.set_value("game", "theme", theme_mode)
	cfg.save(SAVE_PATH)

func _restore() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	var saved_n := int(cfg.get_value("game", "n", 0))
	var pieces: Variant = cfg.get_value("game", "pieces", [])
	if not saved_n in [3, 4, 5, 6] or not pieces is Array or pieces.size() != saved_n * saved_n + 1:
		return false
	n = saved_n
	image_id = str(cfg.get_value("game", "image_id", "Animals-0"))
	image_tier = clampi(int(cfg.get_value("game", "image_tier", 0)), 0, 2)
	unlocked_tier = clampi(int(cfg.get_value("game", "unlocked_tier", 0)), 0, 2)
	sound_enabled = bool(cfg.get_value("game", "sound", true))
	haptics_enabled = bool(cfg.get_value("game", "haptics", true))
	board.show_numbers = bool(cfg.get_value("game", "show_numbers", false))
	if image_id != "custom" and _entry(image_id).is_empty():
		return false
	image_label = str(cfg.get_value("game", "image_label", "Your photo")) if image_id == "custom" else _entry(image_id)[0]
	if image_id != "custom":
		active_category = _current_category()
		if n != TIER_SIZES[image_tier]:
			# The picture's level now uses a different grid; start it fresh.
			n = TIER_SIZES[image_tier]
			_new_game()
			return true
	texture = _load_texture()
	board.setup(texture, n, pieces, int(cfg.get_value("game", "moves", 0)), bool(cfg.get_value("game", "solved", false)))
	var kept := true
	for i in pieces.size():
		kept = kept and board.pieces[i] == int(pieces[i])
	if not kept:
		_reset_clock()  # Saved pieces were invalid and the board reshuffled.
	else:
		elapsed_before = maxi(0, int(cfg.get_value("game", "elapsed", 0)))
		running = board.move_count > 0 and not board.is_solved
		started_at = Time.get_ticks_msec()
	_update_size_buttons()
	_render()
	return true

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if stack.is_empty():
				get_tree().quit()
			else:
				_close_top()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			if is_instance_valid(board):
				_save()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			if theme_mode == 0 and is_instance_valid(ui_root) and _device_dark() != system_dark:
				_rebuild_ui(settings in stack)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not stack.is_empty():
		_close_top()
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if not stack.is_empty() or key == null or not key.pressed:
		return
	var moves := {KEY_UP: Vector2i(1, 0), KEY_DOWN: Vector2i(-1, 0), KEY_LEFT: Vector2i(0, 1), KEY_RIGHT: Vector2i(0, -1)}
	if moves.has(key.keycode):
		board.key_move(moves[key.keycode].x, moves[key.keycode].y)
		get_viewport().set_input_as_handled()

# --- Feedback ---

func _buzz(ms: int) -> void:
	if haptics_enabled:
		Input.vibrate_handheld(ms)

func _play(stream: AudioStream) -> void:
	if not sound_enabled or players.is_empty():
		return
	var player := players[next_player % players.size()]
	next_player += 1
	player.stream = stream
	player.play()

func _make_sounds() -> void:
	for freq in [440.0, 523.25, 493.88, 587.33]:
		move_sounds.append(_synth([[freq, 0.0, 0.055, 0.11, true]]))
	var notes := []
	for i in 4:
		notes.append([[523.25, 659.25, 783.99, 1046.5][i], i * 0.105, 0.2, 0.2, false])
	complete_sound = _synth(notes)
	for i in 3:
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)

## Bakes short tones like the web's oscillators: [frequency, delay, duration, volume, triangle?].
func _synth(notes: Array) -> AudioStreamWAV:
	var rate := 22050
	var total := 0.0
	for note in notes:
		total = maxf(total, note[1] + note[2] + 0.02)
	var count := int(total * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var sample := 0.0
		for note in notes:
			var local: float = t - note[1]
			if local < 0.0 or local > note[2]:
				continue
			var volume: float = note[3]
			var env := volume * local / 0.012 if local < 0.012 else volume * pow(0.0001 / volume, (local - 0.012) / (note[2] - 0.012))
			var phase := fmod(local * note[0], 1.0)
			var wave := 4.0 * absf(phase - 0.5) - 1.0 if note[4] else sin(TAU * phase)
			sample += wave * env
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav

# --- Photo picker ---

func _on_photo_selected(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		hint.text = "That file couldn't be read as an image. Try a JPG or PNG."
		return
	var side := mini(img.get_width(), img.get_height())
	img = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
	if side > 768:
		img.resize(768, 768, Image.INTERPOLATE_LANCZOS)
	var label := path.get_file().get_basename().left(60)
	_request_new_game(func():
		img.save_png(PHOTO_PATH)
		image_id = "custom"
		image_label = label if not label.is_empty() else "Your photo"
		_new_game()
		size_section.visible = true
		_close(gallery))

# --- UI construction ---

func _build_ui() -> void:
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ui_root.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(ui_root)
	var bg := ColorRect.new()
	bg.color = Palette.c.bg
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	ui_root.add_child(bg)
	# Soft accent glow at the top, like the web's radial-gradient background.
	var glow := TextureRect.new()
	var gradient := GradientTexture2D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.set_color(0, Color(Palette.c.accent, 0.13))
	gradient.gradient.set_color(1, Color(Palette.c.accent, 0.0))
	gradient.fill = GradientTexture2D.FILL_RADIAL
	gradient.fill_from = Vector2(0.5, -0.08)
	gradient.fill_to = Vector2(0.5, 0.5)
	glow.texture = gradient
	glow.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	glow.mouse_filter = MOUSE_FILTER_IGNORE
	ui_root.add_child(glow)

	margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ui_root.add_child(margin)
	banner_slot = _build_banner_slot()
	ui_root.add_child(banner_slot)
	var app := VBoxContainer.new()
	app.add_theme_constant_override("separation", 8)
	margin.add_child(app)

	# Top bar: brand mark, picture title + level chip, settings.
	var top := HBoxContainer.new()
	top.custom_minimum_size.y = 65
	top.add_theme_constant_override("separation", 15)
	app.add_child(top)
	var brand := RoundedImage.new()
	brand.texture = load("res://icon.webp")
	brand.radii = [16, 16, 16, 16]
	brand.custom_minimum_size = Vector2(52, 52)
	brand.size_flags_vertical = SIZE_SHRINK_CENTER
	brand.shadow = Color(0.031, 0.498, 0.404, 0.25)
	brand.shadow_size = 10
	brand.shadow_offset = Vector2(0, 5)
	top.add_child(brand)
	var title_block := VBoxContainer.new()
	title_block.size_flags_horizontal = SIZE_EXPAND_FILL
	title_block.alignment = BoxContainer.ALIGNMENT_CENTER
	title_block.add_theme_constant_override("separation", 5)
	top.add_child(title_block)
	image_title = _label("", 21, 800)
	image_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	image_title.clip_text = true
	title_block.add_child(image_title)
	var chip := _pill(Palette.mix(Palette.c.accent, Color(Palette.c.bg, 0.0), 0.13), 999, Vector2(11, 3))
	chip.size_flags_horizontal = SIZE_SHRINK_BEGIN
	level_chip = _label("", 13, 800, Palette.c.accent)
	chip.add_child(level_chip)
	title_block.add_child(chip)
	var menu := _icon_button("sliders", 58, 17)
	menu.pressed.connect(func(): _open(settings))
	top.add_child(menu)

	# Board.
	var stage := MarginContainer.new()
	stage.size_flags_vertical = SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		stage.add_theme_constant_override("margin_" + side, 2)
	for side in ["top", "bottom"]:
		stage.add_theme_constant_override("margin_" + side, 6)
	app.add_child(stage)
	board = PuzzleBoard.new()
	stage.add_child(board)
	board.moved.connect(_on_moved)
	board.solved.connect(_on_solved)
	board.rejected.connect(func(): _buzz(25))
	board.thumb_pressed.connect(func(): _open(preview))

	hint = _label("", 17, 400, Palette.c.muted)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.y = 26
	app.add_child(hint)

	# Action bar.
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	app.add_child(actions)
	var pictures := _action_button("image", "Pictures", false)
	pictures.pressed.connect(_open_gallery)
	actions.add_child(pictures)
	var shuffle := _action_button("shuffle", "Shuffle", true)
	shuffle.size_flags_stretch_ratio = 1.3
	shuffle_label = shuffle.get_meta("label")
	shuffle.pressed.connect(func(): _request_new_game(_shuffle))
	actions.add_child(shuffle)
	peek_button = _action_button("eye", "Peek", false)
	peek_button.button_down.connect(_set_peek.bind(true))
	peek_button.button_up.connect(_set_peek.bind(false))
	actions.add_child(peek_button)

	_build_settings()
	_build_gallery()
	_build_preview()
	_build_win()
	_build_confirm()
	_build_unlock()

	photo_picker = FileDialog.new()
	photo_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	photo_picker.access = FileDialog.ACCESS_FILESYSTEM
	photo_picker.use_native_dialog = true
	photo_picker.title = "Choose a photo"
	photo_picker.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	photo_picker.file_selected.connect(_on_photo_selected)
	ui_root.add_child(photo_picker)

func _set_peek(on: bool) -> void:
	board.set_peek(on)
	var color: Color = Palette.c.accent if on else Palette.c.fg
	peek_button.add_theme_stylebox_override("pressed", _action_style(false, on))
	peek_button.add_theme_stylebox_override("normal", _action_style(false, on))
	(peek_button.get_meta("label") as Label).add_theme_color_override("font_color", color)
	(peek_button.get_meta("icon") as Icon).color = color

func _apply_safe_area() -> void:
	var top := 0.0
	var bottom := 0.0
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		if screen.y > 0:
			var ratio := get_viewport_rect().size.y / float(screen.y)
			top = safe.position.y * ratio
			bottom = (screen.y - safe.end.y) * ratio
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", int(maxf(12.0, top)))
	# The banner sits at the very bottom, with a clear gap above it so the action buttons aren't tapped by mistake.
	var banner: float = ads.banner_height
	banner_slot.visible = banner > 0.0
	banner_slot.offset_top = -(bottom + banner)
	banner_slot.offset_bottom = -bottom
	margin.add_theme_constant_override("margin_bottom", int(bottom + banner + 16.0) if banner > 0.0 else int(maxf(15.0, bottom)))

func _build_settings() -> void:
	settings = _make_overlay("Settings", true)
	var c: VBoxContainer = settings.content
	size_section = VBoxContainer.new()
	size_section.add_theme_constant_override("separation", 0)
	size_section.visible = image_id == "custom"
	c.add_child(size_section)
	size_section.add_child(_section_label("Photo grid size"))
	var seg := _pill(Palette.c.panel, 15, Vector2(4, 4), Palette.c.line)
	size_section.add_child(seg)
	var seg_row := HBoxContainer.new()
	seg_row.add_theme_constant_override("separation", 4)
	seg.add_child(seg_row)
	for size_n in [3, 4, 5, 6]:
		var b := Button.new()
		b.text = "%d×%d" % [size_n, size_n]
		b.custom_minimum_size.y = 52
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.add_theme_font_override("font", Palette.font(700, true))
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(func(): _request_new_game(func():
			n = size_n
			_new_game()))
		seg_row.add_child(b)
		size_buttons[size_n] = b
	size_section.add_child(_spacer(20))

	c.add_child(_section_label("Appearance"))
	var theme_seg := _pill(Palette.c.panel, 15, Vector2(4, 4), Palette.c.line)
	c.add_child(theme_seg)
	var theme_row := HBoxContainer.new()
	theme_row.add_theme_constant_override("separation", 4)
	theme_seg.add_child(theme_row)
	for mode in THEME_MODES.size():
		var b := Button.new()
		b.text = THEME_MODES[mode]
		b.custom_minimum_size.y = 52
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.add_theme_font_override("font", Palette.font(700))
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(_set_theme_mode.bind(mode))
		theme_row.add_child(b)
		theme_buttons[mode] = b
	_update_seg(theme_buttons, theme_mode)
	c.add_child(_spacer(20))

	c.add_child(_section_label("Play"))
	var list := _pill(Palette.c.panel, 20, Vector2.ZERO, Palette.c.line)
	c.add_child(list)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	list.add_child(rows)
	var specs := [["nums", "Show numbers", "Label each piece with its home position"], ["sound", "Sound effects", ""],
		["haptics", "Vibration", "Light buzz on moves, where supported"]]
	for i in specs.size():
		if i > 0:
			var line := ColorRect.new()
			line.color = Palette.c.line
			line.custom_minimum_size.y = 1
			line.mouse_filter = MOUSE_FILTER_IGNORE
			rows.add_child(line)
		rows.add_child(_switch_row(specs[i][0], specs[i][1], specs[i][2]))
	c.add_child(_spacer(20))
	# Shown only where the law requires a way to change ad consent (e.g. EEA and UK).
	privacy_row = VBoxContainer.new()
	privacy_row.visible = ads.privacy_options_required
	c.add_child(privacy_row)
	var privacy_pair := _button_row("Privacy choices", "")
	var privacy := privacy_pair.get_child(0) as Button
	privacy_pair.remove_child(privacy)
	privacy_pair.free()  # Only the first button is needed.
	privacy.pressed.connect(ads.show_privacy_options)
	privacy_row.add_child(privacy)
	privacy_row.add_child(_spacer(20))
	var note := _label("Progress is saved on this device. Built-in pictures set their own grid size; your photos can use any size.", 16, 400, Palette.c.muted)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(note)

func _switch_row(key: String, title: String, subtitle: String) -> Button:
	var row := Button.new()
	row.custom_minimum_size.y = 74
	_style_button(row, StyleBoxEmpty.new(), Palette.box(Palette.mix(Palette.c.fg, Palette.c.panel, 0.05), 0))
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	pad.mouse_filter = MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 20)
	row.add_child(pad)
	var line := HBoxContainer.new()
	line.mouse_filter = MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 17)
	pad.add_child(line)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	text.mouse_filter = MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 2)
	line.add_child(text)
	text.add_child(_label(title, 18, 600))
	if not subtitle.is_empty():
		var sub := _label(subtitle, 15, 400, Palette.c.muted)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(sub)
	var sw := Switch.new()
	line.add_child(sw)
	switches[key] = sw
	row.pressed.connect(_toggle.bind(key))
	return row

func _toggle(key: String) -> void:
	match key:
		"nums":
			board.show_numbers = not board.show_numbers
		"sound":
			sound_enabled = not sound_enabled
		"haptics":
			haptics_enabled = not haptics_enabled
			_buzz(15)
	_update_switches(true)
	_save()

func _update_switches(animate: bool = false) -> void:
	switches.nums.set_on(board.show_numbers, animate)
	switches.sound.set_on(sound_enabled, animate)
	switches.haptics.set_on(haptics_enabled, animate)

func _update_size_buttons() -> void:
	size_section.visible = image_id == "custom"
	_update_seg(size_buttons, n)

## Highlights the selected button of a segmented control, like the web's .seg.
func _update_seg(buttons: Dictionary, selected: int) -> void:
	for key in buttons:
		var on: bool = key == selected
		var b: Button = buttons[key]
		_style_button(b, Palette.box(Palette.c.accent if on else Color.TRANSPARENT, 11))
		_font_colors(b, Palette.c.accent_ink if on else Palette.c.fg)

func _build_gallery() -> void:
	gallery = _make_overlay("Choose a picture", true)
	var c: VBoxContainer = gallery.content
	var photo := Button.new()
	photo.custom_minimum_size.y = 76
	var photo_style := Palette.box(Palette.mix(Palette.c.accent, Palette.c.panel, 0.07), 20, Palette.mix(Palette.c.accent, Palette.c.line, 0.55), 2)
	_style_button(photo, photo_style, Palette.box(Palette.mix(Palette.c.accent, Palette.c.panel, 0.14), 20, Palette.mix(Palette.c.accent, Palette.c.line, 0.55), 2))
	var photo_pad := MarginContainer.new()
	photo_pad.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	photo_pad.mouse_filter = MOUSE_FILTER_IGNORE
	photo_pad.add_theme_constant_override("margin_left", 18)
	photo.add_child(photo_pad)
	var photo_row := HBoxContainer.new()
	photo_row.mouse_filter = MOUSE_FILTER_IGNORE
	photo_row.add_theme_constant_override("separation", 15)
	photo_pad.add_child(photo_row)
	var cam := Icon.new("camera", 28, Palette.c.accent)
	cam.size_flags_vertical = SIZE_SHRINK_CENTER
	photo_row.add_child(cam)
	var photo_text := VBoxContainer.new()
	photo_text.alignment = BoxContainer.ALIGNMENT_CENTER
	photo_text.mouse_filter = MOUSE_FILTER_IGNORE
	photo_text.add_theme_constant_override("separation", 1)
	photo_row.add_child(photo_text)
	photo_text.add_child(_label("Use my own photo", 18, 700))
	photo_text.add_child(_label("Stays on this device, never uploaded", 15, 400, Palette.c.muted))
	photo.pressed.connect(func(): photo_picker.popup_file_dialog() if photo_picker.has_method("popup_file_dialog") else photo_picker.popup_centered_ratio(0.85))
	c.add_child(photo)
	c.add_child(_spacer(18))

	for collection in COLLECTIONS:
		c.add_child(_section_label(collection[0], 13))
		var scroll := ScrollContainer.new()
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		scroll.custom_minimum_size.y = 52
		c.add_child(scroll)
		var chips := HBoxContainer.new()
		chips.add_theme_constant_override("separation", 10)
		scroll.add_child(chips)
		for category in collection[1]:
			var chip := Button.new()
			chip.text = category
			chip.custom_minimum_size.y = 48
			chip.add_theme_font_override("font", Palette.font(600))
			chip.add_theme_font_size_override("font_size", 17)
			chip.pressed.connect(_show_category.bind(category))
			chips.add_child(chip)
			chip_buttons[category] = chip
		c.add_child(_spacer(16))

	gallery_grid = GridContainer.new()
	gallery_grid.columns = 2
	gallery_grid.add_theme_constant_override("h_separation", 14)
	gallery_grid.add_theme_constant_override("v_separation", 14)
	c.add_child(gallery_grid)
	c.add_child(_spacer(18))
	var credit := _label("Solve a puzzle to unlock the next level in every category. Pictures work offline.", 16, 400, Palette.c.muted)
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(credit)

func _open_gallery() -> void:
	_show_category(active_category)
	_open(gallery)

func _show_category(category: String) -> void:
	active_category = category
	for chip_category in chip_buttons:
		var on: bool = chip_category == category
		var chip: Button = chip_buttons[chip_category]
		var style := Palette.box(Palette.c.accent if on else Palette.c.panel, 24, Palette.c.accent if on else Palette.c.line, 1)
		style.content_margin_left = 18
		style.content_margin_right = 18
		_style_button(chip, style)
		_font_colors(chip, Palette.c.accent_ink if on else Palette.c.fg)
		if on:
			var scroll := chip.get_parent().get_parent() as ScrollContainer
			scroll.ensure_control_visible.call_deferred(chip)
	for child in gallery_grid.get_children():
		child.queue_free()
	for i in CATALOG[category].size():
		gallery_grid.add_child(_gallery_card(category, i))

func _gallery_card(category: String, index: int) -> Button:
	var item: Array = CATALOG[category][index]
	var locked := index > unlocked_tier
	var can_watch := index == unlocked_tier + 1  # The next level can be unlocked now with a rewarded ad.
	var current := image_id == "%s-%d" % [category, index]
	var card := Button.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.disabled = locked and not can_watch
	card.clip_contents = true
	var style := Palette.box(Palette.c.panel, 17, Palette.c.accent if current else Palette.c.line, 3 if current else 1)
	Palette.shadow(style, Color(0.09, 0.208, 0.18, 0.05), 6, Vector2(0, 3))
	_style_button(card, style)
	var image := RoundedImage.new()
	image.texture = load(IMAGE_DIR + item[1])
	image.radii = [16, 16, 0, 0]
	if locked:
		image.material = locked_material
	card.add_child(image)
	var tier := _pill(Color(0, 0, 0, 0.62), 9, Vector2(9, 4))
	tier.mouse_filter = MOUSE_FILTER_IGNORE
	tier.position = Vector2(9, 9)
	tier.add_child(_label(("%s · %d×%d" % [LEVELS[index], TIER_SIZES[index], TIER_SIZES[index]]).to_upper(), 12, 800, Color.WHITE))
	card.add_child(tier)
	var caption := _label(item[0], 16, 700)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.max_lines_visible = 2
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(caption)
	var lock: VBoxContainer
	if locked:
		lock = VBoxContainer.new()
		lock.alignment = BoxContainer.ALIGNMENT_CENTER
		lock.mouse_filter = MOUSE_FILTER_IGNORE
		lock.add_theme_constant_override("separation", 5)
		var lock_icon := Icon.new("lock", 27, Color.WHITE)
		lock_icon.size_flags_horizontal = SIZE_SHRINK_CENTER
		lock.add_child(lock_icon)
		var lock_text := _label("Solve %s to unlock" % LEVELS[index - 1], 15, 700, Color.WHITE)
		lock_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
		lock_text.add_theme_constant_override("shadow_offset_y", 1)
		lock.add_child(lock_text)
		if can_watch:
			var watch := _pill(Palette.c.accent, 99, Vector2(12, 5))
			watch.size_flags_horizontal = SIZE_SHRINK_CENTER
			watch.mouse_filter = MOUSE_FILTER_IGNORE
			var watch_row := HBoxContainer.new()
			watch_row.add_theme_constant_override("separation", 5)
			watch_row.mouse_filter = MOUSE_FILTER_IGNORE
			watch.add_child(watch_row)
			var play := Icon.new("play", 16, Palette.c.accent_ink)
			play.size_flags_vertical = SIZE_SHRINK_CENTER
			watch_row.add_child(play)
			watch_row.add_child(_label("or watch an ad", 14, 800, Palette.c.accent_ink))
			lock.add_child(watch)
		card.add_child(lock)
	# Buttons don't lay out children, so place them whenever the card's width changes.
	card.resized.connect(func():
		var w := card.size.x
		image.position = Vector2(1, 1)
		image.size = Vector2(w - 2, w - 2)
		caption.position = Vector2(12, w + 8)
		caption.size = Vector2(w - 24, 48)
		if lock:
			lock.position = Vector2(10, 0)
			lock.size = Vector2(w - 20, w)
		if not is_equal_approx(card.custom_minimum_size.y, w + 66):
			card.custom_minimum_size.y = w + 66)
	_press_fx(card, 0.97)
	card.pressed.connect(func():
		if locked:
			_offer_unlock(category, index)
		else:
			_request_new_game(func():
				_select_picture(category, index)
				_close(gallery)))
	return card

func _build_preview() -> void:
	preview = _make_overlay("Goal picture", false, true, true, 720)
	preview_image = RoundedImage.new()
	preview_image.radii = [15, 15, 15, 15]
	preview_image.square = true
	preview.content.add_child(preview_image)
	preview.on_open = func():
		preview_image.texture = texture
		var vp := get_viewport_rect().size
		var side := minf(minf(vp.x * 0.94, 720.0) - 50.0, vp.y * 0.74)
		preview_image.custom_minimum_size = Vector2(side, side)

func _build_win() -> void:
	win = _make_overlay("", false, true, false, 475)
	var c: VBoxContainer = win.content
	c.add_child(_spacer(6))
	win_image = RoundedImage.new()
	win_image.radii = [25, 25, 25, 25]
	win_image.custom_minimum_size = Vector2(188, 188)
	win_image.size_flags_horizontal = SIZE_SHRINK_CENTER
	win_image.shadow = Color(0.055, 0.173, 0.141, 0.25)
	win_image.shadow_size = 22
	win_image.shadow_offset = Vector2(0, 12)
	c.add_child(win_image)
	c.add_child(_spacer(18))
	c.add_child(_centered(_label("Solved!", 34, 800)))
	win_sub = _centered(_label("", 17, 400, Palette.c.muted))
	c.add_child(win_sub)
	c.add_child(_spacer(18))
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 12)
	c.add_child(stats)
	var values := []
	for caption in ["MOVES", "TIME"]:
		var cell := _pill(Palette.c.panel, 17, Vector2(15, 9), Palette.c.line)
		cell.custom_minimum_size.x = 110
		stats.add_child(cell)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		cell.add_child(col)
		var value := _centered(_label("0", 25, 800, Palette.c.fg, true))
		col.add_child(value)
		col.add_child(_centered(_label(caption, 12, 800, Palette.c.muted)))
		values.append(value)
	win_moves = values[0]
	win_time = values[1]
	win_unlock = _pill(Palette.mix(Palette.c.win, Palette.c.bg, 0.12), 15, Vector2(15, 10))
	win_unlock.add_child(_centered(_label("", 17, 700, Palette.c.win)))
	var unlock_wrap := VBoxContainer.new()
	unlock_wrap.add_theme_constant_override("separation", 0)
	unlock_wrap.add_child(_spacer(15))
	unlock_wrap.add_child(win_unlock)
	c.add_child(unlock_wrap)
	win_unlock.visibility_changed.connect(func(): unlock_wrap.visible = win_unlock.visible)
	c.add_child(_spacer(22))
	var buttons := _button_row("Play again", "Next picture")
	c.add_child(buttons)
	next_button = buttons.get_child(1) as Button
	(buttons.get_child(0) as Button).pressed.connect(func():
		_close(win)
		_shuffle())
	next_button.pressed.connect(func():
		var target := _next_target()
		_close(win)
		_select_picture(target[0], target[1]))

func _build_confirm() -> void:
	confirm = _make_overlay("Start a new puzzle?", false, false, false, 420)
	var message := _label("Your current progress will be lost.", 18, 400, Palette.c.muted)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm.content.add_child(message)
	confirm.content.add_child(_spacer(22))
	var buttons := _button_row("Keep playing", "Start new")
	confirm.content.add_child(buttons)
	(buttons.get_child(0) as Button).pressed.connect(func(): _close(confirm))
	(buttons.get_child(1) as Button).pressed.connect(func():
		var action := pending_action
		pending_action = Callable()
		_close(confirm)
		if action.is_valid():
			action.call())
	confirm.on_close = func(): pending_action = Callable()

# --- Rewarded ad: unlock the next level now ---

func _build_unlock() -> void:
	unlock = _make_overlay("Unlock now?", false, true, true, 440)
	unlock_title = (unlock.panel.get_child(0).get_child(0).get_child(0) as HBoxContainer).get_child(0) as Label
	var message := _label("", 18, 400, Palette.c.muted)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.name = "Message"
	unlock.content.add_child(message)
	unlock_status = _label("", 16, 700, Palette.c.win)
	unlock_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unlock_status.visible = false
	var status_wrap := VBoxContainer.new()
	status_wrap.add_child(_spacer(12))
	status_wrap.add_child(unlock_status)
	unlock.content.add_child(status_wrap)
	unlock.content.add_child(_spacer(22))
	var buttons := _button_row("Not now", "Watch ad")
	unlock.content.add_child(buttons)
	(buttons.get_child(0) as Button).pressed.connect(func(): _close(unlock))
	(buttons.get_child(1) as Button).pressed.connect(_watch_for_unlock)

func _offer_unlock(category: String, index: int) -> void:
	unlock_target = [category, index]
	unlock_title.text = "Unlock %s now?" % LEVELS[index]
	(unlock.content.get_node("Message") as Label).text = (
		"Watch a short video ad to unlock all %s pictures right away. Or unlock them for free by solving a %s puzzle."
		% [LEVELS[index], LEVELS[index - 1]])
	unlock_status.visible = false
	_open(unlock)

func _watch_for_unlock() -> void:
	unlock_status.visible = false
	if not ads.show_rewarded():
		unlock_status.text = "No ad is ready yet. Check your internet connection and try again in a moment."
		unlock_status.visible = true

func _on_rewarded_finished(earned: bool) -> void:
	if unlock_target.is_empty():
		return
	if not earned:
		unlock_status.text = "The ad was closed early, so nothing was unlocked."
		unlock_status.visible = true
		return
	var category: String = unlock_target[0]
	var index: int = unlock_target[1]
	unlock_target = []
	unlocked_tier = maxi(unlocked_tier, index)
	_save()
	_close(unlock)
	_close(gallery)
	_request_new_game(func():
		_select_picture(category, index)
		hint.text = "%s unlocked! Enjoy the new puzzles." % LEVELS[index])

# --- Overlays: bottom sheets and centred dialogs ---

class Overlay:
	var root: Control
	var backdrop: ColorRect
	var mover: Control
	var panel: PanelContainer
	var scroll: ScrollContainer
	var content: VBoxContainer
	var sheet := false
	var closable := true
	var tween: Tween
	var on_open := Callable()
	var on_close := Callable()

func _make_overlay(title: String, sheet: bool, closable: bool = true, close_button: bool = true, max_width: float = 525.0) -> Overlay:
	var ov := Overlay.new()
	ov.sheet = sheet
	ov.closable = closable
	ov.root = Control.new()
	ov.root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ov.root.visible = false
	ui_root.add_child(ov.root)
	ov.backdrop = ColorRect.new()
	ov.backdrop.color = Color(0.024, 0.055, 0.043, 0.6)
	ov.backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ov.backdrop.gui_input.connect(func(event: InputEvent):
		if closable and event is InputEventMouseButton and not event.is_pressed():
			_close(ov))
	ov.root.add_child(ov.backdrop)

	ov.panel = PanelContainer.new()
	var style := Palette.box(Palette.c.bg, 30 if sheet else 27, Palette.c.line, 1)
	Palette.shadow(style, Color(0.031, 0.11, 0.086, 0.3), 40, Vector2(0, 20))
	if sheet:
		style.corner_radius_bottom_left = 0
		style.corner_radius_bottom_right = 0
		style.border_width_bottom = 0
	ov.panel.add_theme_stylebox_override("panel", style)
	if sheet:
		var column := VBoxContainer.new()
		column.mouse_filter = MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 0)
		column.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		var top_space := Control.new()
		top_space.mouse_filter = MOUSE_FILTER_IGNORE
		top_space.size_flags_vertical = SIZE_EXPAND_FILL
		column.add_child(top_space)
		column.add_child(ov.panel)
		ov.mover = column
	else:
		var center := CenterContainer.new()
		center.mouse_filter = MOUSE_FILTER_IGNORE
		center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		center.add_child(ov.panel)
		ov.mover = center
		ov.panel.custom_minimum_size.x = minf(get_viewport_rect().size.x * 0.92, max_width)
	ov.root.add_child(ov.mover)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 24)
	pad.add_theme_constant_override("margin_right", 24)
	pad.add_theme_constant_override("margin_bottom", 26)
	pad.add_theme_constant_override("margin_top", 0 if not title.is_empty() else 26)
	ov.panel.add_child(pad)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	pad.add_child(column)
	if sheet:
		var grab_row := CenterContainer.new()
		grab_row.custom_minimum_size.y = 22
		var grabber := Panel.new()
		grabber.custom_minimum_size = Vector2(50, 6)
		grabber.add_theme_stylebox_override("panel", Palette.box(Palette.c.line, 3))
		grab_row.add_child(grabber)
		column.add_child(grab_row)
	if not title.is_empty():
		var head := HBoxContainer.new()
		head.custom_minimum_size.y = 76 if sheet else 82
		head.add_theme_constant_override("separation", 15)
		column.add_child(head)
		var heading := _label(title, 26, 800)
		heading.size_flags_horizontal = SIZE_EXPAND_FILL
		head.add_child(heading)
		if close_button:
			var close := _icon_button("x", 50, 25, Palette.c.well, Color.TRANSPARENT)
			close.pressed.connect(func(): _close(ov))
			head.add_child(close)
	ov.content = VBoxContainer.new()
	ov.content.add_theme_constant_override("separation", 0)
	ov.content.size_flags_horizontal = SIZE_EXPAND_FILL
	if sheet:
		ov.scroll = ScrollContainer.new()
		ov.scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		ov.scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		ov.scroll.add_child(ov.content)
		column.add_child(ov.scroll)
		ov.content.minimum_size_changed.connect(_fit_sheet.bind(ov))
	else:
		column.add_child(ov.content)
	return ov

func _fit_sheet(ov: Overlay) -> void:
	var vp := get_viewport_rect().size
	var bottom := float(margin.get_theme_constant("margin_bottom"))
	ov.scroll.custom_minimum_size.y = minf(ov.content.get_combined_minimum_size().y + bottom, vp.y * 0.9 - 130.0)

func _open(ov: Overlay) -> void:
	if ov in stack:
		return
	stack.append(ov)
	ads.set_banner_visible(false)
	if ov.on_open.is_valid():
		ov.on_open.call()
	ov.root.move_to_front()
	ov.root.visible = true
	if ov.sheet:
		_fit_sheet(ov)
		ov.scroll.scroll_vertical = 0
	if ov.tween:
		ov.tween.kill()
	ov.backdrop.modulate.a = 0.0
	ov.tween = create_tween().set_parallel()
	ov.tween.tween_property(ov.backdrop, "modulate:a", 1.0, 0.2)
	if ov.sheet:
		ov.mover.position.y = get_viewport_rect().size.y
		ov.tween.tween_property(ov.mover, "position:y", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		ov.mover.pivot_offset = ov.mover.size / 2.0
		ov.mover.scale = Vector2(0.94, 0.94)
		ov.mover.modulate.a = 0.0
		ov.tween.tween_property(ov.mover, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)
		ov.tween.tween_property(ov.mover, "modulate:a", 1.0, 0.2)

func _close(ov: Overlay) -> void:
	if not ov in stack:
		return
	stack.erase(ov)
	if stack.is_empty():
		ads.set_banner_visible(true)
	if ov.on_close.is_valid():
		ov.on_close.call()
	if ov.tween:
		ov.tween.kill()
	ov.tween = create_tween().set_parallel()
	ov.tween.tween_property(ov.backdrop, "modulate:a", 0.0, 0.18)
	if ov.sheet:
		ov.tween.tween_property(ov.mover, "position:y", ov.panel.size.y, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	else:
		ov.tween.tween_property(ov.mover, "modulate:a", 0.0, 0.14)
	ov.tween.chain().tween_callback(func():
		if is_instance_valid(ov.root):  # The UI may have been rebuilt for a theme change meanwhile.
			ov.root.visible = false)

func _close_top() -> void:
	var top: Overlay = stack.back()
	if top.closable or top == confirm:
		_close(top)

## Reserved strip at the bottom for the banner. On Android the real ad is drawn over it by AdMob;
## elsewhere it shows a placeholder so the layout can be checked.
func _build_banner_slot() -> Control:
	var slot := Control.new()
	slot.anchor_left = 0.0
	slot.anchor_right = 1.0
	slot.anchor_top = 1.0
	slot.anchor_bottom = 1.0
	slot.visible = false
	slot.mouse_filter = MOUSE_FILTER_IGNORE
	var divider := ColorRect.new()
	divider.color = Palette.c.line
	divider.anchor_right = 1.0
	divider.offset_top = -9.0
	divider.offset_bottom = -8.0
	divider.mouse_filter = MOUSE_FILTER_IGNORE
	slot.add_child(divider)
	if not ads.live:
		var placeholder := PanelContainer.new()
		placeholder.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		placeholder.mouse_filter = MOUSE_FILTER_IGNORE
		placeholder.add_theme_stylebox_override("panel", Palette.box(Palette.mix(Palette.c.fg, Palette.c.bg, 0.06), 0))
		var text := _centered(_label("Ad banner · preview", 14, 700, Palette.c.muted))
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.add_child(text)
		slot.add_child(placeholder)
	return slot

# --- Small UI helpers ---

func _label(text: String, font_size: int, weight: int = 400, color: Variant = null, mono: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Palette.font(weight, mono))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Palette.c.fg if color == null else color)
	return l

func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _section_label(text: String, font_size: int = 14) -> Control:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 5)
	wrap.add_theme_constant_override("margin_bottom", 10)
	wrap.add_child(_label(text.to_upper(), font_size, 800, Palette.c.muted))
	return wrap

func _spacer(height: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size.y = height
	s.mouse_filter = MOUSE_FILTER_IGNORE
	return s

func _pill(bg: Color, radius: float, padding: Vector2, border: Color = Color.TRANSPARENT) -> PanelContainer:
	var p := PanelContainer.new()
	var style := Palette.box(bg, radius, border, 1 if border.a > 0 else 0)
	style.content_margin_left = padding.x
	style.content_margin_right = padding.x
	style.content_margin_top = padding.y
	style.content_margin_bottom = padding.y
	p.add_theme_stylebox_override("panel", style)
	return p

func _style_button(b: BaseButton, normal: StyleBox, pressed: StyleBox = null) -> void:
	for state in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, normal if state != "focus" else StyleBoxEmpty.new())
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, pressed if pressed else normal)

func _font_colors(b: Button, color: Color) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(state, color)

func _press_fx(c: BaseButton, amount: float = 0.95) -> void:
	c.resized.connect(func(): c.pivot_offset = c.size / 2.0)
	c.button_down.connect(func(): create_tween().tween_property(c, "scale", Vector2(amount, amount), 0.08))
	c.button_up.connect(func(): create_tween().tween_property(c, "scale", Vector2.ONE, 0.12))

func _icon_button(kind: String, side: float, radius: float, bg: Color = Palette.c.panel, border: Color = Palette.c.line) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(side, side)
	b.size_flags_vertical = SIZE_SHRINK_CENTER
	_style_button(b, Palette.box(bg, radius, border, 1 if border.a > 0 else 0))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	center.add_child(Icon.new(kind, side * 0.45, Palette.c.fg))
	b.add_child(center)
	_press_fx(b, 0.93)
	return b

func _action_style(primary: bool, active: bool = false) -> StyleBoxFlat:
	var c: Dictionary = Palette.c
	var style := Palette.box(c.accent if primary else c.panel, 22, c.accent if primary or active else c.line, 1)
	if primary:
		Palette.shadow(style, Color(c.accent, 0.32), 14, Vector2(0, 7))
	else:
		Palette.shadow(style, Color(0.09, 0.208, 0.18, 0.06), 10, Vector2(0, 5))
	return style

func _action_button(kind: String, text: String, primary: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size.y = 75
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	_style_button(b, _action_style(primary))
	var color: Color = Palette.c.accent_ink if primary else Palette.c.fg
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	b.add_child(column)
	var icon := Icon.new(kind, 27, color)
	icon.size_flags_horizontal = SIZE_SHRINK_CENTER
	column.add_child(icon)
	var label := _label(text, 16, 700, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	b.set_meta("label", label)
	b.set_meta("icon", icon)
	_press_fx(b)
	return b

func _button_row(secondary: String, primary: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for i in 2:
		var is_primary := i == 1
		var b := Button.new()
		b.text = primary if is_primary else secondary
		b.custom_minimum_size.y = 62
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.add_theme_font_override("font", Palette.font(700))
		b.add_theme_font_size_override("font_size", 19)
		var style := Palette.box(Palette.c.accent if is_primary else Palette.c.panel, 18, Palette.c.accent if is_primary else Palette.c.line, 1)
		if is_primary:
			Palette.shadow(style, Color(Palette.c.accent, 0.25), 12, Vector2(0, 5))
		_style_button(b, style)
		_font_colors(b, Palette.c.accent_ink if is_primary else Palette.c.fg)
		_press_fx(b, 0.97)
		row.add_child(b)
	return row

# --- Drawn widgets ---

## Line icons, matching the web version's inline SVG symbols (24×24 viewBox, 2 px stroke).
class Icon extends Control:
	var kind := ""
	var color := Color.WHITE:
		set(value):
			color = value
			queue_redraw()

	func _init(icon_kind: String = "", px: float = 27.0, icon_color: Color = Color.WHITE) -> void:
		kind = icon_kind
		color = icon_color
		custom_minimum_size = Vector2(px, px)
		mouse_filter = MOUSE_FILTER_IGNORE

	func _line(points: Array) -> void:
		var s := size.x / 24.0
		var pts := PackedVector2Array()
		for p in points:
			pts.append(p * s)
		draw_polyline(pts, color, maxf(1.5, 2.0 * s), true)

	func _circle(center: Vector2, r: float) -> void:
		var s := size.x / 24.0
		draw_arc(center * s, r * s, 0, TAU, 32, color, maxf(1.5, 2.0 * s), true)

	func _rounded(rect: Rect2, r: float) -> void:
		var pts := Array(Palette.rounded_points(rect, [r, r, r, r]))
		pts.append(pts[0])
		_line(pts)

	func _draw() -> void:
		match kind:
			"sliders":
				_line([Vector2(4, 7), Vector2(14, 7)])
				_line([Vector2(18, 7), Vector2(20, 7)])
				_line([Vector2(4, 17), Vector2(8, 17)])
				_line([Vector2(12, 17), Vector2(20, 17)])
				_circle(Vector2(16, 7), 2)
				_circle(Vector2(10, 17), 2)
			"image":
				_rounded(Rect2(3, 4, 18, 16), 3)
				_circle(Vector2(9, 10), 1.8)
				_line([Vector2(21, 16), Vector2(16, 11), Vector2(7, 20)])
			"shuffle":
				_line([Vector2(16, 4), Vector2(20, 4), Vector2(20, 8)])
				_line([Vector2(4, 20), Vector2(20, 4)])
				_line([Vector2(20, 16), Vector2(20, 20), Vector2(16, 20)])
				_line([Vector2(15, 15), Vector2(20, 20)])
				_line([Vector2(4, 4), Vector2(9, 9)])
			"eye":
				var top := []
				var bottom := []
				for i in 17:
					var t := i / 16.0
					var x := lerpf(2, 22, t)
					top.append(Vector2(x, 12 - 7 * sin(PI * t)))
					bottom.append(Vector2(x, 12 + 7 * sin(PI * t)))
				_line(top)
				_line(bottom)
				_circle(Vector2(12, 12), 3)
			"camera":
				_line([Vector2(4, 8), Vector2(7, 8), Vector2(9, 5), Vector2(15, 5), Vector2(17, 8), Vector2(20, 8), Vector2(21, 9),
					Vector2(21, 19), Vector2(20, 20), Vector2(4, 20), Vector2(3, 19), Vector2(3, 9), Vector2(4, 8)])
				_circle(Vector2(12, 13.5), 3.5)
			"play":
				var pts := PackedVector2Array([Vector2(7, 4), Vector2(20, 12), Vector2(7, 20)])
				var s := size.x / 24.0
				for i in pts.size():
					pts[i] *= s
				draw_colored_polygon(pts, color)
			"x":
				_line([Vector2(6, 6), Vector2(18, 18)])
				_line([Vector2(18, 6), Vector2(6, 18)])
			"lock":
				_rounded(Rect2(5, 11, 14, 10), 2)
				var shackle := [Vector2(8, 11)]
				for i in 13:
					var angle := PI + PI * i / 12.0
					shackle.append(Vector2(12, 8) + Vector2(cos(angle), sin(angle)) * 4)
				shackle.append(Vector2(16, 11))
				_line(shackle)

## An image drawn into a rounded rect, cropped to fill (CSS background-size: cover).
class RoundedImage extends Control:
	var texture: Texture2D:
		set(value):
			texture = value
			queue_redraw()
	var radii := [0, 0, 0, 0]
	var square := false
	var shadow := Color.TRANSPARENT
	var shadow_size := 0
	var shadow_offset := Vector2.ZERO

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if square:
			var side := minf(size.x, size.y)
			rect = Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side))
		if shadow.a > 0.0:
			var back := Palette.shadow(Palette.box(Palette.c.well, radii[0]), shadow, shadow_size, shadow_offset)
			draw_style_box(back, rect)
		else:
			var back := Palette.box(Palette.c.well, 0)
			back.corner_radius_top_left = radii[0]
			back.corner_radius_top_right = radii[1]
			back.corner_radius_bottom_right = radii[2]
			back.corner_radius_bottom_left = radii[3]
			draw_style_box(back, rect)
		Palette.draw_image(self, texture, rect, Palette.cover_uv(texture, rect.size), radii)

## On/off switch like the web's .switch (track + sliding knob).
class Switch extends Control:
	var t := 0.0:
		set(value):
			t = value
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(60, 35)
		size_flags_vertical = SIZE_SHRINK_CENTER
		mouse_filter = MOUSE_FILTER_IGNORE

	func set_on(on: bool, animate: bool = false) -> void:
		if animate and is_inside_tree():
			create_tween().tween_property(self, "t", 1.0 if on else 0.0, 0.2)
		else:
			t = 1.0 if on else 0.0

	func _draw() -> void:
		var c: Dictionary = Palette.c
		draw_style_box(Palette.box(c.line.lerp(c.accent, t), 17.5), Rect2(Vector2.ZERO, size))
		var knob := Vector2(lerpf(17.5, size.x - 17.5, t), size.y / 2.0)
		draw_circle(knob + Vector2(0, 1.5), 14.0, Color(0, 0, 0, 0.2))
		draw_circle(knob, 13.5, Color.WHITE)
