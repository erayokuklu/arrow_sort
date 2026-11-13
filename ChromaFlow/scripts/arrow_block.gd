extends Control
class_name ArrowBlock
## Oyun tahtasındaki ve bekleme alanındaki tekil renkli ok bloğu.
## Prosedürel çizim (_draw) ile yuvarlatılmış blok gövdesi, ok simgesi ve İpucu vurgusu oluşturur.

signal block_clicked(block: ArrowBlock)

enum Direction {
	UP,
	DOWN,
	LEFT,
	RIGHT
}

const COLOR_PALETTE: Dictionary = {
	"red": Color("#EF4444"),
	"blue": Color("#3B82F6"),
	"green": Color("#10B981"),
	"yellow": Color("#F59E0B"),
	"purple": Color("#8B5CF6"),
	"orange": Color("#F97316"),
	"cyan": Color("#06B6D4")
}

var grid_pos: Vector2i = Vector2i.ZERO
var color_id: String = "red"
var direction: Direction = Direction.UP
var is_in_waiting_area: bool = false
var is_interactable: bool = true
var is_hinted: bool = false

var _base_pos: Vector2 = Vector2.ZERO
var _feedback_tween: Tween = null
var _hint_tween: Tween = null
var _flash_ratio: float = 0.0
var _hint_glow_ratio: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size * 0.5
	resized.connect(_on_resized)
	queue_redraw()


func _on_resized() -> void:
	pivot_offset = size * 0.5
	queue_redraw()


## Bloğun başlangıç verilerini ayarlar.
func setup(p_grid_pos: Vector2i, p_color_id: String, p_dir_str: String, p_size: Vector2) -> void:
	grid_pos = p_grid_pos
	color_id = p_color_id.to_lower()
	direction = parse_direction(p_dir_str)
	custom_minimum_size = p_size
	size = p_size
	pivot_offset = p_size * 0.5
	is_in_waiting_area = false
	is_interactable = true
	stop_hint_highlight()
	queue_redraw()


## Metin tabanlı yön bilgisini Direction enum değerine çevirir.
static func parse_direction(dir_str: String) -> Direction:
	match dir_str.to_lower():
		"up":
			return Direction.UP
		"down":
			return Direction.DOWN
		"left":
			return Direction.LEFT
		"right":
			return Direction.RIGHT
		_:
			return Direction.UP


## Direction enum değerini metin karşılığına çevirir.
static func direction_to_string(dir: Direction) -> String:
	match dir:
		Direction.UP:
			return "up"
		Direction.DOWN:
			return "down"
		Direction.LEFT:
			return "left"
		Direction.RIGHT:
			return "right"
		_:
			return "up"


## Okun baktığı yönü birim vektör (Vector2i) olarak döndürür.
func get_direction_vector() -> Vector2i:
	match direction:
		Direction.UP:
			return Vector2i(0, -1)
		Direction.DOWN:
			return Vector2i(0, 1)
		Direction.LEFT:
			return Vector2i(-1, 0)
		Direction.RIGHT:
			return Vector2i(1, 0)
		_:
			return Vector2i(0, -1)


## Dokunmatik ve fare tıklamalarını algılar.
func _gui_input(event: InputEvent) -> void:
	if not is_interactable or is_in_waiting_area:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			accept_event()
			block_clicked.emit(self)


## Yol kapalı olduğunda bloğu çıkış yönüne hafifçe vurup geri döndüren görsel geri bildirim.
func play_blocked_feedback() -> void:
	if _feedback_tween and _feedback_tween.is_running():
		_feedback_tween.kill()
		position = _base_pos

	_base_pos = position
	var dir_vec: Vector2 = Vector2(get_direction_vector())
	var nudge_offset: Vector2 = dir_vec * (size.x * 0.16)

	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_SINE)
	_feedback_tween.set_ease(Tween.EASE_OUT)

	_feedback_tween.tween_method(_set_flash_ratio, 0.0, 0.65, 0.06)
	_feedback_tween.parallel().tween_property(self, "position", _base_pos + nudge_offset, 0.06)
	_feedback_tween.tween_property(self, "position", _base_pos - nudge_offset * 0.45, 0.06)
	_feedback_tween.tween_property(self, "position", _base_pos, 0.07)
	_feedback_tween.parallel().tween_method(_set_flash_ratio, 0.65, 0.0, 0.10)


## İpucu (Hint) jokeri kullanıldığında bloğu altın sarısı çerçeve ve ölçek nabzıyla vurgular.
func play_hint_highlight() -> void:
	stop_hint_highlight()
	is_hinted = true
	pivot_offset = size * 0.5

	_hint_tween = create_tween().set_loops(5)
	_hint_tween.set_trans(Tween.TRANS_SINE)
	_hint_tween.tween_method(_set_hint_glow_ratio, 0.0, 1.0, 0.25)
	_hint_tween.parallel().tween_property(self, "scale", Vector2(1.09, 1.09), 0.25)
	_hint_tween.tween_method(_set_hint_glow_ratio, 1.0, 0.15, 0.25)
	_hint_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.25)
	_hint_tween.finished.connect(stop_hint_highlight)


