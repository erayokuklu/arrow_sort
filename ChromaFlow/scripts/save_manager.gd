extends Node
class_name SaveManager
## Oyuncu ilerlemesini, en iyi hamle rekorlarını ve ses ayarını user://chroma_flow_save.cfg altında saklar.

const SAVE_FILE_PATH: String = "user://chroma_flow_save.cfg"
const SECTION_PROGRESS: String = "progress"
const SECTION_SETTINGS: String = "settings"
const SECTION_RECORDS: String = "records"

var max_unlocked_level: int = 1
var last_played_level: int = 1
var sound_enabled: bool = true
var best_moves_by_level: Dictionary = {}


func _ready() -> void:
	load_game_data()


func load_game_data() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(SAVE_FILE_PATH)
	if err != OK:
		save_game_data()
		return

	max_unlocked_level = int(config.get_value(SECTION_PROGRESS, "max_unlocked_level", 1))
	last_played_level = int(config.get_value(SECTION_PROGRESS, "last_played_level", 1))
	sound_enabled = bool(config.get_value(SECTION_SETTINGS, "sound_enabled", true))
	best_moves_by_level = config.get_value(SECTION_RECORDS, "best_moves_by_level", {})


func save_game_data() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION_PROGRESS, "max_unlocked_level", max_unlocked_level)
	config.set_value(SECTION_PROGRESS, "last_played_level", last_played_level)
	config.set_value(SECTION_SETTINGS, "sound_enabled", sound_enabled)
	config.set_value(SECTION_RECORDS, "best_moves_by_level", best_moves_by_level)

	var err: Error = config.save(SAVE_FILE_PATH)
	if err != OK:
		push_error("Kayıt dosyası yazılamadı: " + str(err))


func record_level_completed(level_number: int, moves_count: int, total_levels: int) -> void:
	if level_number >= max_unlocked_level and level_number < total_levels:
		max_unlocked_level = level_number + 1

	var key: String = str(level_number)
	if not best_moves_by_level.has(key) or moves_count < int(best_moves_by_level[key]):
		best_moves_by_level[key] = moves_count

	save_game_data()


func set_last_played_level(level_number: int) -> void:
	last_played_level = clampi(level_number, 1, max_unlocked_level)
	save_game_data()


func is_level_completed(level_number: int) -> bool:
	return best_moves_by_level.has(str(level_number))


func get_completed_levels_count() -> int:
	return best_moves_by_level.size()


func get_best_moves(level_number: int) -> int:
	var key: String = str(level_number)
	if best_moves_by_level.has(key):
		return int(best_moves_by_level[key])
	return 0


func set_sound_enabled(enabled: bool) -> void:
	sound_enabled = enabled
	save_game_data()


## Tüm seviye kilitlerini ve hamle rekorlarını sıfırlar (ses tercihini korur).
func reset_progress() -> void:
	max_unlocked_level = 1
	last_played_level = 1
	best_moves_by_level.clear()
	save_game_data()