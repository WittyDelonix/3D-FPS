extends Node3D

signal moved(velocity: Vector3, grounded: bool)

@export_category("Movement")
@export var jump_force = 14.0
@export var gravity = 25.0
@export var max_speed = 15.0
@export var move_accel = 5.0
@export var stop_drag = 0.11
@export var air_drag = 0.19
@export_range(5, 10, 0.1) var crouch_speed = 0.7
@export var crouch_movement_speed_modifier = 0.6
@export var min_slide_speed = 10.0
@export var slide_speed_modifier = 1.5

@export_category("Sound")
@export var footstep_sound_interval = 0.3
@export var min_pitch_scale = 0.9
@export var max_pitch_scale = 1.0


var character_body: CharacterBody3D
var move_dir: Vector3
var current_speed = 0.0
var double_jump_available = true
var is_crouching = false
var is_sliding = false
var is_in_air = false
var slide_timer: Timer
var last_footstep_time = -9999.0
var frames_in_air = 0

@onready var jump_sounds = $Audio/JumpSounds.get_children()
@onready var footstep_sounds = $Audio/FootstepSounds.get_children()
@onready var landing_small_sounds = $Audio/LandingSmallSounds.get_children()
@onready var landing_big_sounds = $Audio/LandingBigSounds.get_children()
@onready var player_animations = $"../PlayerAnimations"
@onready var crouch_shape_cast = $"../CrouchShapeCast"
@onready var sliding_sound = $Audio/SlidingSounds/SlidingSound1
@onready var slide_effect = $"../SlideEffect"

func _ready():
	character_body = get_parent()
	crouch_shape_cast.add_exception($"..")

	slide_timer = Timer.new()
	slide_timer.wait_time = 0.7
	slide_timer.one_shot = true
	add_child(slide_timer)
	slide_timer.connect("timeout", Callable(self, "_on_slide_timer_timeout"))

func set_move_dir(new_move_dir: Vector3):
	move_dir = new_move_dir.normalized()

func jump():
	if not is_crouching:
		if character_body.is_on_floor():
			character_body.velocity.y = jump_force
			double_jump_available = true
			play_jump_sound()
			player_animations.play("jump", 0.3)
		elif double_jump_available:
			character_body.velocity.y = jump_force
			double_jump_available = false
			play_jump_sound()
			player_animations.play("jump", 0.3)

func start_crouching():
	if not is_crouching and not crouch_shape_cast.is_colliding():
		is_crouching = true
		if current_speed > min_slide_speed and not is_sliding:
			is_sliding = true
			slide_timer.start()
			play_sliding_sound()
			slide_effect.emitting = true
		else:
			is_sliding = false
			slide_effect.emitting = false
		crouching(true)

func stop_crouching():
	if is_crouching:
		is_crouching = false
		is_sliding = false
		slide_timer.stop()
		stop_sliding_sounds()
		slide_effect.emitting = false
		crouching(false)

func crouching(state: bool):
	if state:
		player_animations.play("crouch", 0, crouch_speed)
	else:
		player_animations.play("crouch", 0, -crouch_speed, true)

func _on_slide_timer_timeout():
	is_sliding = false
	stop_sliding_sounds()
	slide_effect.emitting = false

func _physics_process(delta):
	# Gravity and ceiling hit
	if character_body.velocity.y > 0.0 and character_body.is_on_ceiling():
		character_body.velocity.y = 0.0
	if not character_body.is_on_floor():
		character_body.velocity.y -= gravity * delta

	# Air state and landing logic
	if not character_body.is_on_floor():
		is_in_air = true
		frames_in_air += 1
	else:
		if is_in_air:
			if frames_in_air >= 120:
				player_animations.play("landing_big", 0.3)
				play_big_landing_sound()
			elif frames_in_air >= 2:
				player_animations.play("landing_small", 0.3)
				play_small_landing_sound()
			frames_in_air = 0
		is_in_air = false

	# Determine drag
	var drag = move_accel / max_speed if character_body.is_on_floor() else air_drag
	if move_dir.is_zero_approx():
		drag = stop_drag

	# Adjust acceleration based on crouching/sliding
	var adjusted_move_accel = move_accel
	if is_crouching and character_body.is_on_floor():
		adjusted_move_accel *= slide_speed_modifier if is_sliding else crouch_movement_speed_modifier
	# Movement application
	var flat_velo = character_body.velocity
	flat_velo.y = 0.0
	character_body.velocity += adjusted_move_accel * move_dir - flat_velo * drag

	moved.emit(character_body.velocity, character_body.is_on_floor())

	current_speed = character_body.velocity.length()
	Global.debug.add_property("Movement Speed", current_speed, 1)
	# --- Improved stair climbing ---
	character_body.move_and_slide(
	)
	moved.emit(character_body.velocity, character_body.is_on_floor())
	current_speed = character_body.velocity.length()
	Global.debug.add_property("Movement Speed", current_speed, 1)
	# Footstep logic
	if character_body.is_on_floor() and not move_dir.is_zero_approx():
		var current_time = Time.get_ticks_msec() / 1000.0
		var interval = 0.5 if is_crouching else footstep_sound_interval
		if current_time - last_footstep_time > interval:
			last_footstep_time = current_time
			play_footstep_sound()

# --- Sound Functions ---

func play_footstep_sound():
	var sound = footstep_sounds[randi() % footstep_sounds.size()]
	sound.pitch_scale = randf_range(min_pitch_scale, max_pitch_scale)
	sound.play()

func play_jump_sound():
	jump_sounds[randi() % jump_sounds.size()].play()

func play_small_landing_sound():
	landing_small_sounds[randi() % landing_small_sounds.size()].play()

func play_big_landing_sound():
	landing_big_sounds[randi() % landing_big_sounds.size()].play()

func play_sliding_sound():
	if character_body.is_on_floor():
		sliding_sound.pitch_scale = randf_range(min_pitch_scale, max_pitch_scale)
		sliding_sound.play()

func stop_sliding_sounds():
	if sliding_sound.playing:
		sliding_sound.stop()
