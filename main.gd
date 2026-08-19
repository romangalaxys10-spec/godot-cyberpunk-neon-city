extends Node3D

const RACE_DISTANCE := 2000.0
const ROAD_HALF_WIDTH := 5.4
const CITY_GRID := 64.0
const CITY_SPAN := 3584.0
const CITY_HALF := CITY_SPAN * 0.5
const CITY_ROAD_COUNT := int(CITY_SPAN / CITY_GRID) + 1
const CITY_CORRIDOR_HALF := ROAD_HALF_WIDTH + 4.8
const TRAFFIC_COUNT := 72
const PEDESTRIAN_COUNT := 72
const STRIPE_COUNT := 192
const POLE_COUNT := 128
const TREE_COUNT := 96
const MAX_COPS := 7
const RAIN_COUNT := 520
const CLOUD_COUNT := 12
const STAR_COUNT := 140
const MIX_RATE := 22050

var elapsed := 0.0
var countdown := 3.999
var race_state := "countdown"  # countdown, racing, busted, wrecked, finished
var paused := false
var distance := 0.0
var best_time := INF
var auto_quit_at := -1.0
var screenshot_path := ""
var debug_drive := false
var no_audio := false
var center_timer := 0.75
var perf_time := 0.0
var perf_frames := 0

# Vehicle state
var vel := Vector3.ZERO
var yaw := 0.0
var steer := 0.0
var rpm := 900.0
var gear := 1
var damage := 0.0
var boost_charge := 100.0
var boosting := false
var slip := 0.0
var lateral_g := 0.0
var accel_g := 0.0
var shake := 0.0

# Pursuit state
var heat := 1
var pursuit := 0.0
var busted_timer := 0.0
var evade_timer := 0.0
var police_timer := 4.0
var near_miss_pending := {}


# GTA 6 Physics & Camera state
var body_roll := 0.0
var body_pitch := 0.0
var suspension_bounce := 0.0
var burnout_mode := false
var camera_mode := "chase" # chase, hood
var front_wheel_pivots: Array[Node3D] = []
var wheel_rollers: Array[Node3D] = []
var rear_wheel_rollers: Array[Node3D] = []
var front_wheel_rollers: Array[Node3D] = []

var camera: Camera3D
var car: Node3D
var car_body: MeshInstance3D
var boost_flame: MeshInstance3D
var headlight: SpotLight3D
var brake_lights: Array[MeshInstance3D] = []
var traffic_mm: MultiMesh
var traffic_cabin_mm: MultiMesh
var traffic_front_light_mm: MultiMesh
var traffic_rear_light_mm: MultiMesh
var traffic: Array[Dictionary] = []
var building_nodes: Array[Node3D] = []
var building_chunks: Array[Node3D] = []
var arch_nodes: Array[Node3D] = []
var stripe_mm: MultiMesh
var pole_mm: MultiMesh
var lamp_head_mm: MultiMesh
var rain_mm: MultiMesh
var cloud_mm: MultiMesh
var star_mm: MultiMesh
var cloud_offsets: Array[Vector3] = []
var star_offsets: Array[Vector3] = []
var tree_trunk_mm: MultiMesh
var tree_canopy_mm: MultiMesh
var pedestrian_body_mm: MultiMesh
var pedestrian_head_mm: MultiMesh
var pedestrian_leg_mm: MultiMesh
var pedestrian_arm_mm: MultiMesh
var pedestrians: Array[Dictionary] = []
var aircraft: Array[Dictionary] = []
var plane_strobe_mat: StandardMaterial3D
var moon_node: MeshInstance3D
var light_mode := true
var sky_mat: ProceduralSkyMaterial
var world_env: Environment
var main_dir_light: DirectionalLight3D
var fill_dir_light: DirectionalLight3D
var building_materials: Array[StandardMaterial3D] = []
var roof_water_mat: StandardMaterial3D
var roof_mech_mat: StandardMaterial3D
var landmark_nodes: Array[Node3D] = []
var landmark_bases: Array[Vector3] = []
var rain_ox := PackedFloat32Array()
var rain_oz := PackedFloat32Array()
var rain_y0 := PackedFloat32Array()
var cops: Array[Dictionary] = []
var cop_light_a: StandardMaterial3D
var cop_light_b: StandardMaterial3D
var current_district := ""

# HUD
var hud_speed: Label
var hud_gear: Label
var hud_time: Label
var hud_distance: Label
var hud_boost: Label
var hud_center: Label
var hud_best: Label
var hud_heat: Label
var hud_damage_label: Label
var speed_bar: ColorRect
var boost_bar: ColorRect
var damage_bar: ColorRect
var pursuit_bar: ColorRect
var pursuit_panel: ColorRect
var flash_rect: ColorRect
var speed_tint: ColorRect

# Audio
var audio_player: AudioStreamPlayer
var audio_pb: AudioStreamGeneratorPlayback
var phase_e := 0.0
var phase_sub := 0.0
var phase_siren := 0.0
var impact_env := 0.0
var thunder_env := 0.0
var skid_level := 0.0
var noise_lpf := 0.0
var lightning_timer := 6.0
var thunder_delay := 0.0

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 2077
	Engine.max_fps = 60
	_read_debug_args()
	_build_environment()
	_build_car()
	_build_world()
	_build_cops()
	_build_hud()
	_build_audio()
	_load_best()
	_reset_race()
	_apply_lighting_mode()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C or event.physical_keycode == KEY_C or event.keycode == KEY_V or event.physical_keycode == KEY_V:
			camera_mode = "hood" if camera_mode == "chase" else "chase"
			_set_center("CAMERA: " + camera_mode.to_upper(), 1.0)
		elif event.keycode == KEY_L or event.physical_keycode == KEY_L:
			light_mode = not light_mode
			_apply_lighting_mode()
			_set_center("LIGHTING: DAYLIGHT (LIGHT MODE)" if light_mode else "LIGHTING: NIGHT (NEON MODE)", 1.2)
		elif event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			paused = not paused
			get_tree().paused = paused
			hud_center.text = "PAUSED" if paused else ""
		elif (event.keycode == KEY_R or event.physical_keycode == KEY_R) and not paused:
			_reset_race()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		paused = not paused
		get_tree().paused = paused
		hud_center.text = "PAUSED" if paused else ""

	if Input.is_action_just_pressed("restart") and not paused:
		_reset_race()

	if Input.is_key_pressed(KEY_F1):
		get_viewport().scaling_3d_scale = 0.5
	elif Input.is_key_pressed(KEY_F2):
		get_viewport().scaling_3d_scale = 0.65
	elif Input.is_key_pressed(KEY_F3):
		get_viewport().scaling_3d_scale = 1.0

	if not paused:
		_update_race(delta)
		_update_world(delta)
		_update_weather(delta)

	_update_hud()
	_audio_process()
	_maybe_auto_quit(delta)


func _read_debug_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("auto-quit="):
			auto_quit_at = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("screenshot="):
			screenshot_path = arg.get_slice("=", 1)
		elif arg == "light" or arg == "light_mode=1" or arg == "light_mode=true":
			light_mode = true
		elif arg == "night" or arg == "light_mode=0" or arg == "light_mode=false":
			light_mode = false
	if OS.has_environment("NEON_AUTO_QUIT"):
		auto_quit_at = OS.get_environment("NEON_AUTO_QUIT").to_float()
	if OS.has_environment("NEON_SCREENSHOT"):
		screenshot_path = OS.get_environment("NEON_SCREENSHOT")
	if OS.has_environment("NEON_AUTO_DRIVE"):
		debug_drive = OS.get_environment("NEON_AUTO_DRIVE") == "1"
	if OS.has_environment("NEON_NO_AUDIO"):
		no_audio = OS.get_environment("NEON_NO_AUDIO") == "1"
	if OS.has_environment("NEON_LIGHT_MODE"):
		light_mode = OS.get_environment("NEON_LIGHT_MODE") == "1"


func _reset_race() -> void:
	elapsed = 0.0
	countdown = 1.5
	race_state = "countdown"
	distance = 0.0
	vel = Vector3.ZERO
	yaw = 0.0
	steer = 0.0
	rpm = 900.0
	gear = 1
	damage = 0.0
	boost_charge = 100.0
	pursuit = 0.0
	busted_timer = 0.0
	evade_timer = 0.0
	heat = 1
	police_timer = 4.0
	shake = 0.0
	impact_env = 0.0
	near_miss_pending.clear()
	car.position = Vector3(0, 0, 0)
	car.rotation = Vector3.ZERO
	camera.position = Vector3(0, 2.8, 7.5)
	_spawn_buildings()
	_spawn_arches()
	_spawn_traffic()
	for cop in cops:
		cop.active = false
		cop.node.visible = false
	_spawn_cops(2)
	hud_center.text = "READY"
	center_timer = 0.75


