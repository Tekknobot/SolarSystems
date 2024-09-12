extends Node2D

var orbit_radii = []
var orbit_speeds = [0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025]

var planet_colors = [
	Color(0.2, 0.4, 0.8),  # Earth Blue (Ocean)
	Color(0.0, 0.5, 0.2),  # Earth Green (Forests)
	Color(0.6, 0.3, 0.1),  # Earth Brown (Land)
	Color(0.8, 0.8, 0.8),  # Earth White (Clouds)
	Color(0.8, 0.2, 0.1),  # Mars Red (Surface)
	Color(0.9, 0.6, 0.4),  # Mars Orange (Dunes)
	Color(0.7, 0.5, 0.3),  # Mars Beige (Soil)
	Color(0.5, 0.3, 0.2),  # Mars Dark Brown (Canyons)
	Color(0.6, 0.4, 0.3),  # Mars Light Brown (Rock formations)
	Color(0.9, 0.7, 0.5),  # Mars Pale Orange (Dust storms)
	Color(0.3, 0.2, 0.1),  # Mars Very Dark Brown
	Color(0.1, 0.1, 0.1)   # Mars Almost Black
]

var sun_colors = [
	Color(1.0, 0.9, 0.4),  # Bright Yellow
	Color(1.0, 0.8, 0.0),  # Soft Yellow-Orange
	Color(1.0, 0.6, 0.0),  # Orange
	Color(1.0, 0.4, 0.0),  # Reddish Orange
	Color(1.0, 0.2, 0.0),  # Deep Red
	Color(0.5, 0.1, 0.0),  # Darker Red
	Color(0.3, 0.0, 0.0),  # Very Dark Red
	Color(0.1, 0.1, 0.1),  # Black
	Color(1.0, 0.4, 0.0),  # Back to Reddish Orange
	Color(1.0, 0.6, 0.0),  # Back to Orange
	Color(1.0, 0.8, 0.0)   # Back to Yellow
]

var current_color_index = 0
var color_transition_time = 0.08  # Time between color transitions (slower transition for realism)
var color_timer = 0.0
var current_sun_color = sun_colors[0]  # Initial sun color

var sun_radius = 89
var planet_nodes = []
var orbit_color = Color(0.2, 0.2, 0.2)
var orbit_thickness = 5
var min_orbit_gap = 75
var max_orbit_gap = 125
var perspective_strength = 0.275
var num_additional_planets = randi_range(0, 10)
var pixel_size = 8
var dissolve_duration = 5.0
var collision_effect_radius = 1

# In the main script or a dedicated trajectory script
@onready var trajectory_line = Line2D.new()
var asteroid_travel_time = 3.0  # Time to travel from start to target (in seconds)
var elapsed_time = 0.0  # Time elapsed since the asteroid started moving

var asteroid_start_position = Vector2.ZERO
var asteroid_target_position = Vector2.ZERO
var asteroid_active = false

var trajectory_dissolve_duration = 1.0  # Duration to dissolve the trajectory line (in seconds)
var trajectory_dissolve_timer = 0.0  # Timer to track dissolution progress
var trajectory_dissolving = false  # Flag to indicate if dissolution is in progress

# Define a buffer distance just off the viewport
var buffer_distance = 2000  # You can adjust this value as needed
var check_collision_after_travel = false


func _ready():
	add_child(trajectory_line)
	trajectory_line.default_color = Color(1.0, 1.0, 1.0)  # Red color for the trajectory
	trajectory_line.width = 2  # Adjust the width as needed

	randomize()
	initialize_orbits()
	initialize_planets()
	
func initialize_orbits():
	orbit_radii.clear()
	var last_radius = 0
	for i in range(10):
		var new_radius = last_radius + randf_range(min_orbit_gap, max_orbit_gap)
		if i >= 2:
			orbit_radii.append(Vector2(new_radius, new_radius))
		last_radius = new_radius

