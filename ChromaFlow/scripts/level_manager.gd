extends Node
class_name LevelManager
## Seviye JSON dosyalarını yükleyen, 3'lü renk dengesini ve
## yönlü kilitlenme (deadlock) bulunmadığını doğrulayan yönetici sınıf.

const LEVELS_DIR: String = "res://levels/"
const TOTAL_LEVELS: int = 10


## Toplam seviye sayısını döndürür.
func get_total_levels() -> int:
	return TOTAL_LEVELS


## Belirtilen seviye numarasına ait JSON dosyasını okur ve Dictionary olarak döndürür.
func load_level_data(level_number: int) -> Dictionary:
	var clamped_level: int = clampi(level_number, 1, TOTAL_LEVELS)
	var file_path: String = "%slevel_%02d.json" % [LEVELS_DIR, clamped_level]
	if not FileAccess.file_exists(file_path):
		push_error("Seviye dosyası bulunamadı: " + file_path)
		return _get_fallback_level_data(clamped_level)

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Seviye dosyası açılamadı: " + file_path)
		return _get_fallback_level_data(clamped_level)

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(json_text)
	if parse_err != OK:
		push_error("JSON ayrıştırma hatası (%s): %s" % [file_path, json.get_error_message()])
		return _get_fallback_level_data(clamped_level)

	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY or not _validate_level_dictionary(data):
		push_error("Seviye verisi geçersiz veya çözümsüz: " + file_path)
		return _get_fallback_level_data(clamped_level)

	return data


## Seviye verisinin şemasını, 3'ün katı renk kuralını ve DAG çözülebilirliğini doğrular.
func _validate_level_dictionary(data: Dictionary) -> bool:
	if not data.has("grid_width") or not data.has("grid_height") or not data.has("blocks"):
		return false

	var gw: int = int(data["grid_width"])
	var gh: int = int(data["grid_height"])
	if gw <= 0 or gh <= 0 or typeof(data["blocks"]) != TYPE_ARRAY:
		return false

	var blocks: Array = data["blocks"]
	if blocks.is_empty() or blocks.size() % 3 != 0:
		push_error("Blok sayısı 3'ün katı olmalıdır!")
		return false

	var coord_map: Dictionary = {}
	var color_counts: Dictionary = {}

	for idx: int in range(blocks.size()):
		var b: Dictionary = blocks[idx]
		var pos: Vector2i = Vector2i(int(b.get("x", -1)), int(b.get("y", -1)))
		if pos.x < 0 or pos.x >= gw or pos.y < 0 or pos.y >= gh:
			push_error("Sınır dışı blok koordinatı: " + str(pos))
			return false
		if coord_map.has(pos):
			push_error("Çakışan blok koordinatı: " + str(pos))
			return false

		coord_map[pos] = idx
		var col: String = str(b.get("color", "red"))
		color_counts[col] = int(color_counts.get(col, 0)) + 1

	for col_key: String in color_counts.keys():
		if int(color_counts[col_key]) % 3 != 0:
			push_error("Renk sayısı 3'ün katı değil (%s: %d)" % [col_key, color_counts[col_key]])
			return false

	# Karşılıklı kilitlenme (cycle) kontrolü: Her blok bir aşamada dışarı çıkabilmeli.
	if not _is_board_acyclic(blocks, coord_map, gw, gh):
		push_error("Seviye tahtasında karşılıklı kilitlenen ok döngüsü tespit edildi!")
		return false

	return true


## Kahn topolojik sıralama mantığıyla tahtada birbirini sonsuza dek kilitleyen oklar olmadığını doğrular.
func _is_board_acyclic(blocks: Array, coord_map: Dictionary, gw: int, gh: int) -> bool:
	var remaining: Dictionary = coord_map.duplicate()
	var progress: bool = true

	while not remaining.is_empty() and progress:
		progress = false
		var removable_coords: Array[Vector2i] = []

		for pos: Vector2i in remaining.keys():
			var b_idx: int = int(remaining[pos])
			var b_data: Dictionary = blocks[b_idx]
			var step: Vector2i = _dir_string_to_vec(str(b_data.get("direction", "up")))

			var check: Vector2i = pos + step
			var blocked: bool = false
			while check.x >= 0 and check.x < gw and check.y >= 0 and check.y < gh:
				if remaining.has(check):
					blocked = true
					break
				check += step

			if not blocked:
				removable_coords.append(pos)

		for r_pos: Vector2i in removable_coords:
			remaining.erase(r_pos)
			progress = true

	return remaining.is_empty()


func _dir_string_to_vec(dir_str: String) -> Vector2i:
	match dir_str.to_lower():
		"up":
			return Vector2i(0, -1)
		"down":
			return Vector2i(0, 1)
		"left":
			return Vector2i(-1, 0)
		"right":
			return Vector2i(1, 0)
		_:
			return Vector2i(0, -1)


## Dosya okuma hatası durumunda oyunun çökmemesi için yedek test seviyesi döndürür.
func _get_fallback_level_data(level_number: int) -> Dictionary:
	return {
		"level_id": level_number,
		"level_name": "Yedek Seviye",
		"grid_width": 5,
		"grid_height": 5,
		"blocks": [
			{ "x": 1, "y": 0, "color": "red", "direction": "up" },
			{ "x": 2, "y": 0, "color": "blue", "direction": "up" },
			{ "x": 3, "y": 0, "color": "red", "direction": "up" },
			{ "x": 2, "y": 1, "color": "red", "direction": "up" },
			{ "x": 0, "y": 2, "color": "blue", "direction": "left" },
			{ "x": 4, "y": 2, "color": "blue", "direction": "right" }
		]
	}