func _update_race(delta: float) -> void:
	if race_state == "countdown":
		countdown -= delta
		var input_kick := (
			Input.is_action_pressed("accelerate") or Input.is_action_pressed("brake") or
			Input.is_action_pressed("steer_left") or Input.is_action_pressed("steer_right") or
			Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or
			Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D) or
			Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_DOWN) or
			Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_RIGHT)
		)
		if input_kick:
			countdown = 0.0
		var n := int(ceil(countdown))
		hud_center.text = str(n) if n > 0 else "GO!"
		if countdown <= 0.0:
			race_state = "racing"
			hud_center.text = "GO!"
			center_timer = 0.75
		else:
			vel = vel.lerp(Vector3(0, 0, -4), 2.0 * delta)
			car.position += vel * delta
			_update_car_visual(delta)
			return

	if race_state == "racing":
		elapsed += delta

	var driveable := race_state == "racing"

	# Robust multi-source input reading (Direct keys + Actions + Joypad)
	var key_left := Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var key_right := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var key_accel := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var key_brake := Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	var key_handbrake := Input.is_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_action_pressed("handbrake")
	var key_boost := Input.is_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_E) or Input.is_action_pressed("boost")

	var act_throttle := Input.get_action_strength("accelerate")
	var act_brake := Input.get_action_strength("brake")
	var act_steer := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")

	var throttle := (maxf(act_throttle, 1.0 if key_accel else 0.0)) if driveable else 0.0
	var brake := (maxf(act_brake, 1.0 if key_brake else 0.0)) if driveable else 0.0
	var steer_input := act_steer
	if key_left:
		steer_input -= 1.0
	if key_right:
		steer_input += 1.0
	steer_input = clampf(steer_input, -1.0, 1.0)

	# Analog joypad check with safe deadzone
	for pad in Input.get_connected_joypads():
		var joy_x := Input.get_joy_axis(pad, JOY_AXIS_LEFT_X)
		if absf(joy_x) > 0.15:
			steer_input = clampf(steer_input + joy_x, -1.0, 1.0)
		var joy_trig_r := Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT)
		if joy_trig_r > 0.1:
			throttle = maxf(throttle, joy_trig_r)
		var joy_trig_l := Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT)
		if joy_trig_l > 0.1:
			brake = maxf(brake, joy_trig_l)
		break

	var handbrake := (key_handbrake) and driveable

	# Auto-drive debug route support
	if debug_drive and driveable:
		throttle = 1.0
		steer_input = 0.0

	boosting = driveable and key_boost and boost_charge > 0.0 and throttle > 0.0

	if boosting:
		boost_charge = maxf(0.0, boost_charge - 18.0 * delta)
	elif throttle > 0.0:
		boost_charge = minf(100.0, boost_charge + 3.0 * delta)

	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var vf := vel.dot(fwd)
	var vr := vel.dot(right)

	# Burnout detection (W + S held at low speed)
	burnout_mode = (throttle > 0.4 and brake > 0.4 and absf(vf) < 4.0 and driveable)

	# Engine & damage-limited power curve
	var damage_limit := 1.0 - clampf(damage / 100.0, 0.0, 1.0) * 0.25
	var max_speed := (64.0 if boosting else 46.0) * damage_limit
	var engine_power := (32.0 if boosting else 20.0) * damage_limit

	if burnout_mode:
		# Burnout / Donut mode: spin rear wheels, screaming RPM, yaw spin with steer
		rpm = lerpf(rpm, 7200.0 + rng.randf() * 400.0, 12.0 * delta)
		vf = move_toward(vf, 0.0, 10.0 * delta)
		vr = move_toward(vr, 0.0, 10.0 * delta)
		yaw -= steer_input * 3.4 * delta
		skid_level = 0.95
		_add_shake(0.12 * delta)
	else:
		# Normal driving / acceleration / braking / reverse
		if throttle > 0.0:
			if vf < -0.5:
				# Braking while reversing
				vf = move_toward(vf, 0.0, 36.0 * throttle * delta)
			elif vf < max_speed:
				var accel_mult := clampf(1.0 - (vf / max_speed) * 0.5, 0.4, 1.2)
				vf += engine_power * throttle * accel_mult * delta
		elif brake > 0.0:
			if vf > 0.5:
				# Braking while moving forward
				vf = move_toward(vf, 0.0, 38.0 * brake * delta)
			else:
				# Reversing
				vf = move_toward(vf, -12.0, 12.0 * brake * delta)
		else:
			# Coasting natural deceleration
			vf = move_toward(vf, 0.0, 5.0 * delta)

	# Aerodynamic drag
	vf -= vf * absf(vf) * (0.00045 if boosting else 0.00065) * 60.0 * delta

	# Modern Smooth Car Steering Model (GTA 5 / Arcade-Sim Hybrid):
	# Natural non-linear progressive curve for keyboard & controller inputs:
	var curve_steer := signf(steer_input) * pow(absf(steer_input), 1.35)
	# Speed-adaptive steering lock (0.62 rad (~35°) at standstill/slow speeds, smoothly tightening at speed for stability):
	var steer_lock := 0.62 / (1.0 + absf(vf) * 0.026)
	var steer_target := curve_steer * steer_lock
	# Smooth rate-limited transitions (returning to center is naturally quicker):
	var steer_rate := 3.6 if absf(steer_target) > absf(steer) else 6.2
	steer = move_toward(steer, steer_target, steer_rate * delta)

	# Realistic Traction & Lateral Grip Physics:
	# Rear tire grip breaks progressively under handbrake or heavy lateral load:
	var base_grip := 9.4
	if handbrake:
		base_grip = 1.9 # Controlled power slide / drift
	elif boosting:
		base_grip = 6.4

	var old_vr := vr
	vr *= exp(-base_grip * delta)

	# Yaw rotation with Ackermann low-speed pivot (smooth realistic arc, no sudden snap):
	var effective_speed := absf(vf)
	if (throttle > 0.0 or brake > 0.0 or absf(vf) > 0.1) and effective_speed < 2.5:
		effective_speed = maxf(effective_speed, 2.5)

	if absf(steer) > 0.005:
		var speed_dir := -1.0 if vf < -0.2 else 1.0 # Invert yaw in reverse
		var turn_rate := (steer * effective_speed * 0.72) * speed_dir
		if handbrake:
			turn_rate *= 1.45 # Smooth drift arc
		yaw -= turn_rate * delta

	lateral_g = (vr - old_vr) / maxf(delta, 0.0001) * 0.06
	slip = absf(vr) + (14.0 if burnout_mode else (absf(steer) * absf(vf) * 0.3 if handbrake else 0.0))
	skid_level = clampf((slip - 3.5) / 10.0, 0.0, 1.0)
	if handbrake and absf(vf) > 5.0:
		skid_level = maxf(skid_level, 0.65)

	accel_g = lerpf(accel_g, (vf - vel.dot(fwd)) / maxf(delta, 0.0001) * 0.05, 8.0 * delta)
	vel = fwd * vf + right * vr
	var old_pos := car.position
	car.position += vel * delta

	# City boundaries & building collisions
	var city_hit := _constrain_car_to_city(old_pos)
	vel = fwd * vf + right * vr
	if city_hit:
		vf *= 0.65
		vr *= -0.22
		vel = fwd * vf + right * vr
		_add_shake(0.4)
		_apply_damage(1.8)

	# Traffic collisions and near misses
	for i in range(TRAFFIC_COUNT):
		var t := traffic[i]
		var dz: float = t.z - car.position.z
		var dx: float = t.x - car.position.x
		var along := dz if t.axis == "z" else dx
		var across := dx if t.axis == "z" else dz
		if absf(along) < 2.6 and absf(across) < 1.7:
			var rel: float = vf - t.dir * t.speed
			if rel > 0.0:
				vf = lerpf(vf, t.speed * 0.5, 0.5)
				if t.axis == "z":
					t.z += t.dir * 6.0
				else:
					t.x += t.dir * 6.0
				_apply_damage(4.0)
				_add_shake(0.7)
				impact_env = 1.0
			vel = fwd * vf + right * vr
		elif absf(along) < 5.0 and absf(across) < 2.6 and absf(vf) > 22.0:
			var key := str(i)
			if not near_miss_pending.has(key):
				near_miss_pending[key] = elapsed
				boost_charge = minf(100.0, boost_charge + 8.0)
				_set_center("NEAR MISS +8 BOOST", 0.8)

	# Clean near miss records
	var to_erase := []
	for k in near_miss_pending.keys():
		if elapsed - near_miss_pending[k] > 2.0:
			to_erase.append(k)
	for k in to_erase:
		near_miss_pending.erase(k)

	distance += vel.length() * delta
	_update_district()
	_update_gear(vf)
	_update_police(delta, vf)
	_update_car_visual(delta)


func _road_center(index: int) -> float:
	return -CITY_HALF + float(index) * CITY_GRID


func _nearest_road_index(value: float) -> int:
	return clampi(roundi((value + CITY_HALF) / CITY_GRID), 0, CITY_ROAD_COUNT - 1)


func _is_drivable_city_point(point: Vector3) -> bool:
	var x_dist := absf(point.x - _road_center(_nearest_road_index(point.x)))
	var z_dist := absf(point.z - _road_center(_nearest_road_index(point.z)))
	return x_dist <= CITY_CORRIDOR_HALF or z_dist <= CITY_CORRIDOR_HALF


func _constrain_car_to_city(old_pos: Vector3) -> bool:
	car.position.x = clampf(car.position.x, -CITY_HALF, CITY_HALF)
	car.position.z = clampf(car.position.z, -CITY_HALF, CITY_HALF)
	var pos := car.position
	if _is_drivable_city_point(pos):
		return false

	var x_road := _road_center(_nearest_road_index(pos.x))
	var z_road := _road_center(_nearest_road_index(pos.z))
	var x_dist := absf(pos.x - x_road)
	var z_dist := absf(pos.z - z_road)
	var old_x_dist := absf(old_pos.x - _road_center(_nearest_road_index(old_pos.x)))
	var old_z_dist := absf(old_pos.z - _road_center(_nearest_road_index(old_pos.z)))
	var hit_speed := vel.length()

	if old_z_dist <= CITY_CORRIDOR_HALF and old_x_dist > CITY_CORRIDOR_HALF:
		pos.z = z_road + signf(pos.z - z_road) * CITY_CORRIDOR_HALF
	elif old_x_dist <= CITY_CORRIDOR_HALF:
		pos.x = x_road + signf(pos.x - x_road) * CITY_CORRIDOR_HALF
	elif x_dist <= z_dist:
		pos.x = x_road + signf(pos.x - x_road) * CITY_CORRIDOR_HALF
	else:
		pos.z = z_road + signf(pos.z - z_road) * CITY_CORRIDOR_HALF

	car.position = pos
	if hit_speed > 7.0:
		_apply_damage(hit_speed * 0.22)
		_add_shake(clampf(hit_speed / 34.0, 0.25, 0.8))
		impact_env = maxf(impact_env, clampf(hit_speed / 28.0, 0.2, 1.0))
	return true


func _constrain_cop_to_city(node: Node3D) -> void:
	node.position.x = clampf(node.position.x, -CITY_HALF, CITY_HALF)
	node.position.z = clampf(node.position.z, -CITY_HALF, CITY_HALF)
	var x_road := _road_center(_nearest_road_index(node.position.x))
	var z_road := _road_center(_nearest_road_index(node.position.z))
	var x_dist := absf(node.position.x - x_road)
	var z_dist := absf(node.position.z - z_road)
	if x_dist <= CITY_CORRIDOR_HALF:
		node.position.z = clampf(node.position.z, z_road - CITY_CORRIDOR_HALF + 0.5, z_road + CITY_CORRIDOR_HALF - 0.5)
	elif z_dist <= CITY_CORRIDOR_HALF:
		node.position.x = clampf(node.position.x, x_road - CITY_CORRIDOR_HALF + 0.5, x_road + CITY_CORRIDOR_HALF - 0.5)
	elif x_dist <= z_dist:
		node.position.z = clampf(node.position.z, z_road - CITY_CORRIDOR_HALF + 0.5, z_road + CITY_CORRIDOR_HALF - 0.5)
	else:
		node.position.x = clampf(node.position.x, x_road - CITY_CORRIDOR_HALF + 0.5, x_road + CITY_CORRIDOR_HALF - 0.5)


func _city_district() -> String:
	var radius := Vector2(car.position.x, car.position.z).length()
	if radius < 650.0:
		return "NEON CORE"
	if car.position.z < -CITY_HALF * 0.45:
		return "NORTH HARBOUR"
	if car.position.z > CITY_HALF * 0.45:
		return "SOUTH YARDS"
	if car.position.x < -CITY_HALF * 0.45:
		return "OLD MOSCOW"
	if car.position.x > CITY_HALF * 0.45:
		return "EAST VILLAGE"
	return "MIDTOWN"


func _update_district() -> void:
	var district := _city_district()
	if district != current_district:
		current_district = district
		if race_state == "racing":
			_set_center(district, 1.1)


