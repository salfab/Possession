class_name CorruptionDots
extends Control
# Tiny visual badge that draws a row of small squares per player to show
# how much Corruption each demon has placed on a Domain. One filled square
# per Corruption, in the player's colour, with a thin black outline. Both
# players' squares share the same row, separated by a small gap.

const DOT_SIZE := 12.0
const DOT_GAP := 2.0
const GROUP_GAP := 6.0

var red_count: int = 0
var blue_count: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, DOT_SIZE)


func set_counts(r: int, b: int) -> void:
	if r == red_count and b == blue_count:
		return
	red_count = r
	blue_count = b
	# Recalculate width so the parent container can size us correctly.
	var total := r + b
	var w := total * DOT_SIZE + maxi(total - 1, 0) * DOT_GAP
	if r > 0 and b > 0:
		w += GROUP_GAP - DOT_GAP
	custom_minimum_size = Vector2(w, DOT_SIZE)
	queue_redraw()


func _draw() -> void:
	var x: float = 0.0
	var y: float = (size.y - DOT_SIZE) * 0.5
	var red: Color = GameEnums.PLAYER_COLORS[GameEnums.PlayerId.RED]
	var blue: Color = GameEnums.PLAYER_COLORS[GameEnums.PlayerId.PURPLE]
	for i in red_count:
		var rect := Rect2(x, y, DOT_SIZE, DOT_SIZE)
		draw_rect(rect, red, true)
		draw_rect(rect, Color(0, 0, 0, 0.85), false, 1.5)
		x += DOT_SIZE + DOT_GAP
	if red_count > 0 and blue_count > 0:
		x += GROUP_GAP - DOT_GAP
	for i in blue_count:
		var rect := Rect2(x, y, DOT_SIZE, DOT_SIZE)
		draw_rect(rect, blue, true)
		draw_rect(rect, Color(0, 0, 0, 0.85), false, 1.5)
		x += DOT_SIZE + DOT_GAP
