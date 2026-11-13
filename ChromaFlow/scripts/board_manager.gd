extends Control
class_name BoardManager
## Oyun tahtasını (grid), hücre koordinatlarını, blokların çıkış yolu kontrolünü,
## akıllı İpucu (Hint) seçimini ve kilitlenmesiz Karıştırma (Shuffle) algoritmasını yönetir.

signal block_selected(block: ArrowBlock)

const ARROW_BLOCK_SCENE: PackedScene = preload("res://scenes/arrow_block.tscn")
const BOARD_PADDING: float = 24.0
const CELL_GAP: float = 8.0

var grid_width: int = 5
var grid_height: int = 5
var cell_size: float = 96.0
var grid_origin: Vector2 = Vector2.ZERO

## Koordinat (Vector2i) -> ArrowBlock eşlemesini tutan sözlük
var _blocks_by_coord: Dictionary = {}


func _ready() -> void:
	queue_redraw()


## Seviye verisine göre oyun tahtasını sıfırdan kurar.
func build_board(level_data: Dictionary) -> void:
	clear_board()

	grid_width = int(level_data.get("grid_width", 5))
	grid_height = int(level_data.get("grid_height", 5))
	_calculate_grid_metrics()

	var blocks_array: Array = level_data.get("blocks", [])
	for item: Variant in blocks_array:
		if typeof(item) == TYPE_DICTIONARY:
			var b_data: Dictionary = item as Dictionary
			var pos: Vector2i = Vector2i(int(b_data.get("x", 0)), int(b_data.get("y", 0)))
			var color_id: String = str(b_data.get("color", "red"))
			var dir_str: String = str(b_data.get("direction", "up"))
			_spawn_block_at(pos, color_id, dir_str)

	queue_redraw()


## Undo (Geri Alma) işlemi için kaydedilmiş blok listesinden tahtayı geri yükler.
func restore_board_state(blocks_snapshot: Array) -> void:
	clear_board()
	_calculate_grid_metrics()
	for item: Variant in blocks_snapshot:
		if typeof(item) == TYPE_DICTIONARY:
			var b_data: Dictionary = item as Dictionary
			var pos: Vector2i = Vector2i(int(b_data["x"]), int(b_data["y"]))
			_spawn_block_at(pos, str(b_data["color"]), str(b_data["direction"]))
	queue_redraw()


## Mevcut tahtadaki tüm blokların durumunu Undo yığını için dizi olarak döndürür.
func serialize_board_state() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for coord: Vector2i in _blocks_by_coord.keys():
		var block: ArrowBlock = _blocks_by_coord[coord]
		if is_instance_valid(block):
			snapshot.append({
				"x": coord.x,
				"y": coord.y,
				"color": block.color_id,
				"direction": ArrowBlock.direction_to_string(block.direction)
			})
	return snapshot


## Tahtadaki tüm blok düğümlerini temizler.
func clear_board() -> void:
	for coord: Vector2i in _blocks_by_coord.keys():
		var block: ArrowBlock = _blocks_by_coord[coord]
		if is_instance_valid(block):
			block.queue_free()
	_blocks_by_coord.clear()


## Tüm bloklardaki aktif İpucu (Hint) vurgusunu temizler.
func clear_all_hints() -> void:
	for coord: Vector2i in _blocks_by_coord.keys():
		var block: ArrowBlock = _blocks_by_coord[coord]
		if is_instance_valid(block):
			block.stop_hint_highlight()


## Yolu açık olan bloklar arasından bekleme alanındaki renklere göre en avantajlı bloğu seçer.
func find_best_hint_block(waiting_color_counts: Dictionary) -> ArrowBlock:
	var clear_blocks: Array[ArrowBlock] = []
	var clear_color_tally: Dictionary = {}

	for coord: Vector2i in _blocks_by_coord.keys():
		var block: ArrowBlock = _blocks_by_coord[coord]
		if is_instance_valid(block) and is_exit_path_clear(coord, block.direction):
			clear_blocks.append(block)
			clear_color_tally[block.color_id] = int(clear_color_tally.get(block.color_id, 0)) + 1

	if clear_blocks.is_empty():
		return null

	var best_block: ArrowBlock = clear_blocks[0]
	var best_score: int = -1

	for blk: ArrowBlock in clear_blocks:
		var in_waiting: int = int(waiting_color_counts.get(blk.color_id, 0))
		var available_now: int = int(clear_color_tally.get(blk.color_id, 0))
		# Bekleme alanında 2 adet olan renk anında üçlü eşleşme yapacağı için en yüksek puanı alır
		var score: int = in_waiting * 100 + available_now * 10
		if score > best_score:
			best_score = score
			best_block = blk

	return best_block


