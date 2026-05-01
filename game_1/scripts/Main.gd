extends Node2D

const MOVE_SPEED := 260.0
const SNAP_DISTANCE := 28.0
const ITEM_BOUNDS_MIN := Vector2(80, 90)
const ITEM_BOUNDS_MAX := Vector2(1200, 660)

@onready var items_root: Node2D = $World/Items
@onready var targets_root: Node2D = $World/Targets
@onready var status_label: Label = $UI/Status
@onready var win_panel: Panel = $UI/WinPanel
@onready var restart_button: Button = $UI/WinPanel/RestartButton
@onready var end_button: Button = $UI/WinPanel/EndButton

var selected_item: Node2D = null
var item_nodes: Array[Node2D] = []
var initial_positions: Dictionary = {}
var won := false
var is_dragging := false
var drag_offset := Vector2.ZERO

func _ready() -> void:
	for child in items_root.get_children():
		if child is Node2D:
			item_nodes.append(child)
			initial_positions[child.name] = child.position

	restart_button.pressed.connect(_on_restart_pressed)
	end_button.pressed.connect(_on_end_pressed)
	win_panel.visible = false
	_update_status_text()

func _process(delta: float) -> void:
	if won or selected_item == null or is_dragging:
		return

	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		selected_item.position += direction * MOVE_SPEED * delta
		selected_item.position = selected_item.position.clamp(ITEM_BOUNDS_MIN, ITEM_BOUNDS_MAX)

	_check_for_win()

func _unhandled_input(event: InputEvent) -> void:
	if won:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			selected_item = _find_clicked_item(event.position)
			if selected_item != null:
				is_dragging = true
				drag_offset = selected_item.position - event.position
			_update_status_text()
		else:
			is_dragging = false
			drag_offset = Vector2.ZERO
			_check_for_win()

	if event is InputEventMouseMotion and is_dragging and selected_item != null:
		selected_item.position = (event.position + drag_offset).clamp(ITEM_BOUNDS_MIN, ITEM_BOUNDS_MAX)
		_update_status_text()

func _find_clicked_item(mouse_pos: Vector2) -> Node2D:
	for item in item_nodes:
		if item.position.distance_to(mouse_pos) <= 30.0:
			return item
	return null

func _is_win_state() -> bool:
	for i in item_nodes.size():
		var item := item_nodes[i]
		var target := targets_root.get_node("Target%d" % (i + 1)) as Node2D
		if item.position.distance_to(target.position) > SNAP_DISTANCE:
			return false
	return true

func _on_restart_pressed() -> void:
	for item in item_nodes:
		item.position = initial_positions[item.name]
	won = false
	selected_item = null
	is_dragging = false
	drag_offset = Vector2.ZERO
	win_panel.visible = false
	_update_status_text()

func _on_end_pressed() -> void:
	get_tree().quit()

func _update_status_text() -> void:
	if selected_item == null:
		status_label.text = "Drag an item with mouse, or click to select then move with Arrow keys or WASD."
	elif is_dragging:
		status_label.text = "Dragging: %s" % selected_item.name
	else:
		status_label.text = "Selected: %s" % selected_item.name

func _check_for_win() -> void:
	if _is_win_state():
		won = true
		selected_item = null
		is_dragging = false
		drag_offset = Vector2.ZERO
		status_label.text = "All items are in place. You win!"
		win_panel.visible = true
