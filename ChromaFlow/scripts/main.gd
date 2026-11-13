extends Control
## Uygulama giriş noktası. Ana Menü (MainMenu) ile Oyun (Game) sahnesi arasındaki
## ekran geçişlerini ve ortak SaveManager/SoundManager paylaşımını yönetir.

@onready var game_node: GameManager = $Game
@onready var main_menu: MainMenu = $MainMenu


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	main_menu.play_requested.connect(_on_menu_play_requested)
	main_menu.level_selected.connect(_on_menu_level_selected)
	main_menu.sound_toggled.connect(_on_menu_sound_toggled)
	main_menu.reset_progress_requested.connect(_on_menu_reset_requested)

	game_node.return_to_menu_requested.connect(_on_return_to_menu_requested)

	_show_main_menu()


func _show_main_menu() -> void:
	game_node.visible = false
	main_menu.visible = true
	main_menu.refresh_menu_state(
		game_node.save_manager,
		game_node.level_manager.get_total_levels()
	)


func _on_menu_play_requested() -> void:
	game_node.sound_manager.play_sfx("button")
	main_menu.visible = false
	game_node.visible = true
	game_node.start_from_saved_progress()


func _on_menu_level_selected(level_number: int) -> void:
	game_node.sound_manager.play_sfx("button")
	main_menu.visible = false
	game_node.visible = true
	game_node.start_game(level_number)


func _on_menu_sound_toggled() -> void:
	game_node.toggle_sound_setting()
	main_menu.refresh_menu_state(
		game_node.save_manager,
		game_node.level_manager.get_total_levels()
	)


func _on_menu_reset_requested() -> void:
	game_node.sound_manager.play_sfx("undo")
	game_node.save_manager.reset_progress()
	main_menu.refresh_menu_state(
		game_node.save_manager,
		game_node.level_manager.get_total_levels()
	)


func _on_return_to_menu_requested() -> void:
	game_node.sound_manager.play_sfx("button")
	_show_main_menu()