## Tahtadaki kalan blokların renklerini ve yönlerini kilitlenme (cycle) oluşturmadan karıştırır.
func shuffle_board_blocks() -> void:
	var coords: Array[Vector2i] = []
	var colors: Array[String] = []
	var dirs: Array[ArrowBlock.Direction] = []

	for coord: Vector2i in _blocks_by_coord.keys():
		var blk: ArrowBlock = _blocks_by_coord[coord]
		if is_instance_valid(blk):
			coords.append(coord)
			colors.append(blk.color_id)
			dirs.append(blk.direction)

	var count: int = coords.size()
	if count <= 1:
		return

	# 1. Renkleri karıştır (eski dizilimle birebir aynı kalmamasını sağla)
	var old_colors: Array[String] = colors.duplicate()
	colors.shuffle()
	if colors == old_colors:
		for i: int in range(1, count):
			if colors[i] != colors[0]:
				var tmp_c: String = colors[0]
				colors[0] = colors[i]
				colors[i] = tmp_c
				break

	# 2. Yönleri karıştır ve topolojik olarak kilitlenmesiz (DAG) olduğunu doğrula
	var chosen_dirs: Array[ArrowBlock.Direction] = dirs.duplicate()
	var found_acyclic: bool = false
	for _attempt: int in range(24):
		var candidate_dirs: Array[ArrowBlock.Direction] = dirs.duplicate()
		candidate_dirs.shuffle()
		if _is_configuration_acyclic(coords, candidate_dirs):
			chosen_dirs = candidate_dirs
			found_acyclic = true
			break

	# Rastgele yön permütasyonları döngü oluşturduysa her bloğu en yakın kenara yönlendir (kesin DAG)
	if not found_acyclic:
		for i: int in range(count):
			chosen_dirs[i] = _get_outward_safe_direction(coords[i])

	# 3. Görsel çevirme (flip) animasyonu ile yeni renk ve yönleri uygula
	for i: int in range(count):
		var blk: ArrowBlock = _blocks_by_coord[coords[i]]
		if is_instance_valid(blk):
			var delay: float = float(i % 6) * 0.025
			blk.play_shuffle_animation(colors[i], chosen_dirs[i], delay)


## Verilen koordinat ve yön eşleşmesinin döngüsel kilitlenme içermediğini doğrular.
func _is_configuration_acyclic(coords: Array[Vector2i], dirs: Array[ArrowBlock.Direction]) -> bool:
	var remaining: Dictionary = {}
	for i: int in range(coords.size()):
		remaining[coords[i]] = dirs[i]

	var progress: bool = true
	while not remaining.is_empty() and progress:
		progress = false
		var removable: Array[Vector2i] = []

		for pos: Vector2i in remaining.keys():
			var d: ArrowBlock.Direction = remaining[pos]
			var step: Vector2i = _direction_to_step(d)
			var check: Vector2i = pos + step
			var blocked: bool = false
			while check.x >= 0 and check.x < grid_width and check.y >= 0 and check.y < grid_height:
				if remaining.has(check):
					blocked = true
					break
				check += step
			if not blocked:
				removable.append(pos)

		for r_pos: Vector2i in removable:
			remaining.erase(r_pos)
			progress = true

	return remaining.is_empty()


## Hücrenin en yakın tahta kenarına bakan yönünü döndürür (her zaman %100 çözülebilirdir).
func _get_outward_safe_direction(pos: Vector2i) -> ArrowBlock.Direction:
	var dist_top: int = pos.y
	var dist_bottom: int = (grid_height - 1) - pos.y
	var dist_left: int = pos.x
	var dist_right: int = (grid_width - 1) - pos.x
	var min_d: int = mini(mini(dist_top, dist_bottom), mini(dist_left, dist_right))

	if min_d == dist_top:
		return ArrowBlock.Direction.UP
	elif min_d == dist_bottom:
		return ArrowBlock.Direction.DOWN
	elif min_d == dist_left:
		return ArrowBlock.Direction.LEFT
	return ArrowBlock.Direction.RIGHT


