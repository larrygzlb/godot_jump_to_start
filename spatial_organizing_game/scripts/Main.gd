extends Node2D

const MOVE_SPEED := 260.0
const SNAP_DISTANCE := 42.0
const CLICK_RADIUS := 48.0
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
var target_nodes: Dictionary = {}
var locked_items: Dictionary = {}
var won := false
var is_dragging := false
var drag_offset := Vector2.ZERO

func _ready() -> void:
	for child in items_root.get_children():
		if child is Node2D:
			item_nodes.append(child)
			initial_positions[child.name] = child.position
			# Each item starts unlocked so the player can still experiment with placement.
			locked_items[child.name] = false

	for index in item_nodes.size():
		var item := item_nodes[index]
		# This links each item to exactly one target, so only the matching socket can lock it in.
		target_nodes[item.name] = targets_root.get_node("Target%d" % (index + 1))

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

	_check_for_lock()
	_check_for_win()

func _unhandled_input(event: InputEvent) -> void:
	if won:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			selected_item = _find_clicked_item(event.position)
			if selected_item != null:
				# The drag offset keeps the item under the cursor without snapping its center to the mouse.
				is_dragging = true
				drag_offset = selected_item.position - event.position
			_update_status_text()
		else:
			is_dragging = false
			drag_offset = Vector2.ZERO
			_check_for_lock()
			_check_for_win()
			_update_status_text()

	if event is InputEventMouseMotion and is_dragging and selected_item != null:
		selected_item.position = (event.position + drag_offset).clamp(ITEM_BOUNDS_MIN, ITEM_BOUNDS_MAX)
		_update_status_text()

func _find_clicked_item(mouse_pos: Vector2) -> Node2D:
	for item in item_nodes:
		# Locked items are already solved, so the player should not be able to pick them up again.
		if locked_items[item.name]:
			continue
		if item.position.distance_to(mouse_pos) <= CLICK_RADIUS:
			return item
	return null

func _check_for_lock() -> void:
	if selected_item == null:
		return

	var target := target_nodes.get(selected_item.name) as Node2D
	if target == null:
		return

	# Only the matching target can accept this item, and close placement causes the click-in snap.
	if selected_item.position.distance_to(target.position) <= SNAP_DISTANCE:
		selected_item.position = target.position
		locked_items[selected_item.name] = true
		selected_item = null

func _is_win_state() -> bool:
	for item in item_nodes:
		# Winning now means every piece has clicked into its correct socket and become locked.
		if not locked_items[item.name]:
			return false
	return true

func _on_restart_pressed() -> void:
	for item in item_nodes:
		item.position = initial_positions[item.name]
		locked_items[item.name] = false
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
		status_label.text = "Drag a tool into its matching socket. Correct matches click into place."
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
		status_label.text = "All tools are locked into place. You win!"
		win_panel.visible = true
