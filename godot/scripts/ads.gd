extends Node
## AdMob banner and rewarded ads through the Poing Studios AdMob plugin (res://addons/admob).
## The plugin's classes are looked up at runtime, so the game still runs before the plugin is installed.
## Off Android, or without the plugin, ads run in preview mode: a placeholder banner and a simulated rewarded ad,
## so the layout and the unlock flow can be tested on a PC.

signal banner_changed  ## banner_height changed (in viewport units).
signal rewarded_finished(earned: bool)  ## A rewarded ad closed; earned is true if the player watched it through.
signal privacy_changed  ## privacy_options_required changed.

# Google's test ad units. Debug builds always use these, so you never click your own live ads.
const TEST_BANNER := "ca-app-pub-3940256099942544/6300978111"
const TEST_REWARDED := "ca-app-pub-3940256099942544/5224354917"
# Your ad unit IDs from AdMob → Apps → TileTales → Ad units (they contain a "/"). Used in release exports.
const BANNER_UNIT := "ca-app-pub-7198171083469324/6221381613"  # TileTales Banner
const REWARDED_UNIT := "ca-app-pub-7198171083469324/4785011015"  # TileTales Unlock Level

const PREVIEW_BANNER_HEIGHT := 62.0  # A 50 dp banner at this game's scale.
const RETRY_SECONDS := 30.0
const CONSENT_REQUIRED := 2  # ConsentInformation.ConsentStatus.REQUIRED
const PRIVACY_REQUIRED := 2  # ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED

var live := false  ## True when the AdMob plugin is running on Android.
var banner_height := 0.0  ## Space to reserve at the bottom of the screen, in viewport units.
var privacy_options_required := false

var _classes := {}
var _banner  # AdView
var _rewarded  # RewardedAd
var _loading_rewarded := false
var _earned := false
var _started := false
var _banner_visible := false
var _banner_tween: Tween
var _banner_y_dp := 0.0

func start() -> void:
	live = OS.get_name() == "Android" and Engine.has_singleton("PoingGodotAdMob") and _cls("MobileAds") != null
	if not live:
		banner_height = PREVIEW_BANNER_HEIGHT
		banner_changed.emit()
		return
	_gather_consent()

func rewarded_ready() -> bool:
	return not live or _rewarded != null

## Shows a rewarded ad. Returns false if none is loaded yet (one is then requested).
func show_rewarded() -> bool:
	if not live:
		_show_preview_ad()
		return true
	if _rewarded == null:
		_load_rewarded()
		return false
	_earned = false
	var content = _cls("FullScreenContentCallback").new()
	content.on_ad_dismissed_full_screen_content = _finish_rewarded
	content.on_ad_failed_to_show_full_screen_content = func(_error): _finish_rewarded()
	_rewarded.full_screen_content_callback = content
	var listener = _cls("OnUserEarnedRewardListener").new()
	listener.on_user_earned_reward = func(_item): _earned = true
	_rewarded.show(listener)
	return true

