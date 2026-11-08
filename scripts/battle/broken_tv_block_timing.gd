extends BlockTiming
## Block timing bar for the Broken TV fight.

var _triangle_indices: Array[int] = []

var triangle_squares_enabled: bool = false
var triangle_count: int = 5
var triangle_multiplier: float = 1.2
var triangle_color: Color = Color.RED


func start() -> void:
	super.start()
	_setup_triangles()
	queue_redraw()


func _setup_triangles() -> void:
	_triangle_indices.clear()

	if not triangle_squares_enabled:
		return

	var count: int = _resolved_square_count()
	if count <= 0:
		return

	var candidates: Array[int] = []

	for i in range(count):
		candidates.append(i)

	candidates.shuffle()

	var num_triangles: int = clampi(triangle_count, 1, count)

	for i in range(num_triangles):
		_triangle_indices.append(candidates[i])


func _draw() -> void:
	super._draw()

	if not triangle_squares_enabled:
		return

	var count: int = _resolved_square_count()

	if count <= 0 or _triangle_indices.is_empty():
		return

	var cell_width: float = size.x / float(count)
	var gap: float = clampf(
		square_gap,
		0.0,
		minf(cell_width, size.y) * 0.45
	)

	var block_size := Vector2(
		maxf(cell_width - gap, 1.0),
		maxf(size.y - gap, 1.0)
	)

	var block_top: float = (size.y - block_size.y) * 0.5

	for i in range(_triangle_indices.size()):
		var index: int = _triangle_indices[i]

		var block_left: float = float(index) * cell_width + gap * 0.5

		var center := Vector2(
			block_left + block_size.x * 0.5,
			block_top + block_size.y * 0.5
		)

		var radius: float = minf(block_size.x, block_size.y) * 0.35

		var points := PackedVector2Array([
			center + Vector2(0, -radius),
			center + Vector2(-radius, radius),
			center + Vector2(radius, radius)
		])

		draw_colored_polygon(points, triangle_color)


func _finish(result: Dictionary) -> void:
	if triangle_squares_enabled and not _triangle_indices.is_empty():
		var count: int = _resolved_square_count()

		if count > 0:
			var active_index: int = clampi(
				int(marker_position * float(count)),
				0,
				count - 1
			)

			if _triangle_indices.has(active_index):
				var reduction: float = float(result.get("value", 0.0))
				result["value"] = clampf(reduction / triangle_multiplier, 0.0, 1.0)

	super._finish(result)