func _update_gear(vf: float) -> void:
	var thresholds := [0.0, 11.0, 21.0, 32.0, 45.0, 58.0, 74.0]
	var g := 1
	for i in range(1, thresholds.size()):
		if vf >= thresholds[i - 1]:
			g = i
	gear = g
	var lo: float = thresholds[gear - 1]
	var hi: float = thresholds[gear]
	var frac := clampf((vf - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)
	rpm = lerpf(rpm, 900.0 + frac * 6300.0, 7.0 * get_process_delta_time())


func _apply_damage(amount: float) -> void:
	damage = clampf(damage + amount, 0.0, 100.0)
	if damage >= 100.0 and race_state == "racing":
		race_state = "wrecked"
		_set_center("WRECKED - PRESS R", 0.0)
		vel = Vector3.ZERO


func _add_shake(amount: float) -> void:
	shake = clampf(shake + amount, 0.0, 1.4)


func _update_police(delta: float, player_speed: float) -> void:
	if race_state != "racing":
		return
	police_timer -= delta
	if police_timer <= 0.0:
		heat = mini(5, heat + 1)
		police_timer = 22.0
		_spawn_cops(mini(MAX_COPS, 1 + heat))
		_set_center("HEAT %d" % heat, 0.9)

	var nearest := 9999.0
	var any_close := false
	var cop_top_speed := 39.0 + 5.5 * heat
	for cop in cops:
		if not cop.active:
			continue
		var node: Node3D = cop.node
		var target := car.position + Vector3(sin(yaw) * 8.0, 0, 14.0)
		var dir := (target - node.position)
		dir.y = 0.0
		dir = dir.normalized()
		var to_player := car.position - node.position
		var dist := to_player.length()
		nearest = minf(nearest, dist)
		any_close = any_close or dist < 12.0

		var desired: float = cop_top_speed
		if dist > 55.0:
			desired *= 1.25
		elif dist < 8.0:
			desired = player_speed * 0.92
		cop.speed = move_toward(cop.speed, desired, 16.0 * delta)
		node.position += dir * cop.speed * delta
		_constrain_cop_to_city(node)
		node.look_at(Vector3(car.position.x, node.position.y, car.position.z - 10.0), Vector3.UP)

		if dist < 2.6:
			var push := to_player.normalized() * 6.0
			vel += Vector3(push.x, 0, push.z * 0.4)
			node.position -= Vector3(push.x, 0, push.z) * 0.5
			_apply_damage(3.2)
			_add_shake(0.9)
			impact_env = 1.0
			pursuit = maxf(pursuit - 0.035, -1.0)
		elif dist > 170.0:
			node.position = car.position + Vector3(rng.randf_range(-3, 3), 0, 70.0)
			cop.speed = cop_top_speed * 0.6

	if any_close:
		busted_timer += delta
		evade_timer = 0.0
		if player_speed < 7.0 and busted_timer > 1.2:
			pursuit = maxf(pursuit - 0.30 * delta, -1.0)
	else:
		busted_timer = 0.0
		if nearest > 120.0:
			evade_timer += delta
			pursuit = minf(pursuit + 0.06 * delta, 1.0)
			if evade_timer > 4.0:
				heat = mini(5, heat + 1)
				police_timer = 16.0
				for cop in cops:
					cop.node.visible = false
					cop.active = false
				_spawn_cops(mini(MAX_COPS, 1 + heat))
				pursuit = 0.0
				evade_timer = 0.0
				_set_center("EVADED - HEAT %d" % heat, 1.2)

	if pursuit <= -1.0:
		race_state = "busted"
		vel = Vector3.ZERO
		_set_center("BUSTED - PRESS R", 0.0)
		for cop in cops:
			cop.speed = 0.0


func _spawn_cops(count: int) -> void:
	var spawned := 0
	for cop in cops:
		if cop.active or spawned >= count:
			continue
		cop.active = true
		cop.node.visible = true
		cop.speed = 20.0
		cop.node.position = car.position + Vector3(
			rng.randf_range(-3.5, 3.5), 0, 55.0 + rng.randf() * 30.0
		)
		spawned += 1


func _update_car_visual(delta: float) -> void:
	# GTA 6 4-Wheel Suspension & Weight Transfer Dynamics
	var target_roll := clampf(lateral_g * 0.042, -0.18, 0.18)
	var target_pitch := clampf(-accel_g * 0.016, -0.09, 0.08) # Brake dive / Accel squat
	body_roll = lerpf(body_roll, target_roll, 14.0 * delta)
	body_pitch = lerpf(body_pitch, target_pitch, 14.0 * delta)

	# Procedural road bump vibration
	var speed_norm := clampf(vel.length() / 40.0, 0.0, 1.0)
	var road_vibe := sin(elapsed * 45.0) * (0.003 * speed_norm)
	suspension_bounce = lerpf(suspension_bounce, road_vibe, 12.0 * delta)

	car.rotation = Vector3(body_pitch, yaw, body_roll)
	car_body.position.y = 0.42 + suspension_bounce

	# Front wheels steering angle animation
	for pivot in front_wheel_pivots:
		pivot.rotation.y = -steer

	# Wheel rolling spin animation along local X axis
	var fwd_dir := Vector3(-sin(yaw), 0, -cos(yaw))
	var forward_vel := vel.dot(fwd_dir)
	var roll_step := -(forward_vel / 0.26) * delta
	for roller in wheel_rollers:
		roller.rotate_x(roll_step)

	# High-RPM rear wheel spin during burnout
	if burnout_mode:
		for roller in rear_wheel_rollers:
			roller.rotate_x(-42.0 * delta)

	# Boost flame
	var flame_scale := 1.0 + (0.9 if boosting else 0.0) + sin(Time.get_ticks_msec() * 0.06) * 0.12
	boost_flame.scale = Vector3(1.0, 1.0, flame_scale)
	boost_flame.visible = boosting or burnout_mode

	# Brake lights glow
	var key_brake := Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	var braking := (Input.is_action_pressed("brake") or key_brake) and race_state == "racing"
	for light_mesh in brake_lights:
		var mat: StandardMaterial3D = light_mesh.material_override
		if mat != null:
			mat.emission_energy_multiplier = 4.2 if braking else 0.9


func _travel_basis(axis: String, direction: float) -> Basis:
	var angle := 0.0
	if axis == "x":
		angle = PI * 0.5 if direction > 0.0 else -PI * 0.5
	else:
		angle = 0.0 if direction > 0.0 else PI
	return Basis(Vector3.UP, angle)


func _recycle_traffic(index: int, initial := false) -> void:
	var t := traffic[index]
	var axis := "z" if index % 2 == 0 else "x"
	var direction := -1.0 if rng.randf() < 0.5 else 1.0
	t.axis = axis
	t.dir = direction
	t.speed = rng.randf_range(8.0, 19.0)
	if axis == "z":
		var road := clampi(
			_nearest_road_index(car.position.x) + rng.randi_range(-3, 3),
			0, CITY_ROAD_COUNT - 1
		)
		t.x = _road_center(road) + (2.0 if direction < 0.0 else -2.0)
		t.z = car.position.z + rng.randf_range(-260.0, 180.0)
		if initial and absf(t.z - car.position.z) < 25.0:
			t.z -= 35.0
	else:
		var road := clampi(
			_nearest_road_index(car.position.z) + rng.randi_range(-3, 3),
			0, CITY_ROAD_COUNT - 1
		)
		t.z = _road_center(road) + (-2.0 if direction < 0.0 else 2.0)
		t.x = car.position.x + rng.randf_range(-260.0, 180.0)
		if initial and absf(t.x - car.position.x) < 25.0:
			t.x -= 35.0


func _recycle_pedestrian(index: int, initial := false) -> void:
	var person := pedestrians[index]
	var axis := "z" if index % 2 == 0 else "x"
	var direction := -1.0 if rng.randf() < 0.5 else 1.0
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	person.axis = axis
	person.dir = direction
	person.speed = rng.randf_range(0.9, 2.1)
	if axis == "z":
		var road := clampi(
			_nearest_road_index(car.position.x) + rng.randi_range(-2, 2),
			0, CITY_ROAD_COUNT - 1
		)
		person.x = _road_center(road) + side * 7.4
		person.z = car.position.z + rng.randf_range(-150.0, 90.0)
		if initial and absf(person.z - car.position.z) < 14.0:
			person.z -= 20.0
	else:
		var road := clampi(
			_nearest_road_index(car.position.z) + rng.randi_range(-2, 2),
			0, CITY_ROAD_COUNT - 1
		)
		person.z = _road_center(road) + side * 7.4
		person.x = car.position.x + rng.randf_range(-150.0, 90.0)
		if initial and absf(person.x - car.position.x) < 14.0:
			person.x -= 20.0


func _update_world(delta: float) -> void:
	var near_x := _nearest_road_index(car.position.x)
	var near_z := _nearest_road_index(car.position.z)
	var stripes_per_axis := STRIPE_COUNT / 2
	for i in range(stripes_per_axis):
		var lane := i / 16
		var step := i % 16
		var x_road := clampi(near_x + lane - 2, 0, CITY_ROAD_COUNT - 1)
		var z_road := clampi(near_z + lane - 2, 0, CITY_ROAD_COUNT - 1)
		var z_pos := _road_center(near_z) + -128.0 + float(step) * 16.0
		var x_pos := _road_center(near_x) + -128.0 + float(step) * 16.0
		stripe_mm.set_instance_transform(
			i, Transform3D(Basis(), Vector3(_road_center(x_road), 0.035, z_pos))
		)
		stripe_mm.set_instance_transform(
			i + stripes_per_axis,
			Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x_pos, 0.037, _road_center(z_road)))
		)

	for i in range(POLE_COUNT):
		var intersection_x := clampi(
			near_x + (i % 5) - 2 + (i / 25) * 3, 0, CITY_ROAD_COUNT - 1
		)
		var intersection_z := clampi(
			near_z + ((i / 5) % 5) - 2 + (i / 50) * 3, 0, CITY_ROAD_COUNT - 1
		)
		var side := -1.0 if i % 2 == 0 else 1.0
		var head_basis := Basis()
		var pole_pos := Vector3(
			_road_center(intersection_x) + side * 6.2,
			2.0,
			_road_center(intersection_z)
		)
		if i % 3 == 0:
			pole_pos = Vector3(
				_road_center(intersection_x),
				2.0,
				_road_center(intersection_z) + side * 6.2
			)
			head_basis = Basis(Vector3.UP, PI * 0.5)
		pole_mm.set_instance_transform(i, Transform3D(Basis(), pole_pos))
		lamp_head_mm.set_instance_transform(
			i, Transform3D(head_basis, pole_pos + Vector3(0.0, 2.05, 0.0))
		)

	for i in range(TRAFFIC_COUNT):
		var t := traffic[i]
		if t.axis == "z":
			t.z += t.dir * t.speed * delta
		else:
			t.x += t.dir * t.speed * delta
		if maxf(absf(t.x - car.position.x), absf(t.z - car.position.z)) > 250.0:
			_recycle_traffic(i)
		var pos := Vector3(t.x, 0.5, t.z)
		var basis := _travel_basis(t.axis, t.dir)
		traffic_mm.set_instance_transform(i, Transform3D(basis, pos))
		traffic_cabin_mm.set_instance_transform(
			i, Transform3D(basis, pos + Vector3(0.0, 0.48, 0.0))
		)
		traffic_front_light_mm.set_instance_transform(
			i, Transform3D(basis, pos + basis * Vector3(0.0, -0.02, 1.92))
		)
		traffic_rear_light_mm.set_instance_transform(
			i, Transform3D(basis, pos - basis * Vector3(0.0, -0.02, 1.92))
		)

	# Sidewalk crowds: realistic humanoid bodies, heads, animated legs and swinging arms
	for i in range(PEDESTRIAN_COUNT):
		var person := pedestrians[i]
		if person.axis == "z":
			person.z += person.speed * person.dir * delta
		else:
			person.x += person.speed * person.dir * delta
		if maxf(absf(person.x - car.position.x), absf(person.z - car.position.z)) > 155.0:
			_recycle_pedestrian(i)
		var walk_phase: float = person.phase + elapsed * person.speed * 2.4
		var bob := absf(sin(walk_phase)) * 0.045
		var facing := _travel_basis(person.axis, person.dir)
		var center := Vector3(person.x, 0.0, person.z)
		pedestrian_body_mm.set_instance_transform(
			i, Transform3D(facing, center + Vector3(0.0, 0.98 + bob, 0.0))
		)
		pedestrian_head_mm.set_instance_transform(
			i, Transform3D(facing, center + Vector3(0.0, 1.44 + bob, 0.0))
		)
		var stride := sin(walk_phase) * 0.18
		var leg_basis := facing * Basis(Vector3(1, 0, 0), stride * 0.7)
		pedestrian_leg_mm.set_instance_transform(
			i * 2, Transform3D(leg_basis, center + facing * Vector3(-0.12, 0.38, stride))
		)
		pedestrian_leg_mm.set_instance_transform(
			i * 2 + 1, Transform3D(leg_basis, center + facing * Vector3(0.12, 0.38, -stride))
		)
		# Arm swinging in natural human counter-motion to legs
		var arm_basis_l := facing * Basis(Vector3(1, 0, 0), -stride * 0.85)
		var arm_basis_r := facing * Basis(Vector3(1, 0, 0), stride * 0.85)
		pedestrian_arm_mm.set_instance_transform(
			i * 2, Transform3D(arm_basis_l, center + facing * Vector3(-0.28, 0.96 + bob, -stride * 0.6))
		)
		pedestrian_arm_mm.set_instance_transform(
			i * 2 + 1, Transform3D(arm_basis_r, center + facing * Vector3(0.28, 0.96 + bob, stride * 0.6))
		)

	# Trees along sidewalks
	for i in range(TREE_COUNT):
		var tx_road := clampi(near_x + (i % 6) - 3 + (i / 32) * 2, 0, CITY_ROAD_COUNT - 1)
		var tz_road := clampi(near_z + ((i / 6) % 6) - 3 + (i / 48) * 2, 0, CITY_ROAD_COUNT - 1)
		var side := -1.0 if i % 2 == 0 else 1.0
		var tree_pos := Vector3(_road_center(tx_road) + side * 7.8, 0.0, _road_center(tz_road) + float((i % 4) - 2) * 14.0)
		tree_trunk_mm.set_instance_transform(i, Transform3D(Basis(), tree_pos + Vector3(0, 1.6, 0)))
		tree_canopy_mm.set_instance_transform(i, Transform3D(Basis(), tree_pos + Vector3(0, 3.8, 0)))

	# Airliners cross high above the skyline; strobes blink from one shared material
	for plane in aircraft:
		var plane_node: Node3D = plane.node
		plane_node.position += plane.dir * plane.speed * delta
		if plane_node.position.distance_to(camera.position) > 900.0:
			plane_node.position = camera.position + plane.reset_base
			plane_node.look_at(plane_node.position + plane.dir, Vector3.UP)
	var strobe := fmod(elapsed * 1.35, 1.0)
	plane_strobe_mat.emission_energy_multiplier = 5.0 if strobe < 0.12 or strobe > 0.42 and strobe < 0.50 else 0.15

	# Night sky follows the camera; clouds drift slowly without extra draw calls
	for i in range(CLOUD_COUNT):
		var offset := cloud_offsets[i]
		var x := wrapf(offset.x + elapsed * 1.15, -280.0, 280.0)
		cloud_mm.set_instance_transform(
			i, Transform3D(Basis(Vector3.UP, elapsed * 0.008), Vector3(camera.position.x + x, offset.y, camera.position.z + offset.z))
		)
	for i in range(STAR_COUNT):
		var star_offset := star_offsets[i]
		star_mm.set_instance_transform(
			i, Transform3D(Basis(), camera.position + star_offset)
		)
	moon_node.position = camera.position + Vector3(-138.0, 168.0, -272.0)

	# Rain follows the camera
	for i in range(RAIN_COUNT):
		var yy := wrapf(rain_y0[i] - 26.0 * elapsed, 0.0, 30.0)
		rain_mm.set_instance_transform(
			i, Transform3D(Basis(Vector3(0, 0, 1), 0.09), Vector3(camera.position.x + rain_ox[i], yy, camera.position.z + rain_oz[i]))
		)

	# Cop light bars flash in alternating red/blue
	var flash := fmod(Time.get_ticks_msec() * 0.004, 1.0) < 0.5
	cop_light_a.emission = Color(4.0, 0.1, 0.1) if flash else Color(0.2, 0.02, 0.02)
	cop_light_b.emission = Color(0.1, 0.3, 4.0) if not flash else Color(0.02, 0.05, 0.2)

	# GTA 6 Dynamic Camera System (Chase Cam & Hood Cam)
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right_vec := Vector3(cos(yaw), 0, -sin(yaw))
	var vf := vel.dot(fwd)
	var vr := vel.dot(right_vec)

	if camera_mode == "hood":
		# High-speed cockpit hood cam
		var hood_target := car.position + fwd * 0.8 + Vector3(0, 1.15, 0)
		camera.position = camera.position.lerp(hood_target, 20.0 * delta)
		var look_hood := car.position + fwd * 40.0 + Vector3(0, 1.0, 0)
		camera.look_at(look_hood, Vector3.UP)
		var target_fov := 78.0 + absf(vf) * 0.28 + (8.0 if boosting else 0.0)
		camera.fov = lerpf(camera.fov, target_fov, 6.0 * delta)
	else:
		# GTA 6 Dynamic Chase Cam with lateral drift lag & speed zoom
		var cam_dist := 6.6 + absf(vf) * 0.032
		var cam_height := 2.6 + absf(vf) * 0.010
		# Lateral drift lag: camera swings slightly into the drift arc
		var drift_offset := right_vec * clampf(-vr * 0.12, -1.8, 1.8)
		var target := car.position - fwd * cam_dist + Vector3(0, cam_height, 0) + drift_offset
		camera.position = camera.position.lerp(target, 6.5 * delta)

		if shake > 0.001:
			camera.position += Vector3(
				rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)
			) * shake * 0.18
			shake = lerpf(shake, 0.0, 6.0 * delta)

		var look := car.position + fwd * 10.0 + Vector3(0, 1.2, 0)
		camera.look_at(look, Vector3.UP)
		camera.rotation.z += clampf(-lateral_g * 0.014, -0.06, 0.06)
		var target_fov := 64.0 + absf(vf) * 0.32 + (8.0 if boosting else 0.0)
		camera.fov = lerpf(camera.fov, target_fov, 4.0 * delta)

	headlight.light_energy = 3.8 + (1.4 if boosting else 0.0)
	speed_tint.color.a = clampf(absf(vf) / 70.0, 0.0, 1.0) * 0.055