func initialize_planets():
	planet_nodes.clear()
	num_additional_planets = randi_range(0, 50)
	for i in range(orbit_radii.size() + num_additional_planets):
		var orbit_index = (i + 2) % orbit_radii.size()
		var radius = randi_range(8, 34)
		planet_nodes.append({
			"color": planet_colors[i % planet_colors.size()],
			"original_color": planet_colors[i % planet_colors.size()],
			"radius": radius,
			"angle": randf() * PI * 2,
			"speed": orbit_speeds[i % orbit_speeds.size()],
			"orbit_index": orbit_index,
			"original_speed": orbit_speeds[i % orbit_speeds.size()],
			"pixels": [],
			"dissolving": false,
			"glow_dissolving": false,  # Add glow dissolving property
			"glow_dissolve_timer": 0.0  # Add glow dissolve timer
		})
		create_pixels_for_planet(planet_nodes[-1])

func create_pixels_for_planet(planet):
	var pixel_radius = pixel_size / 2
	for x in range(-planet["radius"], planet["radius"], pixel_size):
		for y in range(-planet["radius"], planet["radius"], pixel_size):
			if x * x + y * y <= planet["radius"] * planet["radius"]:
				planet["pixels"].append({
					"position": Vector2(x, y),
					"color": planet["color"],
					"lifetime": dissolve_duration,
					"velocity": Vector2(randf_range(-50, 50), randf_range(-50, 50)),
					"scale": 1.0
				})

func get_random_planet_target() -> Vector2:
	if planet_nodes.size() == 0:
		return Vector2.ZERO  # No planets to target
	
	var random_planet = planet_nodes[randi() % planet_nodes.size()]
	return get_planet_position(random_planet)  # Function to get the current position of the planet

func get_planet_position(planet: Dictionary) -> Vector2:
	# Get the orbit index and the corresponding orbit radius
	var orbit_index = planet["orbit_index"]
	var radius_x = orbit_radii[orbit_index].x
	var radius_y = orbit_radii[orbit_index].y * (1 - perspective_strength * (orbit_index / orbit_radii.size()))

	# Calculate the position based on the angle and radius
	var x = cos(planet["angle"]) * radius_x
	var y = sin(planet["angle"]) * radius_y

	# Apply perspective transformation
	var planet_position = Vector2(x - y, (x + y) * perspective_strength)
	
	# Adjust for the center of the orbit system
	return planet_position + Vector2.ZERO  # Assuming the center is at (0, 0); adjust if needed

func update_trajectory_line(start_position: Vector2, target_position: Vector2):
	trajectory_line.clear_points()  # Clear previous trajectory
	trajectory_line.add_point(start_position)
	trajectory_line.add_point(target_position)


func create_asteroid_trajectory():
	var viewport_size = get_viewport().size

	# Choose a random off-screen direction
	var direction = randi() % 4  # Randomly pick a direction (0 = left, 1 = right, 2 = top, 3 = bottom)
	match direction:
		0:  # Left of the screen
			asteroid_start_position = Vector2(-buffer_distance, randf_range(0, viewport_size.y))
		1:  # Right of the screen
			asteroid_start_position = Vector2(viewport_size.x + buffer_distance, randf_range(0, viewport_size.y))
		2:  # Above the screen
			asteroid_start_position = Vector2(randf_range(0, viewport_size.x), -buffer_distance)
		3:  # Below the screen
			asteroid_start_position = Vector2(randf_range(0, viewport_size.x), viewport_size.y + buffer_distance)

	asteroid_target_position = get_planet_position(planet_nodes[randi() % planet_nodes.size()])
	asteroid_active = true
	elapsed_time = 0.0  # Reset elapsed time for new trajectory
	update_trajectory_line(asteroid_start_position, asteroid_target_position)
	
	print("Asteroid created from ", asteroid_start_position, " to ", asteroid_target_position)