## Native banners draw above the game. An idle banner slides up; input hides it immediately.
func set_banner_visible(on: bool, animate: bool = false) -> void:
	_banner_visible = on
	if not _banner:
		return
	if _banner_tween and _banner_tween.is_running():
		_banner_tween.kill()
	if not on:
		_banner.hide()
		return
	if not animate:
		_banner.set_position(_banner_position(_banner_rest_y_dp()))
		_banner.show()
		return
	_banner_y_dp = _banner_hidden_y_dp()
	_banner.set_position(_banner_position(int(_banner_y_dp)))
	_banner.show()
	_banner_tween = create_tween()
	_banner_tween.tween_method(_move_banner_to, _banner_y_dp, _banner_rest_y_dp(), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _move_banner_to(y_dp: float) -> void:
	_banner_y_dp = y_dp
	if _banner:
		_banner.set_position(_banner_position(roundi(y_dp)))

func _banner_position(y_dp: int):
	return _cls("AdPosition").custom(0, y_dp)

func _banner_density() -> float:
	return maxf(1.0, DisplayServer.screen_get_dpi() / 160.0)

func _banner_rest_y_dp() -> float:
	var safe := DisplayServer.get_display_safe_area()
	var safe_bottom := float(safe.end.y) if safe.size.y > 0 else float(DisplayServer.screen_get_size().y)
	return maxf(0.0, safe_bottom / _banner_density() - float(_banner.ad_size.height))

func _banner_hidden_y_dp() -> float:
	return float(DisplayServer.window_get_size().y) / _banner_density() + 8.0

func show_privacy_options() -> void:
	if live:
		_cls("UserMessagingPlatform").show_privacy_options_form(func(_error): _update_privacy())

# --- Consent (Google's User Messaging Platform; shows the EEA/UK consent form when required) ---

func _gather_consent() -> void:
	var ump = _cls("UserMessagingPlatform")
	var params = _cls("ConsentRequestParameters").new()
	params.tag_for_under_age_of_consent = false  # General audience game.
	ump.consent_information.update(params, _on_consent_updated, func(_error): _start_ads())

func _on_consent_updated() -> void:
	var ump = _cls("UserMessagingPlatform")
	_update_privacy()
	if ump.consent_information.get_is_consent_form_available() and ump.consent_information.get_consent_status() == CONSENT_REQUIRED:
		ump.load_consent_form(func(form): form.show(func(_error):
			_update_privacy()
			_start_ads()), func(_error): _start_ads())
	else:
		_start_ads()

func _update_privacy() -> void:
	var required: bool = _cls("UserMessagingPlatform").consent_information.get_privacy_options_requirement_status() == PRIVACY_REQUIRED
	if required != privacy_options_required:
		privacy_options_required = required
		privacy_changed.emit()

# --- Ads ---

func _start_ads() -> void:
	if _started:
		return
	_started = true
	_cls("MobileAds").initialize()
	_load_banner()
	_load_rewarded()

func _unit(own: String, test: String) -> String:
	return test if OS.is_debug_build() or own.is_empty() else own

## Converts native pixels to this game's viewport units.
func _to_units(pixels: float) -> float:
	var window := DisplayServer.window_get_size()
	return pixels * get_viewport().get_visible_rect().size.y / float(window.y) if window.y > 0 else 0.0

func _load_banner() -> void:
	var size_class = _cls("AdSize")
	var size = size_class.get_current_orientation_anchored_adaptive_banner_ad_size(size_class.FULL_WIDTH)
	_banner = _cls("AdView").new(_unit(BANNER_UNIT, TEST_BANNER), size, _banner_position(int(_banner_hidden_y_dp())))
	_banner.hide()
	# Reserve the adaptive banner's height straight away, so the board doesn't jump when the ad arrives.
	banner_height = _to_units(size.height * DisplayServer.screen_get_dpi() / 160.0)
	banner_changed.emit()
	_banner.ad_listener.on_ad_loaded = func():
		banner_height = _to_units(_banner.get_height_in_pixels())
		banner_changed.emit()
		set_banner_visible(_banner_visible, _banner_visible)
	_banner.ad_listener.on_ad_failed_to_load = func(_error):
		get_tree().create_timer(RETRY_SECONDS).timeout.connect(func(): _banner.load_ad(_cls("AdRequest").new()))
	_banner.load_ad(_cls("AdRequest").new())

func _load_rewarded() -> void:
	if not live or not _started or _loading_rewarded or _rewarded:
		return
	_loading_rewarded = true
	var callback = _cls("RewardedAdLoadCallback").new()
	callback.on_ad_loaded = func(ad):
		_loading_rewarded = false
		_rewarded = ad
	callback.on_ad_failed_to_load = func(_error):
		_loading_rewarded = false
		get_tree().create_timer(RETRY_SECONDS).timeout.connect(_load_rewarded)
	_cls("RewardedAdLoader").new().load(_unit(REWARDED_UNIT, TEST_REWARDED), _cls("AdRequest").new(), callback)

func _finish_rewarded() -> void:
	if _rewarded:
		_rewarded.destroy()
		_rewarded = null
	rewarded_finished.emit(_earned)
	_load_rewarded()  # Have the next one ready.

## A plugin class (by class_name), or null when the plugin isn't installed.
func _cls(class_id: String):
	if not _classes.has(class_id):
		_classes[class_id] = null
		for entry in ProjectSettings.get_global_class_list():
			if entry["class"] == class_id:
				_classes[class_id] = load(entry["path"])
				break
	return _classes[class_id]

# --- Preview mode: a stand-in rewarded ad for testing on a PC ---

func _show_preview_ad() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.03, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	var title := Label.new()
	title.text = "Rewarded ad preview"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var note := Label.new()
	note.text = "Real video ads play in the Android app."
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)
	var countdown := Label.new()
	countdown.add_theme_font_size_override("font_size", 22)
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(countdown)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	var skip := Button.new()
	skip.text = "Close early"
	skip.custom_minimum_size = Vector2(150, 52)
	buttons.add_child(skip)
	var done := Button.new()
	done.text = "Claim reward"
	done.custom_minimum_size = Vector2(150, 52)
	done.disabled = true
	buttons.add_child(done)
	var finish := func(earned: bool):
		layer.queue_free()
		rewarded_finished.emit(earned)
	skip.pressed.connect(finish.bind(false))
	done.pressed.connect(finish.bind(true))
	for seconds in [3, 2, 1]:
		if not is_instance_valid(layer):
			return
		countdown.text = "Reward in %d…" % seconds
		await get_tree().create_timer(1.0).timeout
	if is_instance_valid(layer):
		countdown.text = "Reward ready"
		done.disabled = false