func _update_weather(delta: float) -> void:
	if light_mode:
		flash_rect.color.a = 0.0
		return
	lightning_timer -= delta
	if lightning_timer <= 0.0:
		lightning_timer = 9.0 + rng.randf() * 14.0
		flash_rect.color.a = 0.32
		thunder_delay = 0.7 + rng.randf() * 1.4
	if flash_rect.color.a > 0.0:
		flash_rect.color.a = maxf(0.0, flash_rect.color.a - 1.8 * delta)
	if thunder_delay > 0.0:
		thunder_delay -= delta
		if thunder_delay <= 0.0:
			thunder_env = 1.0
	if thunder_env > 0.0:
		thunder_env = maxf(0.0, thunder_env - 0.65 * delta)


func _city_multimesh(mesh: PlaneMesh, material: Material, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mesh.material = material
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = mm
	add_child(holder)
	return mm


func _build_city_ground() -> void:
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.10, 0.11, 0.13)
	if ResourceLoader.exists("res://textures/sidewalk_tiles.jpg"):
		ground_mat.albedo_texture = load("res://textures/sidewalk_tiles.jpg")
		ground_mat.uv1_scale = Vector3(45, 45, 1)
	else:
		ground_mat.albedo_texture = _noise_texture()
		ground_mat.uv1_scale = Vector3(90, 90, 1)
	ground_mat.roughness = 0.85
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(CITY_SPAN + 320.0, CITY_SPAN + 320.0)
	var ground := MeshInstance3D.new()
	ground.mesh = ground_mesh
	ground.material_override = ground_mat
	add_child(ground)

	# High-res PBR Asphalt road with crisp markings and realistic wetness sheen
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.92, 0.94, 0.98)
	if ResourceLoader.exists("res://textures/road_asphalt.jpg"):
		road_mat.albedo_texture = load("res://textures/road_asphalt.jpg")
		road_mat.uv1_scale = Vector3(1.0, 72.0, 1)
	else:
		road_mat.albedo_texture = _noise_texture()
		road_mat.uv1_scale = Vector3(1.2, 72.0, 1)
	road_mat.metallic = 0.35
	road_mat.roughness = 0.22
	road_mat.rim_enabled = true
	road_mat.rim = 0.25
	var road_mesh := PlaneMesh.new()
	road_mesh.size = Vector2(ROAD_HALF_WIDTH * 2.0, CITY_SPAN)
	var road_v := _city_multimesh(road_mesh, road_mat, CITY_ROAD_COUNT)
	var road_h := _city_multimesh(road_mesh, road_mat, CITY_ROAD_COUNT)

	# Sidewalk concrete paving tiles
	var sidewalk_mat := StandardMaterial3D.new()
	sidewalk_mat.albedo_color = Color(0.85, 0.86, 0.88)
	if ResourceLoader.exists("res://textures/sidewalk_tiles.jpg"):
		sidewalk_mat.albedo_texture = load("res://textures/sidewalk_tiles.jpg")
		sidewalk_mat.uv1_scale = Vector3(1.0, 72.0, 1)
	else:
		sidewalk_mat.albedo_texture = _noise_texture()
		sidewalk_mat.uv1_scale = Vector3(1.5, 72.0, 1)
	sidewalk_mat.roughness = 0.68
	var walk_mesh := PlaneMesh.new()
	walk_mesh.size = Vector2(9.6, CITY_SPAN)
	var walk_v := _city_multimesh(walk_mesh, sidewalk_mat, CITY_ROAD_COUNT * 2)
	var walk_h := _city_multimesh(walk_mesh, sidewalk_mat, CITY_ROAD_COUNT * 2)

	for i in range(CITY_ROAD_COUNT):
		var center := _road_center(i)
		road_v.set_instance_transform(i, Transform3D(Basis(), Vector3(center, 0.01, 0.0)))
		road_h.set_instance_transform(
			i, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, 0.012, center))
		)
		for side in [-1, 1]:
			walk_v.set_instance_transform(
				i * 2 + (side + 1) / 2,
				Transform3D(Basis(), Vector3(center + side * (ROAD_HALF_WIDTH + 4.8), 0.075, 0.0))
			)
			walk_h.set_instance_transform(
				i * 2 + (side + 1) / 2,
				Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, 0.08, center + side * (ROAD_HALF_WIDTH + 4.8)))
			)


func _set_center(text: String, hold: float) -> void:
	hud_center.text = text
	center_timer = hold


func _update_hud() -> void:
	if center_timer > 0.0 and hud_center.text.length() > 0:
		center_timer -= get_process_delta_time()
		if center_timer <= 0.0 and not hud_center.text.begins_with("BUSTED") and not hud_center.text.begins_with("WRECKED"):
			hud_center.text = ""
	var vf := vel.dot(Vector3(-sin(yaw), 0, -cos(yaw)))
	hud_speed.text = "%03d" % int(absf(vf) * 3.6)
	hud_gear.text = "G%d" % gear
	hud_time.text = "OPEN CITY 3.6 KM"
	hud_distance.text = "ODO %.0f M - %s" % [distance, current_district]
	hud_boost.text = "NOS %d%%" % int(boost_charge)
	hud_best.text = "FREE ROAM"
	hud_heat.text = "*".repeat(heat)
	hud_heat.modulate = Color(1.0, 0.35 + 0.13 * heat, 0.25, 1.0)
	hud_damage_label.text = "DMG %d%%" % int(damage)
	speed_bar.custom_minimum_size.x = clampf(absf(vf) / 62.0, 0.0, 1.0) * 250.0
	boost_bar.custom_minimum_size.x = clampf(boost_charge / 100.0, 0.0, 1.0) * 170.0
	damage_bar.custom_minimum_size.x = clampf(damage / 100.0, 0.0, 1.0) * 170.0
	var evade_k := clampf((pursuit + 1.0) / 2.0, 0.0, 1.0)
	pursuit_bar.custom_minimum_size.x = evade_k * 300.0
	pursuit_bar.color = Color(1.0 - evade_k * 0.85, 0.15 + evade_k * 0.75, 0.2, 0.95)


func _maybe_auto_quit(delta: float) -> void:
	if auto_quit_at < 0.0:
		return
	auto_quit_at -= delta
	perf_time += delta
	if perf_time > 0.25:
		perf_frames += 1
	if auto_quit_at <= 0.0:
		if not screenshot_path.is_empty():
			var tex := get_viewport().get_texture()
			if tex != null:
				var img := tex.get_image()
				if img != null:
					img.save_png(screenshot_path)
		if perf_frames > 0:
			print("perf scale=%.2f avg_fps=%.2f frames=%d" % [
				get_viewport().scaling_3d_scale,
				perf_frames / maxf(perf_time - 0.25, 0.001),
				perf_frames
			])
			print("route pos=%.1f,%.1f yaw=%.2f district=%s" % [
				car.position.x, car.position.z, yaw, current_district
			])
		get_tree().quit()


func _build_environment() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat

	world_env = Environment.new()
	world_env.background_mode = Environment.BG_SKY
	world_env.sky = sky
	world_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	world_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_env.glow_enabled = true
	world_env.glow_hdr_threshold = 1.02
	world_env.fog_enabled = true

	var we := WorldEnvironment.new()
	we.environment = world_env
	add_child(we)

	main_dir_light = DirectionalLight3D.new()
	add_child(main_dir_light)

	fill_dir_light = DirectionalLight3D.new()
	add_child(fill_dir_light)

	_apply_lighting_mode()

	camera = Camera3D.new()
	camera.fov = 64.0
	camera.near = 0.2
	camera.far = 380.0
	camera.position = Vector3(0, 3, 8)
	add_child(camera)


