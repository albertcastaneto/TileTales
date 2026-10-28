extends RefCounted
## Colours, fonts and drawing helpers shared by the UI. Values mirror the CSS tokens in www/index.html.

const LIGHT := {
	"bg": Color("#F2F6F2"), "fg": Color("#17352E"), "muted": Color("#61776F"), "well": Color("#E0EAE4"),
	"panel": Color("#FFFFFF"), "line": Color("#D5E2DB"), "accent": Color("#087F67"), "accent_ink": Color("#FFFFFF"),
	"win": Color("#B5650F"),
}
const DARK := {
	"bg": Color("#0F1714"), "fg": Color("#E2ECE8"), "muted": Color("#92A39D"), "well": Color("#1B2622"),
	"panel": Color("#16201C"), "line": Color("#2F3D37"), "accent": Color("#3CCB9F"), "accent_ink": Color("#082019"),
	"win": Color("#F0A54A"),
}

static var c: Dictionary = LIGHT
static var _fonts := {}

static func use_dark(dark: bool) -> void:
	c = DARK if dark else LIGHT

## Like CSS color-mix(in srgb, a amount%, b).
static func mix(a: Color, b: Color, amount: float) -> Color:
	return b.lerp(a, amount)

static func font(weight: int = 400, mono: bool = false) -> Font:
	var key := "%d-%s" % [weight, mono]
	if not _fonts.has(key):
		var f := SystemFont.new()
		if mono:
			f.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Roboto Mono", "Droid Sans Mono", "monospace"])
		else:
			f.font_names = PackedStringArray(["Segoe UI", "Roboto", "Noto Sans", "sans-serif"])
		f.font_weight = weight
		_fonts[key] = f
	return _fonts[key]

static func box(bg: Color, radius: float = 0.0, border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 10
	if border_width > 0:
		sb.border_color = border
		sb.set_border_width_all(border_width)
	sb.anti_aliasing = true
	return sb

static func shadow(sb: StyleBoxFlat, color: Color, size: int, offset: Vector2) -> StyleBoxFlat:
	sb.shadow_color = color
	sb.shadow_size = size
	sb.shadow_offset = offset
	return sb

## Points around a rect with per-corner radii [top-left, top-right, bottom-right, bottom-left].
static func rounded_points(rect: Rect2, radii: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var limit := minf(rect.size.x, rect.size.y) / 2.0
	var corners := [
		[Vector2(rect.position.x, rect.position.y), Vector2(1, 1), PI],
		[Vector2(rect.end.x, rect.position.y), Vector2(-1, 1), PI * 1.5],
		[Vector2(rect.end.x, rect.end.y), Vector2(-1, -1), 0.0],
		[Vector2(rect.position.x, rect.end.y), Vector2(1, -1), PI * 0.5],
	]
	for i in 4:
		var r := minf(float(radii[i]), limit)
		var corner: Vector2 = corners[i][0]
		if r < 0.5:
			pts.append(corner)
			continue
		var center: Vector2 = corner + corners[i][1] * r
		var start: float = corners[i][2]
		for step in 7:
			var angle := start + PI * 0.5 * step / 6.0
			pts.append(center + Vector2(cos(angle), sin(angle)) * r)
	return pts

## Draws part of a texture (uv_rect in 0..1) into a rounded rect.
static func draw_image(ci: CanvasItem, texture: Texture2D, rect: Rect2, uv_rect: Rect2, radii: Array, modulate: Color = Color.WHITE) -> void:
	if texture == null or rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	var pts := rounded_points(rect, radii)
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append(uv_rect.position + (p - rect.position) / rect.size * uv_rect.size)
	ci.draw_polygon(pts, PackedColorArray([modulate]), uvs, texture)

## UV rect that crops a texture to fill the target aspect ratio, like CSS background-size: cover.
static func cover_uv(texture: Texture2D, target: Vector2) -> Rect2:
	if texture == null or target.y <= 0.0:
		return Rect2(0, 0, 1, 1)
	var tex_aspect := float(texture.get_width()) / float(texture.get_height())
	var aspect := target.x / target.y
	if tex_aspect > aspect:
		var w := aspect / tex_aspect
		return Rect2((1.0 - w) / 2.0, 0, w, 1)
	var h := tex_aspect / aspect
	return Rect2(0, (1.0 - h) / 2.0, 1, h)

## Text drawn centred horizontally on x, with its top at y.
static func draw_text(ci: CanvasItem, text: String, center_x: float, top: float, f: Font, size: int, color: Color) -> void:
	var width := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(f, Vector2(center_x - width / 2.0, top + f.get_ascent(size)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