func _process(delta):
	if asteroid_active:
		elapsed_time += delta
		var progress = min(elapsed_time / asteroid_travel_time, 1.0)
		var current_position = lerp(asteroid_start_position, asteroid_target_position, progress)
		update_trajectory_line(asteroid_start_position, current_position)
		
		if progress >= 1.0:
			asteroid_active = false
			check_collision_after_travel = true  # Set flag to check collision after reaching target
			start_dissolving_trajectory()  # Start dissolving the trajectory line
	
	trajectory_line.default_color.a = 1.0;
	
	if trajectory_dissolving:
		trajectory_dissolve_timer += delta
		var dissolve_progress = min(trajectory_dissolve_timer / trajectory_dissolve_duration, 1.0)
		trajectory_line.default_color.a = 1.0 - dissolve_progress  # Fade out the line

		if dissolve_progress >= 1.0:
			trajectory_dissolving = false
			trajectory_line.clear_points()  # Remove the trajectory line after dissolving

	# Update planet positions
	update_planet_positions(delta)
	
	# Check for collisions if flag is set
	if check_collision_after_travel:
		check_collisions(delta)  # Perform collision checks after asteroid finishes travel
		check_collision_after_travel = false  # Reset flag after checking collisions
	
	# Update dissolve effect
	update_pixels(delta)
	
	# Update sun color transition timer
	color_timer += delta
	if color_timer >= color_transition_time:
		color_timer = 0.0
		current_color_index = (current_color_index + 1) % sun_colors.size()

	var next_color_index = (current_color_index + 1) % sun_colors.size()
	var t = color_timer / color_transition_time
	
	var current_color = sun_colors[current_color_index]
	var next_color = sun_colors[next_color_index]
	current_sun_color = Color(
		lerp(current_color.r, next_color.r, t),
		lerp(current_color.g, next_color.g, t),
		lerp(current_color.b, next_color.b, t),
		lerp(current_color.a, next_color.a, t)
	)
	
	queue_redraw()

func start_dissolving_trajectory():
	trajectory_dissolving = true
	trajectory_dissolve_timer = 0.0  # Reset the dissolve timer


func check_collisions(delta):
	for i in range(planet_nodes.size()):
		var planet_a = planet_nodes[i]
		for j in range(i + 1, planet_nodes.size()):
			var planet_b = planet_nodes[j]
			if planet_a["orbit_index"] == planet_b["orbit_index"]:
				var orbit_index = planet_a["orbit_index"]
				var radius_x = orbit_radii[orbit_index].x
				var radius_y = orbit_radii[orbit_index].y * (1 - perspective_strength * (orbit_index / orbit_radii.size()))
				var x_a = cos(planet_a["angle"]) * radius_x
				var y_a = sin(planet_a["angle"]) * radius_y
				var x_b = cos(planet_b["angle"]) * radius_x
				var y_b = sin(planet_b["angle"]) * radius_y
				var pos_a = Vector2(x_a - y_a, (x_a + y_a) * perspective_strength)
				var pos_b = Vector2(x_b - y_b, (x_b + y_b) * perspective_strength)
				if pos_a.distance_to(pos_b) < (planet_a["radius"] + planet_b["radius"] + collision_effect_radius):
					# Start dissolving for both planets
					planet_a["dissolving"] = true
					planet_b["dissolving"] = true
					planet_a["glow_dissolving"] = true
					planet_b["glow_dissolving"] = true
					planet_a["glow_dissolve_timer"] = dissolve_duration
					planet_b["glow_dissolve_timer"] = dissolve_duration

	if not check_collision_after_travel:
		return
	
	for planet in planet_nodes:
		var planet_position = get_planet_position(planet)
		if asteroid_target_position.distance_to(planet_position) < (planet["radius"] + collision_effect_radius + 8):
			handle_asteroid_collision(planet)
			check_collision_after_travel = false
			break  # Assuming asteroid hits only one planet per trajectory


func handle_asteroid_collision(planet):
	# Handle collision effect here
	planet["dissolving"] = true
	planet["glow_dissolving"] = true
	planet["glow_dissolve_timer"] = dissolve_duration

	# Optionally, deactivate the asteroid
	asteroid_active = false
	trajectory_line.clear_points()

