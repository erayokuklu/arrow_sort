extends Control
class_name WaitingArea
## 7 yuvalı bekleme alanını, blok yerleşimini, 3'lü renk eşleşme sistemini,
## CPUParticles2D parçacık patlamalarını ve yuvaları sola kaydırmayı yönetir.

signal match_occurred(color_id: String)

const MAX_SLOTS: int = 7
const WAITING_SLOT_SCENE: PackedScene = preload("res://scenes/waiting_slot.tscn")
const ARROW_BLOCK_SCENE: PackedScene = preload("res://scenes/arrow_block.tscn")
const AREA_PADDING_X: float = 16.0
const SLOT_GAP: float = 8.0

var slot_nodes: Array[WaitingSlot] = []
var slot_blocks: Array[ArrowBlock] = []
var slot_size: float = 80.0
var _particle_texture: ImageTexture = null


func _ready() -> void:
	_particle_texture = _create_soft_circle_texture()
	_setup_slots()
	queue_redraw()


## Harici görsel dosyası gerektirmeden CPUParticles2D için yumuşak kenarlı dairesel doku üretir.
func _create_soft_circle_texture() -> ImageTexture:
	var tex_size: int = 20
	var img: Image = Image.create_empty(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(float(tex_size) * 0.5, float(tex_size) * 0.5)
	var max_r: float = float(tex_size) * 0.5

	for y: int in range(tex_size):
		for x: int in range(tex_size):
			var dist: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
			var alpha: float = clampf(1.0 - (dist / max_r), 0.0, 1.0)
			alpha = alpha * alpha
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(img)


func _setup_slots() -> void:
	for child: Node in get_children():
		child.queue_free()
	slot_nodes.clear()
	slot_blocks.clear()

	var avail_w: float = size.x - AREA_PADDING_X * 2.0 - SLOT_GAP * float(MAX_SLOTS - 1)
	slot_size = floorf(minf(avail_w / float(MAX_SLOTS), size.y - 24.0))
	slot_size = clampf(slot_size, 64.0, 86.0)

	var total_w: float = slot_size * float(MAX_SLOTS) + SLOT_GAP * float(MAX_SLOTS - 1)
	var start_x: float = (size.x - total_w) * 0.5
	var pos_y: float = (size.y - slot_size) * 0.5

	for i: int in range(MAX_SLOTS):
		var slot: WaitingSlot = WAITING_SLOT_SCENE.instantiate() as WaitingSlot
		add_child(slot)
		slot.slot_index = i
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		slot.size = Vector2(slot_size, slot_size)
		slot.position = Vector2(start_x + float(i) * (slot_size + SLOT_GAP), pos_y)
		slot_nodes.append(slot)
		slot_blocks.append(null)


func clear_waiting_area() -> void:
	for i: int in range(MAX_SLOTS):
		if slot_blocks[i] != null and is_instance_valid(slot_blocks[i]):
			slot_blocks[i].queue_free()
		slot_blocks[i] = null
		if i < slot_nodes.size():
			slot_nodes[i].set_occupied(false)


func get_first_empty_slot_index() -> int:
	for i: int in range(MAX_SLOTS):
		if slot_blocks[i] == null:
			return i
	return -1


func has_empty_slot() -> bool:
	return get_first_empty_slot_index() != -1


func is_full() -> bool:
	return get_first_empty_slot_index() == -1


func get_slot_global_position(slot_idx: int) -> Vector2:
	if slot_idx < 0 or slot_idx >= slot_nodes.size():
		return global_position
	return slot_nodes[slot_idx].global_position


## İpucu sistemi için bekleme alanındaki renklerin kaçar adet olduğunu Dictionary olarak döndürür.
func get_waiting_color_counts() -> Dictionary:
	var counts: Dictionary = {}
	for i: int in range(MAX_SLOTS):
		var blk: ArrowBlock = slot_blocks[i]
		if blk != null and is_instance_valid(blk):
			counts[blk.color_id] = int(counts.get(blk.color_id, 0)) + 1
	return counts


func place_block_in_slot(block: ArrowBlock, slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= MAX_SLOTS:
		return

	if block.get_parent() != self:
		block.reparent(self)

	block.stop_hint_highlight()
	block.is_in_waiting_area = true
	block.is_interactable = false
	block.size = Vector2(slot_size, slot_size)
	block.position = slot_nodes[slot_idx].position
	block.scale = Vector2.ONE
	block.modulate = Color.WHITE

	slot_blocks[slot_idx] = block
	slot_nodes[slot_idx].set_occupied(true)


## Aynı renkten 3 blok bulunduğunda CPUParticles2D patlaması ve küçülme animasyonuyla siler.
func check_and_resolve_matches() -> bool:
	var color_indices: Dictionary = {}
	for i: int in range(MAX_SLOTS):
		var blk: ArrowBlock = slot_blocks[i]
		if blk != null and is_instance_valid(blk):
			if not color_indices.has(blk.color_id):
				color_indices[blk.color_id] = []
			color_indices[blk.color_id].append(i)

	var matched_color: String = ""
	var matched_slots: Array = []

	for c_id: String in color_indices.keys():
		var indices: Array = color_indices[c_id]
		if indices.size() >= 3:
			matched_color = c_id
			matched_slots = [indices[0], indices[1], indices[2]]
			break

	if matched_slots.is_empty():
		return false

	var blocks_to_remove: Array[ArrowBlock] = []
	var particle_Color: Color = ArrowBlock.COLOR_PALETTE.get(matched_color, Color("#38BDF8"))

	for idx_variant: Variant in matched_slots:
		var idx: int = int(idx_variant)
		var blk: ArrowBlock = slot_blocks[idx]
		slot_blocks[idx] = null
		slot_nodes[idx].set_occupied(false)
		if blk != null and is_instance_valid(blk):
			blocks_to_remove.append(blk)
			var center_pos: Vector2 = slot_nodes[idx].position + Vector2(slot_size * 0.5, slot_size * 0.5)
			_spawn_match_particles(center_pos, particle_Color)

	match_occurred.emit(matched_color)

	var match_tween: Tween = create_tween()
	match_tween.set_parallel(true)
	for blk: ArrowBlock in blocks_to_remove:
		blk.pivot_offset = blk.size * 0.5
		match_tween.tween_property(blk, "scale", Vector2(1.24, 1.24), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		match_tween.tween_property(blk, "scale", Vector2.ZERO, 0.15).set_delay(0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		match_tween.tween_property(blk, "modulate:a", 0.0, 0.15).set_delay(0.09)

	await match_tween.finished
	for blk: ArrowBlock in blocks_to_remove:
		if is_instance_valid(blk):
			blk.queue_free()

	await _compact_slots()
	return true


## Eşleşen her yuvanın merkezinde renkli CPUParticles2D patlaması oluşturur ve bitince temizler.
func _spawn_match_particles(local_center: Vector2, base_color: Color) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.position = local_center
	particles.z_index = 20
	particles.texture = _particle_texture
	particles.amount = 26
	particles.lifetime = 0.62
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, 280.0)
	particles.initial_velocity_min = 95.0
	particles.initial_velocity_max = 225.0
	particles.damping_min = 140.0
	particles.damping_max = 200.0
	particles.scale_amount_min = 0.55
	particles.scale_amount_max = 1.25

	var scale_curve: Curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.65, 0.85))
	scale_curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = scale_curve

	var grad: Gradient = Gradient.new()
	grad.set_color(0, base_color.lightened(0.32))
	grad.add_point(0.55, base_color)
	grad.set_color(1, Color(base_color.r, base_color.g, base_color.b, 0.0))
	particles.color_ramp = grad

	add_child(particles)
	particles.finished.connect(particles.queue_free)
	particles.emitting = true


func _compact_slots() -> void:
	var remaining_blocks: Array[ArrowBlock] = []
	for i: int in range(MAX_SLOTS):
		if slot_blocks[i] != null and is_instance_valid(slot_blocks[i]):
			remaining_blocks.append(slot_blocks[i])
		slot_blocks[i] = null
		slot_nodes[i].set_occupied(false)

	var shift_tween: Tween = null
	for target_idx: int in range(remaining_blocks.size()):
		var blk: ArrowBlock = remaining_blocks[target_idx]
		slot_blocks[target_idx] = blk
		slot_nodes[target_idx].set_occupied(true)
		var target_pos: Vector2 = slot_nodes[target_idx].position
		if blk.position.distance_to(target_pos) > 1.0:
			if shift_tween == null:
				shift_tween = create_tween()
				shift_tween.set_parallel(true)
			shift_tween.tween_property(blk, "position", target_pos, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if shift_tween != null:
		await shift_tween.finished


func play_lose_shake() -> void:
	var base_x: float = position.x
	var shake_tween: Tween = create_tween()
	shake_tween.tween_property(self, "position:x", base_x - 10.0, 0.05)
	shake_tween.tween_property(self, "position:x", base_x + 10.0, 0.05)
	shake_tween.tween_property(self, "position:x", base_x - 6.0, 0.05)
	shake_tween.tween_property(self, "position:x", base_x, 0.05)


func serialize_waiting_state() -> Array:
	var state: Array = []
	for i: int in range(MAX_SLOTS):
		var blk: ArrowBlock = slot_blocks[i]
		if blk != null and is_instance_valid(blk):
			state.append({
				"slot": i,
				"color": blk.color_id,
				"direction": ArrowBlock.direction_to_string(blk.direction)
			})
	return state


func restore_waiting_state(waiting_snapshot: Array) -> void:
	clear_waiting_area()
	for item: Variant in waiting_snapshot:
		if typeof(item) == TYPE_DICTIONARY:
			var d: Dictionary = item as Dictionary
			var s_idx: int = int(d.get("slot", 0))
			if s_idx >= 0 and s_idx < MAX_SLOTS:
				var blk: ArrowBlock = ARROW_BLOCK_SCENE.instantiate() as ArrowBlock
				add_child(blk)
				blk.setup(Vector2i.ZERO, str(d["color"]), str(d["direction"]), Vector2(slot_size, slot_size))
				place_block_in_slot(blk, s_idx)


func _draw() -> void:
	var panel_box: StyleBoxFlat = StyleBoxFlat.new()
	panel_box.bg_color = Color(0.117647, 0.160784, 0.231373, 1.0)
	panel_box.set_corner_radius_all(20)
	panel_box.border_color = Color(0.22, 0.30, 0.42, 1.0)
	panel_box.set_border_width_all(3)
	draw_style_box(panel_box, Rect2(Vector2.ZERO, size))