func _apply_lighting_mode() -> void:
	if sky_mat == null or world_env == null or main_dir_light == null or fill_dir_light == null:
		return
	if light_mode:
		# Realistic Bright Daytime Mode (GTA 5 style sunny California daylight)
		sky_mat.sky_top_color = Color(0.18, 0.46, 0.86)
		sky_mat.sky_horizon_color = Color(0.72, 0.82, 0.92)
		sky_mat.ground_bottom_color = Color(0.16, 0.18, 0.16)
		sky_mat.ground_horizon_color = Color(0.56, 0.64, 0.70)
		sky_mat.sky_curve = 0.12
		sky_mat.sky_energy_multiplier = 1.05

		world_env.ambient_light_energy = 0.92
		world_env.tonemap_exposure = 1.06
		world_env.fog_light_color = Color(0.70, 0.78, 0.88)
		world_env.fog_density = 0.0018
		world_env.fog_sky_affect = 0.25
		world_env.glow_intensity = 0.30
		world_env.glow_bloom = 0.03

		main_dir_light.rotation_degrees = Vector3(-50, 38, 0)
		main_dir_light.light_color = Color(1.0, 0.97, 0.90)
		main_dir_light.light_energy = 1.45
		main_dir_light.shadow_enabled = true

		fill_dir_light.rotation_degrees = Vector3(45, -135, 0)
		fill_dir_light.light_color = Color(0.58, 0.68, 0.82)
		fill_dir_light.light_energy = 0.45

		if moon_node != null and moon_node.material_override is StandardMaterial3D:
			(moon_node.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.96, 0.82)

		if headlight != null:
			headlight.light_energy = 0.6

		for mat in building_materials:
			mat.emission_energy_multiplier = 0.20
	else:
		# Night Neon Cyberpunk Mode
		sky_mat.sky_top_color = Color(0.010, 0.016, 0.038)
		sky_mat.sky_horizon_color = Color(0.18, 0.11, 0.22)
		sky_mat.ground_bottom_color = Color(0.008, 0.010, 0.018)
		sky_mat.ground_horizon_color = Color(0.21, 0.13, 0.23)
		sky_mat.sky_curve = 0.09
		sky_mat.sky_energy_multiplier = 1.15

		world_env.ambient_light_energy = 1.05
		world_env.tonemap_exposure = 1.12
		world_env.fog_light_color = Color(0.20, 0.14, 0.24)
		world_env.fog_density = 0.0042
		world_env.fog_sky_affect = 0.40
		world_env.glow_intensity = 0.92
		world_env.glow_bloom = 0.12

		main_dir_light.rotation_degrees = Vector3(-42, 35, 0)
		main_dir_light.light_color = Color(0.65, 0.74, 1.0)
		main_dir_light.light_energy = 0.85
		main_dir_light.shadow_enabled = false

		fill_dir_light.rotation_degrees = Vector3(50, -145, 0)
		fill_dir_light.light_color = Color(0.28, 0.18, 0.35)
		fill_dir_light.light_energy = 0.35

		if moon_node != null and moon_node.material_override is StandardMaterial3D:
			(moon_node.material_override as StandardMaterial3D).albedo_color = Color(0.88, 0.92, 1.0)

		if headlight != null:
			headlight.light_energy = 2.4

		for mat in building_materials:
			mat.emission_energy_multiplier = 1.20


func _noise_texture() -> ImageTexture:
	var img := Image.create_empty(256, 256, false, Image.FORMAT_RGB8)
	for y in range(256):
		for x in range(256):
			var v := 18 + rng.randf() * 16
			img.set_pixel(x, y, Color(v / 255.0, v / 255.0, (v + 5) / 255.0))
	return ImageTexture.create_from_image(img)


func _window_texture() -> ImageTexture:
	var img := Image.create_empty(128, 256, false, Image.FORMAT_RGB8)
	img.fill(Color(0, 0, 0))
	for gx in range(16):
		for gy in range(32):
			if rng.randf() < 0.34:
				var c := Color(0.55, 0.9, 1.0)
				var r := rng.randf()
				if r < 0.22:
					c = Color(1.0, 0.72, 0.42)
				elif r > 0.92:
					c = Color(1.0, 0.28, 0.75)
				var e := 0.25 + rng.randf() * 0.75
				img.fill_rect(Rect2i(gx * 8 + 2, gy * 8 + 2, 5, 4), Color(c.r * e, c.g * e, c.b * e))
	return ImageTexture.create_from_image(img)


func _facade_texture(kind: int) -> ImageTexture:
	var img := Image.create_empty(256, 256, false, Image.FORMAT_RGB8)
	var base := Color(0.05, 0.05, 0.07)
	match kind:
		0: base = Color(0.075, 0.038, 0.030)  # New York brick
		1: base = Color(0.078, 0.074, 0.068)  # prewar limestone
		2: base = Color(0.026, 0.044, 0.060)  # glass tower
		3: base = Color(0.085, 0.070, 0.050)  # Moscow stone
		4: base = Color(0.048, 0.050, 0.058)  # modern concrete
	img.fill(base)

	for y in range(256):
		for x in range(256):
			var n := rng.randf_range(-0.012, 0.012)
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(
				clampf(c.r + n, 0.0, 1.0),
				clampf(c.g + n, 0.0, 1.0),
				clampf(c.b + n * 1.1, 0.0, 1.0)
			))

	if kind == 0:
		for y in range(256):
			var row := y % 16
			if row <= 1:
				for x in range(256):
					var c := img.get_pixel(x, y)
					img.set_pixel(x, y, Color(c.r * 1.7, c.g * 1.7, c.b * 1.6))
			elif row >= 8 and row <= 9:
				for x in range(256):
					if (x + (y / 16) * 16) % 48 < 2:
						var c := img.get_pixel(x, y)
						img.set_pixel(x, y, Color(c.r * 1.6, c.g * 1.7, c.b * 1.7))
	elif kind == 1 or kind == 3:
		for y in range(0, 256, 32):
			for x in range(256):
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r * 1.35, c.g * 1.30, c.b * 1.15))
		for y in range(0, 256, 64):
			for x in range(20, 236, 44):
				img.fill_rect(Rect2i(x, y + 8, 26, 34), Color(0.018, 0.022, 0.028))
	elif kind == 2:
		for y in range(0, 256, 24):
			img.fill_rect(Rect2i(0, y, 256, 3), Color(0.045, 0.065, 0.085))
		for x in range(0, 256, 32):
			img.fill_rect(Rect2i(x, 0, 3, 256), Color(0.050, 0.070, 0.090))
	else:
		for y in range(0, 256, 28):
			img.fill_rect(Rect2i(0, y, 256, 2), Color(0.065, 0.068, 0.074))

	return ImageTexture.create_from_image(img)


func _prepare_building_materials(windows: ImageTexture) -> void:
	building_materials.clear()
	var facade_tex: Texture2D = null
	if ResourceLoader.exists("res://textures/facade_windows.jpg"):
		facade_tex = load("res://textures/facade_windows.jpg")

	for kind in range(5):
		var mat := StandardMaterial3D.new()
		if facade_tex != null:
			mat.albedo_texture = facade_tex
			mat.uv1_scale = Vector3(1.0, 2.5, 1.0)
		else:
			mat.albedo_texture = _facade_texture(kind)
			mat.uv1_scale = Vector3(2.0, 4.0, 1.0)
		mat.metallic = 0.35 if kind != 2 else 0.85
		mat.roughness = 0.40 if kind != 2 else 0.12
		mat.emission_enabled = true
		mat.emission_texture = facade_tex if facade_tex != null else windows
		mat.emission_energy_multiplier = 0.95 if kind == 2 else 1.30
		building_materials.append(mat)

	roof_water_mat = StandardMaterial3D.new()
	roof_water_mat.albedo_color = Color(0.055, 0.035, 0.025)
	roof_water_mat.roughness = 0.82
	roof_mech_mat = StandardMaterial3D.new()
	roof_mech_mat.albedo_color = Color(0.045, 0.048, 0.055)
	roof_mech_mat.metallic = 0.35
	roof_mech_mat.roughness = 0.58


func _make_multimesh(mesh: Mesh, mat: Material, count: int, use_colors := false) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	if use_colors:
		mm.use_colors = true
	mm.instance_count = count
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = mat
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = mm
	add_child(holder)
	return mm


