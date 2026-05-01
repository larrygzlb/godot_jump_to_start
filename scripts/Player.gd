extends CharacterBody2D

const SPEED = 200.0
const JUMP_VELOCITY = -550.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	var jump = Input.is_action_just_pressed("ui_accept") \
		or Input.is_action_just_pressed("ui_up")
	if jump and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var move_left = Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A)
	var move_right = Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D)
	var direction = float(move_right) - float(move_left)

	if direction:
		velocity.x = direction * SPEED
		$Sprite2D.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Reset if fallen off the screen
	if position.y > 850:
		position = Vector2(200, 640)
		velocity = Vector2.ZERO

	move_and_slide()