func _direction_to_step(dir: ArrowBlock.Direction) -> Vector2i:
	match dir:
		ArrowBlock.Direction.UP:
			return Vector2i(0, -1)
		ArrowBlock.Direction.DOWN:
			return Vector2i(0, 1)
		ArrowBlock.Direction.LEFT:
			return Vector2i(-1, 0)
		ArrowBlock.Direction.RIGHT:
			return Vector2i(1, 0)
		_:
			return Vector2i(0, -1)


func _calculate_grid_metrics() -> void:
	var avail_w: float = size.x - BOARD_PADDING * 2.0 - CELL_GAP * float(grid_width - 1)
	var avail_h: float = size.y - BOARD_PADDING * 2.0 - CELL_GAP * float(grid_height - 1)
	cell_size = floorf(minf(avail_w / float(grid_width), avail_h / float(grid_height)))
	cell_size = clampf(cell_size, 56.0, 108.0)

	var total_w: float = cell_size * float(grid_width) + CELL_GAP * float(grid_width - 1)
	var total_h: float = cell_size * float(grid_height) + CELL_GAP * float(grid_height - 1)
	grid_origin = (size - Vector2(total_w, total_h)) * 0.5


func _spawn_block_at(coord: Vector2i, color_id: String, dir_str: String) -> void:
	if coord.x < 0 or coord.x >= grid_width or coord.y < 0 or coord.y >= grid_height:
		push_warning("Tahta sınırları dışında blok koordinatı atlandı: " + str(coord))
		return

	var block: ArrowBlock = ARROW_BLOCK_SCENE.instantiate() as ArrowBlock
	add_child(block)
	block.setup(coord, color_id, dir_str, Vector2(cell_size, cell_size))
	block.position = grid_to_local_pos(coord)
	block.block_clicked.connect(_on_block_clicked)
	_blocks_by_coord[coord] = block


func grid_to_local_pos(coord: Vector2i) -> Vector2:
	return grid_origin + Vector2(
		float(coord.x) * (cell_size + CELL_GAP),
		float(coord.y) * (cell_size + CELL_GAP)
	)


func is_exit_path_clear(start_coord: Vector2i, dir: ArrowBlock.Direction) -> bool:
	var step: Vector2i = _direction_to_step(dir)
	var check_coord: Vector2i = start_coord + step
	while check_coord.x >= 0 and check_coord.x < grid_width and check_coord.y >= 0 and check_coord.y < grid_height:
		if _blocks_by_coord.has(check_coord):
			return false
		check_coord += step
	return true


func detach_block_from_grid(block: ArrowBlock) -> void:
	block.stop_hint_highlight()
	if _blocks_by_coord.has(block.grid_pos) and _blocks_by_coord[block.grid_pos] == block:
		_blocks_by_coord.erase(block.grid_pos)


func get_remaining_block_count() -> int:
	return _blocks_by_coord.size()


func _on_block_clicked(block: ArrowBlock) -> void:
	block_selected.emit(block)


func _draw() -> void:
	var board_box: StyleBoxFlat = StyleBoxFlat.new()
	board_box.bg_color = Color(0.117647, 0.160784, 0.231373, 1.0)
	board_box.set_corner_radius_all(24)
	board_box.border_color = Color(0.20, 0.27, 0.38, 1.0)
	board_box.set_border_width_all(3)
	draw_style_box(board_box, Rect2(Vector2.ZERO, size))

	var cell_box: StyleBoxFlat = StyleBoxFlat.new()
	cell_box.bg_color = Color(0.082353, 0.117647, 0.180392, 1.0)
	cell_box.set_corner_radius_all(14)

	for y: int in range(grid_height):
		for x: int in range(grid_width):
			var c_pos: Vector2 = grid_to_local_pos(Vector2i(x, y))
			draw_style_box(cell_box, Rect2(c_pos, Vector2(cell_size, cell_size)))