func _build_world() -> void:
	_build_city_ground()

	stripe_mm = _multimesh_box(Vector3(0.20, 0.02, 3.0), Color(1.25, 1.3, 0.95), STRIPE_COUNT)
	pole_mm = _multimesh_box(Vector3(0.11, 4.0, 0.11), Color(0.55, 0.58, 0.65), POLE_COUNT)
	lamp_head_mm = _multimesh_box(Vector3(0.8, 0.14, 0.32), Color(2.6, 1.9, 1.2), POLE_COUNT)

	# Realistic roadside boulevard trees
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.24
	trunk_mesh.height = 3.2
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.22, 0.16, 0.11)
	trunk_mat.roughness = 0.90
	tree_trunk_mm = _make_multimesh(trunk_mesh, trunk_mat, TREE_COUNT)

	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 1.65
	canopy_mesh.height = 3.3
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(0.12, 0.38, 0.14)
	canopy_mat.roughness = 0.65
	canopy_mat.rim_enabled = true
	canopy_mat.rim = 0.4
	if ResourceLoader.exists("res://textures/tree_leaves.png"):
		canopy_mat.albedo_texture = load("res://textures/tree_leaves.png")
	tree_canopy_mm = _make_multimesh(canopy_mesh, canopy_mat, TREE_COUNT)

	var windows := _window_texture()
	_prepare_building_materials(windows)
	_spawn_buildings(windows)
	_build_landmarks()

	var traffic_body := BoxMesh.new()
	traffic_body.size = Vector3(1.75, 0.72, 3.9)
	var traffic_mat := StandardMaterial3D.new()
	traffic_mat.vertex_color_use_as_albedo = true
	traffic_mat.metallic = 0.55
	traffic_mat.roughness = 0.34
	traffic_mm = _make_multimesh(traffic_body, traffic_mat, TRAFFIC_COUNT, true)

	var traffic_cabin_mesh := BoxMesh.new()
	traffic_cabin_mesh.size = Vector3(1.48, 0.42, 1.9)
	var traffic_glass := StandardMaterial3D.new()
	traffic_glass.albedo_color = Color(0.025, 0.035, 0.055)
	traffic_glass.metallic = 0.85
	traffic_glass.roughness = 0.12
	traffic_cabin_mm = _make_multimesh(traffic_cabin_mesh, traffic_glass, TRAFFIC_COUNT)

	var traffic_front_mesh := BoxMesh.new()
	traffic_front_mesh.size = Vector3(1.25, 0.10, 0.08)
	var traffic_front_mat := StandardMaterial3D.new()
	traffic_front_mat.emission_enabled = true
	traffic_front_mat.emission = Color(1.8, 1.9, 2.1)
	traffic_front_light_mm = _make_multimesh(traffic_front_mesh, traffic_front_mat, TRAFFIC_COUNT)

	var traffic_rear_mesh := BoxMesh.new()
	traffic_rear_mesh.size = Vector3(1.25, 0.10, 0.08)
	var traffic_rear_mat := StandardMaterial3D.new()
	traffic_rear_mat.emission_enabled = true
	traffic_rear_mat.emission = Color(2.2, 0.12, 0.12)
	traffic_rear_light_mm = _make_multimesh(traffic_rear_mesh, traffic_rear_mat, TRAFFIC_COUNT)

	for i in range(TRAFFIC_COUNT):
		traffic.append({
			"x": 0.0, "z": 0.0, "axis": "z", "dir": -1.0,
			"speed": rng.randf_range(8.0, 19.0)
		})
	_spawn_traffic()
	_build_pedestrians()
	_build_aircraft()
	_build_night_sky()

	# Crosswalks, storefront signs, and billboards are static instanced geometry.
	var crosswalk_mesh := BoxMesh.new()
	crosswalk_mesh.size = Vector3(0.45, 0.025, 10.5)
	var crosswalk_mm := _make_multimesh(crosswalk_mesh, StandardMaterial3D.new(), 512)
	var cw_instance := 0
	for z_road in range(0, CITY_ROAD_COUNT, 8):
		for x_road in range(0, CITY_ROAD_COUNT, 8):
			var intersection := Vector3(_road_center(x_road), 0.035, _road_center(z_road))
			for stripe in range(4):
				var across := -3.6 + float(stripe) * 2.4
				crosswalk_mm.set_instance_transform(
					cw_instance,
					Transform3D(Basis(Vector3.UP, PI * 0.5), intersection + Vector3(across, 0.0, 6.2))
				)
				cw_instance += 1
				crosswalk_mm.set_instance_transform(
					cw_instance,
					Transform3D(Basis(), intersection + Vector3(6.2, 0.0, across))
				)
				cw_instance += 1

	var sign_mesh := BoxMesh.new()
	sign_mesh.size = Vector3(0.12, 0.75, 2.3)
	var sign_mat := StandardMaterial3D.new()
	sign_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sign_mat.vertex_color_use_as_albedo = true
	var sign_mm := _make_multimesh(sign_mesh, sign_mat, 256, true)
	var sign_colors := [
		Color(0.15, 2.5, 3.1), Color(2.7, 0.28, 2.5), Color(2.4, 1.55, 0.25),
		Color(0.35, 2.5, 1.25), Color(2.5, 0.45, 0.20)
	]
	for i in range(256):
		var side := -1.0 if i % 2 == 0 else 1.0
		var x_road := (i * 3) % CITY_ROAD_COUNT
		var z_road := ((i / 8) * 5) % CITY_ROAD_COUNT
		var horizontal := i % 3 == 0
		var basis := Basis(Vector3.UP, PI * 0.5) if horizontal else Basis()
		var pos := Vector3(
			_road_center(x_road) + (0.0 if horizontal else side * 10.1),
			3.05,
			_road_center(z_road) + (side * 10.1 if horizontal else 0.0)
		)
		sign_mm.set_instance_transform(i, Transform3D(basis, pos))
		sign_mm.set_instance_color(i, sign_colors[i % sign_colors.size()])

	var billboard_mesh := BoxMesh.new()
	billboard_mesh.size = Vector3(0.15, 3.3, 7.0)
	var billboard_mat := StandardMaterial3D.new()
	billboard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	billboard_mat.vertex_color_use_as_albedo = true
	var billboard_mm := _make_multimesh(billboard_mesh, billboard_mat, 128, true)
	for i in range(128):
		var side := -1.0 if i % 2 == 0 else 1.0
		var x_road := (i * 7) % CITY_ROAD_COUNT
		var z_road := ((i / 5) * 9) % CITY_ROAD_COUNT
		var horizontal := i % 2 == 0
		var y := 12.0 + 6.5 * float(i % 5)
		var basis := Basis(Vector3.UP, PI * 0.5) if horizontal else Basis()
		var pos := Vector3(
			_road_center(x_road) + (0.0 if horizontal else side * 10.6),
			y,
			_road_center(z_road) + (side * 10.6 if horizontal else 0.0)
		)
		billboard_mm.set_instance_transform(i, Transform3D(basis, pos))
		billboard_mm.set_instance_color(i, sign_colors[(i + 2) % sign_colors.size()])

	rain_mm = MultiMesh.new()
	rain_mm.transform_format = MultiMesh.TRANSFORM_3D
	var rain_mesh := BoxMesh.new()
	rain_mesh.size = Vector3(0.012, 0.55, 0.012)
	rain_mm.mesh = rain_mesh
	rain_mm.instance_count = RAIN_COUNT
	var rain_mat := StandardMaterial3D.new()
	rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_mat.albedo_color = Color(0.55, 0.72, 1.0, 0.34)
	rain_mesh.material = rain_mat
	var rain_holder := MultiMeshInstance3D.new()
	rain_holder.multimesh = rain_mm
	add_child(rain_holder)
	rain_ox.resize(RAIN_COUNT)
	rain_oz.resize(RAIN_COUNT)
	rain_y0.resize(RAIN_COUNT)
	for i in range(RAIN_COUNT):
		rain_ox[i] = rng.randf_range(-22.0, 22.0)
		rain_oz[i] = rng.randf_range(-26.0, 26.0)
		rain_y0[i] = rng.randf_range(0.0, 30.0)


func _spawn_buildings(windows: ImageTexture = null) -> void:
	for chunk in building_chunks:
		chunk.queue_free()
	building_chunks.clear()
	if windows == null:
		windows = _window_texture()

	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	var roof_unit := BoxMesh.new()
	roof_unit.size = Vector3.ONE
	var block_count := 64
	var roof_count := 64
	for cz in range(-3, 4):
		for cx in range(-3, 4):
			var chunk := Node3D.new()
			chunk.position = Vector3(float(cx) * 512.0, 0.0, float(cz) * 512.0)
			add_child(chunk)
			building_chunks.append(chunk)
			var kind := posmod(cx * 2 + cz * 3 + 7, building_materials.size())
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = unit
			mm.instance_count = block_count
			var roof_mm := MultiMesh.new()
			roof_mm.transform_format = MultiMesh.TRANSFORM_3D
			roof_mm.mesh = roof_unit
			roof_mm.instance_count = roof_count

			var instance := 0
			var roof_instance := 0
			for bz in range(8):
				for bx in range(8):
					var block_center := Vector3(
						chunk.position.x - 256.0 + float(bx) * CITY_GRID + CITY_GRID * 0.5,
						0.0,
						chunk.position.z - 256.0 + float(bz) * CITY_GRID + CITY_GRID * 0.5
					)
					var district_radius := Vector2(block_center.x, block_center.z).length()
					roof_mm.set_instance_transform(
						roof_instance,
						Transform3D(Basis().scaled(Vector3(38.0, 0.24, 38.0)), block_center + Vector3(0, 0.12, 0))
					)
					roof_instance += 1
					var side_x := -1.0 if (bx + bz) % 2 == 0 else 1.0
					var side_z := -1.0 if (bx * 3 + bz) % 2 == 0 else 1.0
					var w := rng.randf_range(11.0, 22.0)
					var d := rng.randf_range(11.0, 22.0)
					var h := rng.randf_range(14.0, 42.0)
					if district_radius < 680.0:
						h = rng.randf_range(48.0, 160.0) # Downtown Los Santos skyscrapers
					elif district_radius < 1280.0:
						h = rng.randf_range(24.0, 85.0)  # Midtown / Commercial towers
					var pos := Vector3(
						block_center.x + side_x * rng.randf_range(7.0, 11.0),
						h * 0.5,
						block_center.z + side_z * rng.randf_range(7.0, 11.0)
					)
					mm.set_instance_transform(
						instance, Transform3D(Basis().scaled(Vector3(w, h, d)), pos)
					)
					instance += 1

			unit.material = building_materials[kind]
			var holder := MultiMeshInstance3D.new()
			holder.multimesh = mm
			chunk.add_child(holder)
			var roof_holder := MultiMeshInstance3D.new()
			roof_holder.multimesh = roof_mm
			roof_unit.material = roof_mech_mat
			chunk.add_child(roof_holder)


func _spawn_arches() -> void:
	for arch in arch_nodes:
		arch.queue_free()
	arch_nodes.clear()
	for i in range(14):
		var arch := Node3D.new()
		for side in [-1, 1]:
			var pillar := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.7, 7.0, 0.7)
			pillar.mesh = pm
			var pmat := StandardMaterial3D.new()
			pmat.albedo_color = Color(0.05, 0.05, 0.08)
			pillar.material_override = pmat
			pillar.position = Vector3(side * 6.3, 3.5, 0)
			arch.add_child(pillar)
		var beam := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(13.4, 0.8, 0.9)
		beam.mesh = bm
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.04, 0.04, 0.07)
		beam.material_override = bmat
		beam.position = Vector3(0, 7.1, 0)
		arch.add_child(beam)
		var neon := MeshInstance3D.new()
		var nm := BoxMesh.new()
		nm.size = Vector3(12.6, 0.08, 0.08)
		neon.mesh = nm
		var nmat := StandardMaterial3D.new()
		nmat.emission_enabled = true
		nmat.emission = Color(0.2, 2.8, 3.2) if i % 2 == 0 else Color(3.0, 0.35, 2.6)
		neon.material_override = nmat
		neon.position = Vector3(0, 6.68, 0)
		arch.add_child(neon)
		arch.position = Vector3(0, 0, -40.0 - 160.0 * i)
		add_child(arch)
		arch_nodes.append(arch)


func _spawn_traffic() -> void:
	var colors := [
		Color(0.08, 0.09, 0.12), Color(0.55, 0.57, 0.62), Color(0.48, 0.08, 0.08),
		Color(0.06, 0.16, 0.35), Color(0.12, 0.22, 0.12), Color(0.62, 0.52, 0.12)
	]
	for i in range(TRAFFIC_COUNT):
		_recycle_traffic(i, true)
		traffic_mm.set_instance_color(i, colors[i % colors.size()])


func _build_pedestrians() -> void:
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.44, 0.78, 0.26)
	var body_mat := StandardMaterial3D.new()
	body_mat.vertex_color_use_as_albedo = true
	body_mat.roughness = 0.82
	pedestrian_body_mm = _make_multimesh(body_mesh, body_mat, PEDESTRIAN_COUNT, true)

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.13
	head_mesh.height = 0.26
	head_mesh.radial_segments = 10
	head_mesh.rings = 6
	var head_mat := StandardMaterial3D.new()
	head_mat.vertex_color_use_as_albedo = true
	head_mat.roughness = 0.68
	pedestrian_head_mm = _make_multimesh(head_mesh, head_mat, PEDESTRIAN_COUNT, true)

	var leg_mesh := BoxMesh.new()
	leg_mesh.size = Vector3(0.12, 0.62, 0.14)
	var leg_mat := StandardMaterial3D.new()
	leg_mat.vertex_color_use_as_albedo = true
	leg_mat.roughness = 0.88
	pedestrian_leg_mm = _make_multimesh(leg_mesh, leg_mat, PEDESTRIAN_COUNT * 2, true)

	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.10, 0.58, 0.10)
	var arm_mat := StandardMaterial3D.new()
	arm_mat.vertex_color_use_as_albedo = true
	arm_mat.roughness = 0.75
	pedestrian_arm_mm = _make_multimesh(arm_mesh, arm_mat, PEDESTRIAN_COUNT * 2, true)
	_spawn_pedestrians()


func _spawn_pedestrians() -> void:
	pedestrians.clear()
	var coats := [
		Color(0.08, 0.10, 0.14), Color(0.35, 0.08, 0.10), Color(0.05, 0.16, 0.20),
		Color(0.18, 0.14, 0.22), Color(0.30, 0.25, 0.16), Color(0.55, 0.52, 0.46)
	]
	var skin := [Color(0.48, 0.31, 0.21), Color(0.68, 0.49, 0.34), Color(0.26, 0.17, 0.12)]
	var pants := [Color(0.045, 0.055, 0.080), Color(0.080, 0.070, 0.060), Color(0.035, 0.045, 0.060)]
	for i in range(PEDESTRIAN_COUNT):
		pedestrians.append({
			"x": 0.0, "z": 0.0, "axis": "z",
			"speed": rng.randf_range(0.9, 2.1),
			"dir": 1.0 if rng.randf() < 0.5 else -1.0,
			"phase": rng.randf_range(0.0, TAU)
		})
		_recycle_pedestrian(i, true)
		pedestrian_body_mm.set_instance_color(i, coats[i % coats.size()])
		pedestrian_head_mm.set_instance_color(i, skin[i % skin.size()])
		pedestrian_leg_mm.set_instance_color(i * 2, pants[i % pants.size()])
		pedestrian_leg_mm.set_instance_color(i * 2 + 1, pants[i % pants.size()])
		pedestrian_arm_mm.set_instance_color(i * 2, coats[i % coats.size()])
		pedestrian_arm_mm.set_instance_color(i * 2 + 1, coats[i % coats.size()])