## İpucu vurgusunu durdurur ve bloğu normal görünümüne döndürür.
func stop_hint_highlight() -> void:
	if _hint_tween and _hint_tween.is_running():
		_hint_tween.kill()
	_hint_tween = null
	is_hinted = false
	_hint_glow_ratio = 0.0
	scale = Vector2.ONE
	queue_redraw()


## Karıştırma (Shuffle) sırasında bloğu yatayda kapatıp yeni renk ve yönüyle açar.
func play_shuffle_animation(new_color: String, new_dir: Direction, delay_sec: float = 0.0) -> void:
	stop_hint_highlight()
	pivot_offset = size * 0.5
	var tween: Tween = create_tween()
	if delay_sec > 0.0:
		tween.tween_interval(delay_sec)
	tween.tween_property(self, "scale:x", 0.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		color_id = new_color
		direction = new_dir
		queue_redraw()
	)
	tween.tween_property(self, "scale:x", 1.0, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_flash_ratio(val: float) -> void:
	_flash_ratio = val
	queue_redraw()


func _set_hint_glow_ratio(val: float) -> void:
	_hint_glow_ratio = val
	queue_redraw()


## Yuvarlatılmış blok gövdesini, 3B alt gölgesini, İpucu çerçevesini ve yön okunu çizer.
func _draw() -> void:
	var base_color: Color = COLOR_PALETTE.get(color_id, Color("#3B82F6"))
	var draw_color: Color = base_color.lerp(Color(1.0, 0.15, 0.15), _flash_ratio)
	draw_color = draw_color.lerp(Color(1.0, 0.95, 0.55), _hint_glow_ratio * 0.35)

	var shadow_color: Color = draw_color.darkened(0.32)
	var highlight_color: Color = draw_color.lightened(0.22)
	if is_hinted:
		highlight_color = highlight_color.lerp(Color(1.0, 0.92, 0.25), _hint_glow_ratio)

	var margin: float = 4.0
	var rect_size: Vector2 = size - Vector2(margin * 2.0, margin * 2.0)
	if rect_size.x <= 8.0 or rect_size.y <= 8.0:
		return

	var corner_radius: int = int(clampf(rect_size.x * 0.22, 8.0, 20.0))

	# İpucu dış parlama halkası
	if is_hinted and _hint_glow_ratio > 0.01:
		var glow_box: StyleBoxFlat = StyleBoxFlat.new()
		glow_box.bg_color = Color(1.0, 0.90, 0.20, 0.38 * _hint_glow_ratio)
		glow_box.set_corner_radius_all(corner_radius + 4)
		draw_style_box(glow_box, Rect2(Vector2.ZERO, size))

	# 1. Alt 3B derinlik katmanı
	var shadow_box: StyleBoxFlat = StyleBoxFlat.new()
	shadow_box.bg_color = shadow_color
	shadow_box.set_corner_radius_all(corner_radius)
	draw_style_box(shadow_box, Rect2(Vector2(margin, margin + 4.0), rect_size))

	# 2. Ana gövde katmanı
	var body_box: StyleBoxFlat = StyleBoxFlat.new()
	body_box.bg_color = draw_color
	body_box.set_corner_radius_all(corner_radius)
	body_box.border_color = highlight_color
	body_box.set_border_width_all(3 if is_hinted else 2)
	draw_style_box(body_box, Rect2(Vector2(margin, margin), rect_size - Vector2(0.0, 3.0)))

	# 3. Vektörel ok simgesi
	var center: Vector2 = size * 0.5 - Vector2(0.0, 1.5)
	var arrow_scale: float = minf(rect_size.x, rect_size.y) * 0.28
	_draw_arrow_icon(center, arrow_scale, direction)


func _draw_arrow_icon(center: Vector2, radius: float, dir: Direction) -> void:
	var angle: float = 0.0
	match dir:
		Direction.UP:
			angle = 0.0
		Direction.RIGHT:
			angle = PI * 0.5
		Direction.DOWN:
			angle = PI
		Direction.LEFT:
			angle = -PI * 0.5

	var raw_points: Array[Vector2] = [
		Vector2(0.0, -radius * 1.05),
		Vector2(radius * 0.85, -radius * 0.05),
		Vector2(radius * 0.36, -radius * 0.05),
		Vector2(radius * 0.36, radius * 0.95),
		Vector2(-radius * 0.36, radius * 0.95),
		Vector2(-radius * 0.36, -radius * 0.05),
		Vector2(-radius * 0.85, -radius * 0.05)
	]

	var transformed_points: PackedVector2Array = PackedVector2Array()
	var shadow_points: PackedVector2Array = PackedVector2Array()
	for pt: Vector2 in raw_points:
		var rotated_pt: Vector2 = pt.rotated(angle) + center
		transformed_points.append(rotated_pt)
		shadow_points.append(rotated_pt + Vector2(0.0, 2.0))

	draw_colored_polygon(shadow_points, Color(0.0, 0.0, 0.0, 0.25))
	draw_colored_polygon(transformed_points, Color(1.0, 1.0, 1.0, 0.96))
