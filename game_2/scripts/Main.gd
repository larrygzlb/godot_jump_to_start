extends Node2D
# Main.gd — Controls all gameplay for the tool-matching puzzle.
# The player drags 6 tool items (left panel) to matching sockets (right panel).
# When a tool is close enough to its target socket, it snaps in and locks.
# Win when all 6 tools are locked.

# ─── Constants ────────────────────────────────────────────────────────────────

## How many pixels per second the selected item moves when using keyboard arrows.
const MOVE_SPEED: float = 260.0

## How close (pixels) the item's center must be to a socket center to snap & lock.
const SNAP_DISTANCE: float = 42.0

## Mouse click radius — clicking within this distance of an item's center selects it.
const CLICK_RADIUS: float = 48.0

## Bounds that keep keyboard-moved items inside the play area.
const ITEM_BOUNDS_MIN := Vector2(80.0, 90.0)
const ITEM_BOUNDS_MAX := Vector2(1200.0, 660.0)

# ─── State variables ──────────────────────────────────────────────────────────

## The item node currently held / selected by the player (null if none).
var selected_item: Node2D = null

## All draggable item nodes gathered from the scene tree in _ready().
var item_nodes: Array[Node2D] = []

## Original positions of each item, keyed by item name. Used for restart.
var initial_positions: Dictionary = {}

## Maps each item NAME → its matching TARGET node (e.g. "ItemHammer" → Target1 node).
var target_nodes: Dictionary = {}

## Tracks whether each item is locked into its socket. Key = item name, value = bool.
var locked_items: Dictionary = {}

## True once all items are locked (win state reached).
var won: bool = false

## True while the player is actively dragging with the mouse.
var is_dragging: bool = false

## Offset from the item's origin to where the mouse grabbed it, so the item
## doesn't "jump" to center when clicked.
var drag_offset: Vector2 = Vector2.ZERO

# ─── Node references (filled in _ready) ───────────────────────────────────────
@onready var status_label: Label = $UI/Status
@onready var win_panel: Control  = $UI/WinPanel

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# --- Collect all item nodes from the World/Items group ----------------
	# Each child of World/Items is one draggable tool.
	for item in $World/Items.get_children():
		var item_node := item as Node2D
		item_nodes.append(item_node)
		initial_positions[item_node.name] = item_node.position
		locked_items[item_node.name] = false   # start unlocked

	# --- Build the name→target mapping ------------------------------------
	# The order here must match the order Godot returns children in the
	# World/Items group (same order as they appear in the .tscn file).
	var target_names := ["Target1", "Target2", "Target3", "Target4", "Target5", "Target6"]
	for i in item_nodes.size():
		var target_node := $World/Targets.get_node(target_names[i]) as Node2D
		target_nodes[item_nodes[i].name] = target_node

	# --- Connect UI buttons -----------------------------------------------
	$UI/WinPanel/RestartButton.pressed.connect(_on_restart_pressed)
	$UI/WinPanel/EndButton.pressed.connect(_on_end_pressed)

	# Hide the win panel until the player wins.
	win_panel.hide()
	_update_status_text()

# ─── Per-frame update ─────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Keyboard movement: only active when an item is selected but NOT being mouse-dragged.
	if selected_item != null and not is_dragging:
		# get_vector returns a Vector2 in range (-1,-1)..(1,1) based on held keys.
		var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if dir != Vector2.ZERO:
			selected_item.position += dir * MOVE_SPEED * delta
			# Clamp so the item stays within the defined play area.
			selected_item.position = selected_item.position.clamp(ITEM_BOUNDS_MIN, ITEM_BOUNDS_MAX)
			_check_for_lock()
			_check_for_win()

	_update_status_text()

# ─── Input handling ───────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	# --- Mouse button pressed: try to grab an item ------------------------
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# Find the closest unlocked item under the cursor.
				selected_item = _find_clicked_item(mb.position)
				if selected_item != null:
					is_dragging = true
					# Record offset so the item doesn't snap its centre to the cursor.
					drag_offset = selected_item.position - mb.position
			else:
				# Mouse released: drop the item.
				is_dragging = false
				if selected_item != null:
					_check_for_lock()
					_check_for_win()
				# Don't clear selected_item — keyboard movement stays active.

	# --- Mouse motion: move the held item with the cursor -----------------
	elif event is InputEventMouseMotion and is_dragging and selected_item != null:
		var mm := event as InputEventMouseMotion
		selected_item.position = mm.position + drag_offset
		selected_item.position = selected_item.position.clamp(ITEM_BOUNDS_MIN, ITEM_BOUNDS_MAX)

# ─── Helper: find which item the player clicked ───────────────────────────────

func _find_clicked_item(mouse_pos: Vector2) -> Node2D:
	# Walk all items in reverse draw order (top-most first) to pick the visually
	# top item when items overlap.
	var best: Node2D = null
	var best_dist: float = CLICK_RADIUS

	for item in item_nodes:
		# Skip items that are already locked — they can't be moved.
		if locked_items[item.name]:
			continue
		var dist := item.position.distance_to(mouse_pos)
		if dist <= best_dist:
			best_dist = dist
			best = item

	return best

# ─── Helper: snap & lock if item is close enough to its socket ───────────────

func _check_for_lock() -> void:
	if selected_item == null:
		return
	if locked_items[selected_item.name]:
		return   # already locked, nothing to do

	# Look up this item's matching socket node.
	var target: Node2D = target_nodes[selected_item.name]
	var dist := selected_item.position.distance_to(target.position)

	if dist <= SNAP_DISTANCE:
		# Snap the item exactly onto the socket centre.
		selected_item.position = target.position
		# Mark as locked so it can't be dragged again.
		locked_items[selected_item.name] = true
		# Release selection so the player can't accidentally move it.
		selected_item = null
		is_dragging = false

# ─── Helper: check whether all items are locked (win condition) ───────────────

func _check_for_win() -> void:
	if won:
		return
	if _is_win_state():
		won = true
		win_panel.show()

func _is_win_state() -> bool:
	# Every item must have its locked flag set to true.
	for item in item_nodes:
		if not locked_items[item.name]:
			return false
	return true

# ─── UI callbacks ─────────────────────────────────────────────────────────────

func _on_restart_pressed() -> void:
	# Reset every item to where it started and unlock all.
	for item in item_nodes:
		item.position = initial_positions[item.name]
		locked_items[item.name] = false
	selected_item = null
	is_dragging   = false
	won           = false
	win_panel.hide()
	_update_status_text()

func _on_end_pressed() -> void:
	# Close the game window.
	get_tree().quit()

# ─── Status label ─────────────────────────────────────────────────────────────

func _update_status_text() -> void:
	if selected_item == null:
		status_label.text = "Click a tool to select it"
	elif is_dragging:
		status_label.text = "Dragging: " + selected_item.name
	else:
		status_label.text = "Selected: " + selected_item.name + "  (arrow keys or drag)"