func _build_aircraft() -> void:
	var fuselage_mat := StandardMaterial3D.new()
	fuselage_mat.albedo_color = Color(0.16, 0.18, 0.22)
	fuselage_mat.metallic = 0.65
	fuselage_mat.roughness = 0.35
	var wing_mat := StandardMaterial3D.new()
	wing_mat.albedo_color = Color(0.10, 0.12, 0.15)
	wing_mat.metallic = 0.60
	wing_mat.roughness = 0.40
	plane_strobe_mat = StandardMaterial3D.new()
	plane_strobe_mat.emission_enabled = true
	plane_strobe_mat.emission = Color(3.5, 0.35, 0.25)

	for i in range(3):
		var plane := Node3D.new()
		var fuselage := MeshInstance3D.new()
		var body := CylinderMesh.new()
		body.top_radius = 0.55
		body.bottom_radius = 0.35
		body.height = 10.0
		body.radial_segments = 10
		fuselage.mesh = body
		fuselage.material_override = fuselage_mat
		fuselage.rotation_degrees = Vector3(90, 0, 0)
		plane.add_child(fuselage)

		var wing := MeshInstance3D.new()
		var wing_mesh := BoxMesh.new()
		wing_mesh.size = Vector3(13.0, 0.18, 2.0)
		wing.mesh = wing_mesh
		wing.material_override = wing_mat
		wing.position = Vector3(0, 0.1, 0.4)
		plane.add_child(wing)

		var tail := MeshInstance3D.new()
		var tail_mesh := BoxMesh.new()
		tail_mesh.size = Vector3(4.4, 0.15, 1.0)
		tail.mesh = tail_mesh
		tail.material_override = wing_mat
		tail.position = Vector3(0, 0.5, 4.4)
		plane.add_child(tail)

		for x in [-6.2, 6.2]:
			var strobe := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(0.30, 0.12, 0.30)
			strobe.mesh = sm
			strobe.material_override = plane_strobe_mat
			strobe.position = Vector3(x, 0.15, 0.4)
			plane.add_child(strobe)

		var reset := Vector3(
			[-260.0, 230.0, -180.0][i],
			[82.0, 104.0, 94.0][i],
			[-260.0, -210.0, -310.0][i]
		)
		var dir: Vector3 = [Vector3(1, 0, 0.16), Vector3(-1, 0, 0.12), Vector3(0.55, 0, 1)][i].normalized()
		plane.position = reset
		add_child(plane)
		plane.look_at(plane.position + dir, Vector3.UP)
		aircraft.append({"node": plane, "dir": dir, "speed": [42.0, 50.0, 34.0][i], "reset_base": reset})


func _build_night_sky() -> void:
	star_mm = MultiMesh.new()
	star_mm.transform_format = MultiMesh.TRANSFORM_3D
	var star_mesh := BoxMesh.new()
	star_mesh.size = Vector3(0.18, 0.18, 0.18)
	star_mm.mesh = star_mesh
	star_mm.instance_count = STAR_COUNT
	var star_mat := StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.albedo_color = Color(0.72, 0.80, 1.0)
	star_mesh.material = star_mat
	var star_holder := MultiMeshInstance3D.new()
	star_holder.multimesh = star_mm
	add_child(star_holder)
	for i in range(STAR_COUNT):
		var angle := rng.randf_range(0.0, TAU)
		var height := rng.randf_range(75.0, 255.0)
		var radius := sqrt(maxf(1.0, 255.0 * 255.0 - height * height))
		star_offsets.append(Vector3(cos(angle) * radius, height, -absf(sin(angle) * radius) - 25.0))

	cloud_mm = MultiMesh.new()
	cloud_mm.transform_format = MultiMesh.TRANSFORM_3D
	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radius = 10.0
	cloud_mesh.height = 20.0
	cloud_mesh.radial_segments = 10
	cloud_mesh.rings = 6
	cloud_mm.mesh = cloud_mesh
	cloud_mm.instance_count = CLOUD_COUNT
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.albedo_color = Color(0.055, 0.065, 0.105, 0.42)
	cloud_mesh.material = cloud_mat
	var cloud_holder := MultiMeshInstance3D.new()
	cloud_holder.multimesh = cloud_mm
	add_child(cloud_holder)
	for i in range(CLOUD_COUNT):
		cloud_offsets.append(Vector3(
			rng.randf_range(-270.0, 270.0),
			rng.randf_range(95.0, 155.0),
			rng.randf_range(-280.0, -120.0)
		))

	moon_node = MeshInstance3D.new()
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 8.0
	moon_mesh.height = 16.0
	moon_mesh.radial_segments = 18
	moon_mesh.rings = 12
	moon_node.mesh = moon_mesh
	var moon_mat := StandardMaterial3D.new()
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_mat.albedo_color = Color(0.88, 0.92, 1.0)
	moon_node.material_override = moon_mat
	add_child(moon_node)


func _build_landmarks() -> void:
	var silhouette := StandardMaterial3D.new()
	silhouette.albedo_color = Color(0.020, 0.024, 0.036)
	silhouette.roughness = 0.65
	silhouette.metallic = 0.20

	var empire := Node3D.new()
	var tiers := [[12.0, 22.0], [9.0, 16.0], [6.0, 12.0], [3.5, 9.0]]
	for i in range(tiers.size()):
		var part := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(tiers[i][0], tiers[i][1], tiers[i][0])
		part.mesh = pm
		part.material_override = silhouette
		part.position.y = 11.0 + float(i) * 14.5
		empire.add_child(part)
	var spire := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.05
	sm.bottom_radius = 0.55
	sm.height = 18.0
	spire.mesh = sm
	spire.material_override = silhouette
	spire.position.y = 78.0
	empire.add_child(spire)
	empire.position = Vector3(-48.0, 0, -265.0)
	add_child(empire)
	landmark_nodes.append(empire)
	landmark_bases.append(empire.position)

	var moscow := Node3D.new()
	var tower_tiers := [[15.0, 14.0], [12.0, 13.0], [9.0, 12.0], [6.0, 11.0]]
	for i in range(tower_tiers.size()):
		var tier := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(tower_tiers[i][0], tower_tiers[i][1], tower_tiers[i][0])
		tier.mesh = tm
		tier.material_override = silhouette
		tier.position.y = 7.0 + float(i) * 12.0
		moscow.add_child(tier)
	var crown := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 7.5
	cm.bottom_radius = 2.0
	cm.height = 5.0
	crown.mesh = cm
	crown.material_override = silhouette
	crown.position.y = 55.0
	moscow.add_child(crown)
	var tower_spire := MeshInstance3D.new()
	var tsm := CylinderMesh.new()
	tsm.top_radius = 0.05
	tsm.bottom_radius = 0.45
	tsm.height = 16.0
	tower_spire.mesh = tsm
	tower_spire.material_override = silhouette
	tower_spire.position.y = 65.0
	moscow.add_child(tower_spire)
	moscow.position = Vector3(54.0, 0, -235.0)
	add_child(moscow)
	landmark_nodes.append(moscow)
	landmark_bases.append(moscow.position)


func _build_car() -> void:
	car = Node3D.new()
	add_child(car)
	front_wheel_pivots.clear()
	wheel_rollers.clear()
	rear_wheel_rollers.clear()
	front_wheel_rollers.clear()
	brake_lights.clear()

	car_body = MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.82, 0.48, 4.1)
	car_body.mesh = body_mesh
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.85, 0.08, 0.12)
	body_mat.metallic = 0.88
	body_mat.roughness = 0.18
	body_mat.emission_enabled = true
	body_mat.emission = Color(0.85, 0.02, 0.06)
	body_mat.emission_energy_multiplier = 0.45
	car_body.material_override = body_mat
	car_body.position = Vector3(0, 0.42, 0)
	car.add_child(car_body)

	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.38, 0.38, 1.85)
	cabin.mesh = cabin_mesh
	var cabin_mat := StandardMaterial3D.new()
	cabin_mat.albedo_color = Color(0.02, 0.03, 0.05)
	cabin_mat.metallic = 0.95
	cabin_mat.roughness = 0.05
	cabin.material_override = cabin_mat
	cabin.position = Vector3(0, 0.80, 0.12)
	car.add_child(cabin)

	# 4 Wheels: Front axle at z = -1.35, Rear axle at z = 1.35
	var tire_mat := StandardMaterial3D.new()
	tire_mat.albedo_color = Color(0.03, 0.03, 0.04)
	tire_mat.roughness = 0.85

	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.22, 0.24, 0.28)
	rim_mat.metallic = 0.95
	rim_mat.roughness = 0.15

	var hub_mat := StandardMaterial3D.new()
	hub_mat.albedo_color = Color(0.1, 0.8, 1.0)
	hub_mat.emission_enabled = true
	hub_mat.emission = Color(0.3, 2.2, 3.2)
	hub_mat.emission_energy_multiplier = 1.2

	var caliper_mat := StandardMaterial3D.new()
	caliper_mat.albedo_color = Color(0.9, 0.05, 0.08)
	caliper_mat.metallic = 0.8
	caliper_mat.roughness = 0.3

	for x in [-0.82, 0.82]:
		for z in [-1.35, 1.35]:
			var is_front := float(z) < 0.0  # -Z is forward in Godot
			var pivot := Node3D.new()
			pivot.position = Vector3(x, 0.24, z)
			car.add_child(pivot)

			if is_front:
				front_wheel_pivots.append(pivot)

			# Static Brake Caliper (does not spin with tire)
			var caliper := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = Vector3(0.08, 0.12, 0.12)
			caliper.mesh = cm
			caliper.material_override = caliper_mat
			caliper.position = Vector3(-0.04 if x > 0.0 else 0.04, 0.10, 0.0)
			pivot.add_child(caliper)

			# Spinning Wheel Roller
			var roller := Node3D.new()
			pivot.add_child(roller)
			wheel_rollers.append(roller)
			if is_front:
				front_wheel_rollers.append(roller)
			else:
				rear_wheel_rollers.append(roller)

			# Tire rubber mesh
			var tire := MeshInstance3D.new()
			var tm := CylinderMesh.new()
			tm.top_radius = 0.26
			tm.bottom_radius = 0.26
			tm.height = 0.20
			tire.mesh = tm
			tire.material_override = tire_mat
			tire.rotation_degrees = Vector3(0, 0, 90)
			roller.add_child(tire)

			# Inner alloy rim
			var rim := MeshInstance3D.new()
			var rm := CylinderMesh.new()
			rm.top_radius = 0.18
			rm.bottom_radius = 0.18
			rm.height = 0.21
			rim.mesh = rm
			rim.material_override = rim_mat
			rim.rotation_degrees = Vector3(0, 0, 90)
			roller.add_child(rim)

			# Cyber Neon Center Hub
			var hub := MeshInstance3D.new()
			var hm := CylinderMesh.new()
			hm.top_radius = 0.07
			hm.bottom_radius = 0.07
			hm.height = 0.22
			hub.mesh = hm
			hub.material_override = hub_mat
			hub.rotation_degrees = Vector3(0, 0, 90)
			roller.add_child(hub)

			# Visual spoke cross
			var spoke := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(0.215, 0.30, 0.04)
			spoke.mesh = sm
			spoke.material_override = rim_mat
			roller.add_child(spoke)

	# Front Neon Headlight Strips (-Z)
	_neon_child(car, Vector3(-0.58, 0.38, -2.06), Vector3(0.44, 0.10, 0.08), Color(2.8, 2.8, 3.2))
	_neon_child(car, Vector3(0.58, 0.38, -2.06), Vector3(0.44, 0.10, 0.08), Color(2.8, 2.8, 3.2))

	# Rear Neon Taillight Strips (+Z)
	_neon_child(car, Vector3(-0.62, 0.42, 2.06), Vector3(0.38, 0.10, 0.08), Color(3.5, 0.1, 0.15))
	_neon_child(car, Vector3(0.62, 0.42, 2.06), Vector3(0.38, 0.10, 0.08), Color(3.5, 0.1, 0.15))

	var brake_mat := StandardMaterial3D.new()
	brake_mat.emission_enabled = true
	brake_mat.emission = Color(3.8, 0.05, 0.05)
	brake_mat.emission_energy_multiplier = 0.9
	for x in [-0.62, 0.62]:
		var light_mesh := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.38, 0.10, 0.08)
		light_mesh.mesh = lm
		light_mesh.material_override = brake_mat
		light_mesh.position = Vector3(x, 0.52, 2.06)
		car.add_child(light_mesh)
		brake_lights.append(light_mesh)

	boost_flame = MeshInstance3D.new()
	var flame := BoxMesh.new()
	flame.size = Vector3(0.85, 0.16, 0.9)
	boost_flame.mesh = flame
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_color = Color(0.2, 2.8, 4.2)
	boost_flame.material_override = flame_mat
	boost_flame.position = Vector3(0, 0.36, 2.45)
	car.add_child(boost_flame)

	# Aerodynamic Carbon Fiber Splitter, Diffuser, Side Mirrors, and GT Spoiler
	var carbon_mat := StandardMaterial3D.new()
	if ResourceLoader.exists("res://textures/car_carbon.jpg"):
		carbon_mat.albedo_texture = load("res://textures/car_carbon.jpg")
		carbon_mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
	else:
		carbon_mat.albedo_color = Color(0.04, 0.04, 0.05)
	carbon_mat.metallic = 0.92
	carbon_mat.roughness = 0.18

	# Front Aero Splitter (-Z)
	var splitter := MeshInstance3D.new()
	var spm := BoxMesh.new()
	spm.size = Vector3(1.86, 0.05, 0.42)
	splitter.mesh = spm
	splitter.material_override = carbon_mat
	splitter.position = Vector3(0, 0.16, -2.12)
	car.add_child(splitter)

	# Rear Aero Diffuser (+Z)
	var diffuser := MeshInstance3D.new()
	var dfm := BoxMesh.new()
	dfm.size = Vector3(1.82, 0.08, 0.36)
	diffuser.mesh = dfm
	diffuser.material_override = carbon_mat
	diffuser.position = Vector3(0, 0.20, 2.14)
	car.add_child(diffuser)

	# Aerodynamic Side Mirrors
	var mirror_glass_mat := StandardMaterial3D.new()
	mirror_glass_mat.albedo_color = Color(0.95, 0.95, 0.98)
	mirror_glass_mat.metallic = 0.98
	mirror_glass_mat.roughness = 0.02
	for mx in [-0.94, 0.94]:
		var mirror := MeshInstance3D.new()
		var mm_box := BoxMesh.new()
		mm_box.size = Vector3(0.22, 0.12, 0.15)
		mirror.mesh = mm_box
		mirror.material_override = carbon_mat
		mirror.position = Vector3(mx, 0.82, -0.42)
		car.add_child(mirror)

	# GT Racing Wing
	for sx in [-0.62, 0.62]:
		var stand := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.06, 0.32, 0.14)
		stand.mesh = sm
		stand.material_override = carbon_mat
		stand.position = Vector3(sx, 0.72, 1.78)
		car.add_child(stand)
	var wing := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(1.76, 0.05, 0.40)
	wing.mesh = wm
	wing.material_override = carbon_mat
	wing.position = Vector3(0, 0.88, 1.82)
	wing.rotation_degrees = Vector3(-6, 0, 0)
	car.add_child(wing)

	# Cyan Neon Underglow Tube
	_neon_child(car, Vector3(0, 0.10, 0), Vector3(1.4, 0.04, 3.2), Color(0.2, 2.5, 3.8))

	headlight = SpotLight3D.new()
	headlight.light_color = Color(0.85, 0.92, 1.0)
	headlight.light_energy = 4.2
	headlight.spot_range = 75.0
	headlight.spot_angle = 38.0
	headlight.spot_attenuation = 1.2
	headlight.shadow_enabled = false
	headlight.position = Vector3(0, 0.85, -1.95) # Facing forward (-Z)
	headlight.rotation_degrees = Vector3(-6, 0, 0)
	car.add_child(headlight)


