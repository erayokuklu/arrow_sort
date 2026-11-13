extends Control
class_name WaitingSlot
## Bekleme alanındaki 7 yuvadan her birinin görsel çerçevesini çizen bileşen.

var slot_index: int = 0
var is_occupied: bool = false


func _ready() -> void:
	queue_redraw()


func set_occupied(occupied: bool) -> void:
	is_occupied = occupied
	queue_redraw()


func _draw() -> void:
	var slot_box: StyleBoxFlat = StyleBoxFlat.new()
	slot_box.bg_color = Color(0.082, 0.118, 0.180, 1.0) if not is_occupied else Color(0.13, 0.18, 0.27, 1.0)
	slot_box.set_corner_radius_all(14)
	slot_box.border_color = Color(0.24, 0.32, 0.45, 1.0)
	slot_box.set_border_width_all(2)
	draw_style_box(slot_box, Rect2(Vector2.ZERO, size))