func update_pixels(delta):
	var planets_to_remove = []
	for planet in planet_nodes:
		if planet["dissolving"]:
			for pixel in planet["pixels"]:
				pixel["position"] += pixel["velocity"] * delta
				pixel["lifetime"] -= delta
				pixel["scale"] = max(0.0, pixel["scale"] - delta * (1.0 / dissolve_duration))
				if pixel["lifetime"] <= 0 or pixel["scale"] <= 0:
					planet["pixels"].erase(pixel)
			if len(planet["pixels"]) == 0:
				planets_to_remove.append(planet)
	for planet in planets_to_remove:
		planet_nodes.erase(planet)

func update_planet_positions(delta):
	for planet in planet_nodes:
		if not planet["dissolving"]:  # Only update planets that are not dissolving
			planet["angle"] += planet["speed"] * delta
			# Ensure angle stays within 0 to 2 * PI
			planet["angle"] = fmod(planet["angle"], 2 * PI)


func _draw():
	var orbit_center = Vector2(0, 0)
	
	# Draw the sun
	draw_circle(orbit_center, sun_radius, current_sun_color)
	
	# Draw the orbits
	for i in range(orbit_radii.size()):
		var radius_x = orbit_radii[i].x
		var radius_y = orbit_radii[i].y * (1 - perspective_strength * (i / orbit_radii.size()))
		draw_isometric_ellipse(orbit_center, radius_x, radius_y, orbit_color, orbit_thickness)
	
	# Draw planets with glow
	for planet_data in planet_nodes:
		var orbit_index = planet_data["orbit_index"]
		var radius_x = orbit_radii[orbit_index].x
		var radius_y = orbit_radii[orbit_index].y * (1 - perspective_strength * (orbit_index / orbit_radii.size()))
		var x = cos(planet_data["angle"]) * radius_x
		var y = sin(planet_data["angle"]) * radius_y
		var planet_position = orbit_center + Vector2(x - y, (x + y) * perspective_strength)
		var planet_size = planet_data["radius"] * (1 - perspective_strength * (orbit_index / orbit_radii.size()))

		# Draw the glow effect
		if planet_data["glow_dissolving"]:
			var dissolve_progress = min(1.0, planet_data["glow_dissolve_timer"] / dissolve_duration)
			var glow_color = Color(planet_data["color"].r, planet_data["color"].g, planet_data["color"].b, 0.25 * (1.0 - dissolve_progress))  # Adjust alpha for glow
			var glow_radius = planet_size * 1.5 * (1.0 - dissolve_progress)  # Adjust the radius for the glow effect
			draw_circle(planet_position, glow_radius, glow_color)
		else:
			var glow_color = Color(planet_data["color"].r, planet_data["color"].g, planet_data["color"].b, 0.25)  # Default glow color
			var glow_radius = planet_size * 1.5  # Default glow radius
			draw_circle(planet_position, glow_radius, glow_color)
		
		if planet_data["dissolving"]:
			# Draw dissolving pixels
			for pixel in planet_data["pixels"]:
				draw_circle(planet_position + pixel["position"], (pixel_size / 2) * pixel["scale"], pixel["color"])
		else:
			# Draw the planet itself
			draw_circle(planet_position, planet_size, planet_data["color"])

func draw_isometric_ellipse(center: Vector2, radius_x: float, radius_y: float, color: Color, thickness: int):
	var points = []
	var segments = 360
	for i in range(segments):
		var angle = i * 2 * PI / segments
		var x = cos(angle) * radius_x
		var y = sin(angle) * radius_y
		var iso_x = x - y
		var iso_y = (x + y) * perspective_strength
		points.append(center + Vector2(iso_x, iso_y))
	for i in range(segments):
		var next_index = (i + 1) % segments
		draw_line(points[i], points[next_index], color, thickness)

# Reset system when space bar is pressed
func _input(event):
	if event.is_action_pressed("ui_select"):  # "ui_select" is the default action for the space bar
		reset_system()
		
	if event.is_action_pressed("mouse_left"):  # Check if the left mouse button is pressed
		create_asteroid_trajectory()  # Start a new asteroid trajectory

func reset_system():
	# Reinitialize the orbit radii and planets
	orbit_radii.clear()
	planet_nodes.clear()
	
	initialize_orbits()
	initialize_planets()  # Reinitialize planets with new sizes and angles