func _build_cops() -> void:
	cop_light_a = StandardMaterial3D.new()
	cop_light_a.emission_enabled = true
	cop_light_a.emission = Color(4.0, 0.1, 0.1)
	cop_light_b = StandardMaterial3D.new()
	cop_light_b.emission_enabled = true
	cop_light_b.emission = Color(0.1, 0.3, 4.0)

	for i in range(MAX_COPS):
		var node := Node3D.new()
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.9, 0.55, 4.2)
		body.mesh = bm
		var body_mat := StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.055, 0.06, 0.09)
		body_mat.metallic = 0.5
		body_mat.roughness = 0.35
		body.material_override = body_mat
		body.position = Vector3(0, 0.5, 0)
		node.add_child(body)

		var stripe := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(1.94, 0.16, 1.2)
		stripe.mesh = sm
		var stripe_mat := StandardMaterial3D.new()
		stripe_mat.albedo_color = Color(0.75, 0.78, 0.85)
		stripe.material_override = stripe_mat
		stripe.position = Vector3(0, 0.44, 0.3)
		node.add_child(stripe)

		var light_a := MeshInstance3D.new()
		var lam := BoxMesh.new()
		lam.size = Vector3(0.55, 0.14, 0.22)
		light_a.mesh = lam
		light_a.material_override = cop_light_a
		light_a.position = Vector3(-0.3, 0.88, 0.1)
		node.add_child(light_a)

		var light_b := MeshInstance3D.new()
		var lbm := BoxMesh.new()
		lbm.size = Vector3(0.55, 0.14, 0.22)
		light_b.mesh = lbm
		light_b.material_override = cop_light_b
		light_b.position = Vector3(0.3, 0.88, 0.1)
		node.add_child(light_b)

		node.visible = false
		add_child(node)
		cops.append({"node": node, "active": false, "speed": 0.0})


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(flash_rect)

	speed_tint = ColorRect.new()
	speed_tint.color = Color(0.45, 0.85, 1.0, 0.0)
	speed_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	speed_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(speed_tint)

	var panel := ColorRect.new()
	panel.color = Color(0.015, 0.015, 0.035, 0.62)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -122
	panel.offset_bottom = -14
	canvas.add_child(panel)

	hud_speed = _label(panel, Vector2(18, 4), 48)
	hud_speed.add_theme_color_override("font_color", Color(0.65, 1.0, 1.0))
	hud_gear = _label(panel, Vector2(132, 16), 24)
	hud_gear.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25))
	hud_time = _label(panel, Vector2(445, 6), 22)
	hud_distance = _label(panel, Vector2(18, 56), 16)
	hud_boost = _label(panel, Vector2(445, 34), 16)
	hud_best = _label(panel, Vector2(445, 58), 14)
	hud_damage_label = _label(panel, Vector2(445, 82), 14)
	hud_damage_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.25))
	hud_heat = _label(panel, Vector2(180, 10), 28)

	speed_bar = _bar(panel, Vector2(18, 92), Color(0.1, 0.75, 1.0), 250, 7)
	boost_bar = _bar(panel, Vector2(445, 100), Color(0.2, 0.75, 1.0), 170, 5)
	damage_bar = _bar(panel, Vector2(290, 78), Color(1.0, 0.35, 0.1), 130, 5)

	pursuit_panel = ColorRect.new()
	pursuit_panel.color = Color(0.06, 0.06, 0.10, 0.75)
	pursuit_panel.anchor_left = 0.5
	pursuit_panel.anchor_right = 0.5
	pursuit_panel.anchor_top = 1.0
	pursuit_panel.anchor_bottom = 1.0
	pursuit_panel.offset_left = -150
	pursuit_panel.offset_right = 150
	pursuit_panel.offset_top = -146
	pursuit_panel.offset_bottom = -128
	canvas.add_child(pursuit_panel)
	pursuit_bar = _bar(pursuit_panel, Vector2(0, 0), Color(0.2, 0.9, 0.3), 300, 18)

	hud_center = _label(canvas, Vector2(0, 0), 52)
	hud_center.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hud_center.position = Vector2(-180, 58)
	hud_center.custom_minimum_size = Vector2(360, 70)
	hud_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_center.add_theme_color_override("font_color", Color(1.0, 3.0, 4.0))


func _label(parent: Node, pos: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95))
	parent.add_child(label)
	return label


func _bar(parent: Node, pos: Vector2, c: Color, width: int, height: int) -> ColorRect:
	var bar := ColorRect.new()
	bar.position = pos
	bar.color = c
	bar.custom_minimum_size = Vector2(width, height)
	parent.add_child(bar)
	return bar


func _neon_box(pos: Vector3, size: Vector3, c: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = c
	mesh.material_override = mat
	mesh.position = pos
	add_child(mesh)


func _neon_child(parent: Node3D, pos: Vector3, size: Vector3, c: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = c
	mesh.material_override = mat
	mesh.position = pos
	parent.add_child(mesh)


func _multimesh_box(size: Vector3, c: Color, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = size
	mm.mesh = mesh
	mm.instance_count = count
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = c
	mesh.material = mat
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = mm
	add_child(holder)
	return mm


func _build_audio() -> void:
	if no_audio:
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	audio_player = AudioStreamPlayer.new()
	audio_player.stream = generator
	audio_player.volume_db = -8.0
	add_child(audio_player)
	audio_player.play()
	audio_pb = audio_player.get_stream_playback()


func _audio_process() -> void:
	if no_audio or audio_pb == null:
		return
	var pushes := 0
	while audio_pb.get_frames_available() >= 128 and pushes < 4:
		var buf := PackedVector2Array()
		buf.resize(128)
		for i in range(128):
			var s := _audio_sample()
			buf[i] = Vector2(s, s)
		audio_pb.push_buffer(buf)
		pushes += 1


func _audio_sample() -> float:
	var dt := 1.0 / float(MIX_RATE)
	var vf := vel.length()
	var rpm_k := clampf((rpm - 900.0) / 6300.0, 0.05, 1.0)
	var engine_freq := 48.0 + rpm_k * 175.0
	phase_e = fposmod(phase_e + engine_freq * dt, 1.0)
	phase_sub = fposmod(phase_sub + engine_freq * 0.5 * dt, 1.0)
	var saw := 2.0 * phase_e - 1.0
	var sub := 2.0 * phase_sub - 1.0
	var sqr := 1.0 if phase_e < 0.5 else -1.0
	var engine_vol := 0.18 + clampf(vf / 60.0, 0.0, 1.0) * 0.20 + (0.12 if (boosting or burnout_mode) else 0.0)
	var sample := (saw * 0.45 + sub * 0.35 + sqr * 0.20) * engine_vol

	# Police siren
	var any_cop := false
	var nearest := 9999.0
	for cop in cops:
		if cop.active:
			any_cop = true
			nearest = minf(nearest, (cop.node.position - car.position).length())
	if any_cop:
		var siren_phase := fposmod(Time.get_ticks_msec() * 0.0018, 1.0)
		var siren_freq := 640.0 + sin(siren_phase * TAU) * 180.0
		phase_siren = fposmod(phase_siren + siren_freq * dt, 1.0)
		var siren_vol := clampf(1.0 - nearest / 130.0, 0.0, 1.0) * 0.16
		sample += sin(phase_siren * TAU) * siren_vol

	# Dynamic tire skid / drift screech sound with slip-velocity pitch modulation
	var noise := rng.randf_range(-1.0, 1.0)
	noise_lpf = lerpf(noise_lpf, noise, 0.25)
	if skid_level > 0.05:
		var skid_freq := 700.0 + skid_level * 500.0
		var skid_mod := sin(Time.get_ticks_msec() * 0.001 * skid_freq * TAU)
		sample += (noise_lpf * 0.6 + skid_mod * 0.4) * skid_level * 0.22

	# Impact crunch
	if impact_env > 0.001:
		sample += noise * impact_env * 0.60
		impact_env *= 0.960

	# Thunder rumble
	if thunder_env > 0.001:
		sample += noise_lpf * thunder_env * 0.75

	return clampf(sample, -1.0, 1.0)


func _load_best() -> void:
	var f := FileAccess.open("user://best_time.cfg", FileAccess.READ)
	if f != null:
		var value := f.get_line().to_float()
		best_time = value if value > 0.0 else INF
		f.close()


func _save_best() -> void:
	var f := FileAccess.open("user://best_time.cfg", FileAccess.WRITE)
	if f != null:
		f.store_line(str(best_time))
		f.close()
