extends CharacterBody3D
class_name MovementController3D

signal stepped
signal landed
signal jumped

@export_group("Movement")
@export var gravity_multiplier := 3.0
@export var speed := 10
@export var acceleration := 8
@export var deceleration := 10
@export_range(0.0, 1.0, 0.05) var air_control := 0.3

@export_group("Sprint")
@export var sprint_speed_multiplier := 1.6
@export var fov_multiplier := 1.05

@export_group("Jump")
@export var jump_height := 10

@export_group("Footsteps")
@export var step_lengthen = 0.7
@export var step_interval : float = 8

@export_group("Inputs")
@export var input_back := "move_backward"
@export var input_forward := "move_forward"
@export var input_left := "move_left"
@export var input_right := "move_right"
@export var input_sprint := "move_sprint"
@export var input_jump := "move_jump"

var camera_path := NodePath("Head/Camera")
var head_bob_path := NodePath("Head/Head Bob")

var direction := Vector3()
var input_axis := Vector2()
var step_cycle : float = 0
var next_step : float = 0
var horizontal_velocity
# Get the gravity from the project settings to be synced with RigidDynamicBody nodes.
@onready var gravity: float = (ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_multiplier)
@onready var head_bob: HeadBob = get_node(head_bob_path)
@onready var camera: Camera3D = get_node(camera_path)
@onready var normal_speed: int = speed
@onready var normal_fov: float = camera.fov

var _last_is_on_floor := false

func _ready():
	head_bob.setup_bob(step_interval * 2);

# Called every physics tick. 'delta' is constant
func _physics_process(_delta: float) -> void:
	input_axis = Input.get_vector(input_back, input_forward, input_left, input_right)
	
	_direction_input()
	_check_landed()
	_jump_and_gravity(_delta)
	_accelerate(_delta)
	
	move_and_slide()
	horizontal_velocity = Vector3(velocity.x,0.0,velocity.z)
	
	_check_step(_delta)
	_check_sprint(_delta)
	_check_head_bob(_delta)
	
func _check_landed():
	if is_on_floor() and !_last_is_on_floor:
		emit_signal("landed")
		reset_step()
#		head_bob.reset()
	_last_is_on_floor = is_on_floor()
	
func _check_step(_delta):
	if is_step(horizontal_velocity.length(), is_on_floor(), _delta):
		_step(is_on_floor())

func _jump_and_gravity(_delta):
	if is_on_floor():
		if Input.is_action_just_pressed(input_jump):
			velocity.y = jump_height
			emit_signal("jumped")
			head_bob.do_bob_jump()
			head_bob.reset()
	else:
		velocity.y -= gravity * _delta

func _direction_input() -> void:
	direction = Vector3()
	var aim: Basis = get_global_transform().basis
	if input_axis.x >= 0.5:
		direction -= aim.z
	if input_axis.x <= -0.5:
		direction += aim.z
	if input_axis.y <= -0.5:
		direction -= aim.x
	if input_axis.y >= 0.5:
		direction += aim.x
	direction.y = 0
	direction = direction.normalized()
	
	
func _check_sprint(_delta):
	if can_sprint():
		speed = normal_speed * sprint_speed_multiplier
		camera.set_fov(lerp(camera.fov, normal_fov * fov_multiplier, _delta * 8))
	else:
		speed = normal_speed
		camera.set_fov(lerp(camera.fov, normal_fov, _delta * 8))

func _accelerate(delta: float) -> void:
	# Using only the horizontal velocity, interpolate towards the input.
	var temp_vel := velocity
	temp_vel.y = 0
	
	var temp_accel: float
	var target: Vector3 = direction * speed
	
	if direction.dot(temp_vel) > 0:
		temp_accel = acceleration
	else:
		temp_accel = deceleration
	
	if not is_on_floor():
		temp_accel *= air_control
	
	temp_vel = temp_vel.lerp(target, temp_accel * delta)
	
	velocity.x = temp_vel.x
	velocity.z = temp_vel.z
	
func _step(is_on_floor:bool) -> bool:
	reset_step()
	if(is_on_floor):
		emit_signal("stepped")
		return true
	return false
	
func _check_head_bob(_delta):
	head_bob.head_bob_process(horizontal_velocity, input_axis, can_sprint(), is_on_floor(), _delta)
		
func reset_step():
	next_step = step_cycle + step_interval
	
func can_sprint() -> bool:
	return (is_on_floor() and Input.is_action_pressed(input_sprint) 
			and input_axis.x >= 0.5)
			
func is_step(velocity:float, is_on_floor:bool, _delta:float) -> bool:
	if(abs(velocity) < 0.1):
		return false
	step_cycle = step_cycle + ((velocity + step_lengthen) * _delta)
	if(step_cycle <= next_step):
		return false
	return true
	
