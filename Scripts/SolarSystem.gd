extends Node2D

var orbit_radii = []  # Will be initialized with fixed values
var orbit_speeds = [  # Speed for each planet (you can adjust these values)
	0.5, 0.4, 0.35, 0.3, 0.25, 0.2, 0.18, 0.15, 0.12, 0.1
]

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
	Color(0.9, 0.7, 0.5)   # Mars Pale Orange (Dust storms)
]

var sun_radius = 89  # Radius for the sun
var planet_nodes = []  # Holds the planets
var orbit_color = Color(0.2, 0.2, 0.2) # Light color for orbit lines
var orbit_thickness = 5  # Adjustable thickness for orbits
var min_orbit_gap = 75  # Minimum distance between consecutive orbits
var max_orbit_gap = 125  # Maximum distance between consecutive orbits
var perspective_strength = 0.275  # Perspective strength (0 for no perspective, 1 for full perspective effect)
var num_additional_planets = randi_range(0, 10)  # Additional planets to add to the system (adjustable)
var pixel_size = 8  # Size of the pixel pieces
var dissolve_duration = 5.0  # Duration of the dissolve effect
var collision_effect_radius = 1

func _ready():
	randomize()  # Initialize random number generator
	var orbit_center = Vector2(0, 0)
	
	# Initialize fixed orbit radii
	initialize_orbits()
	
	# Initialize planets with random sizes and starting angles
	initialize_planets()
	
	# set_process(true)  # Start processing for animation

func initialize_orbits():
	# Generate a random set of orbit radii with constraints
	orbit_radii.clear()  # Clear previous radii if any
	var last_radius = 0
	for i in range(10):  # Number of orbits
		var new_radius = last_radius + randf_range(min_orbit_gap, max_orbit_gap)
		if i >= 2:  # Skip the first two orbital paths
			orbit_radii.append(Vector2(new_radius, new_radius))  # Use same value for x and y
		last_radius = new_radius

func initialize_planets():
	planet_nodes.clear()  # Clear previous planet nodes
	num_additional_planets = randi_range(0, 50)  # Randomize the number of additional planets
	
	# Initialize planets with random sizes and starting angles
	for i in range(orbit_radii.size() + num_additional_planets):
		var orbit_index = (i + 2) % orbit_radii.size()  # Adjust to skip first two orbits
		var radius = randi_range(8, 34)  # Randomize the planet radius between 5 and 34
		planet_nodes.append({
			"color": planet_colors[i % planet_colors.size()],  # Cycle through colors if needed
			"original_color": planet_colors[i % planet_colors.size()],  # Store the original color
			"radius": radius,  # Set planet radius from the randomized value
			"angle": randf() * PI * 2,  # Random starting angle for each planet
			"speed": orbit_speeds[i % orbit_speeds.size()],  # Cycle through speeds if needed
			"orbit_index": orbit_index,  # Track which orbit this planet belongs to
			"original_speed": orbit_speeds[i % orbit_speeds.size()],  # Store the original speed
			"pixels": [],  # List of pixels representing the planet
			"dissolving": false  # Flag to indicate if the planet is dissolving
		})
		# Create pixels for each planet
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
					"scale": 1.0  # Initial scale of 1.0 (normal size)
				})

func _process(delta):
	# Update planet positions
	for planet_data in planet_nodes:
		# Update the angle for next frame (move planets)
		planet_data["angle"] += planet_data["speed"] * delta
		
		# Keep angle between 0 and 2*PI
		if planet_data["angle"] > PI * 2:
			planet_data["angle"] -= PI * 2
	
	# Check for collisions
	check_collisions(delta)
	
	# Update pixels for dissolving effect
	update_pixels(delta)
	
	queue_redraw()  # Request a redraw

func check_collisions(delta):
	# Check for collisions between planets on the same orbit
	for i in range(planet_nodes.size()):
		var planet_a = planet_nodes[i]
		for j in range(i + 1, planet_nodes.size()):
			var planet_b = planet_nodes[j]
			
			# Check if planets are on the same orbit
			if planet_a["orbit_index"] == planet_b["orbit_index"]:
				# Calculate positions of planets
				var orbit_index = planet_a["orbit_index"]
				var radius_x = orbit_radii[orbit_index].x
				var radius_y = orbit_radii[orbit_index].y * (1 - perspective_strength * (orbit_index / orbit_radii.size()))
				
				var x_a = cos(planet_a["angle"]) * radius_x
				var y_a = sin(planet_a["angle"]) * radius_y
				var x_b = cos(planet_b["angle"]) * radius_x
				var y_b = sin(planet_b["angle"]) * radius_y
				
				# Apply perspective to positions
				var pos_a = Vector2(x_a - y_a, (x_a + y_a) * perspective_strength)
				var pos_b = Vector2(x_b - y_b, (x_b + y_b) * perspective_strength)
				
				# Check distance between planets
				if pos_a.distance_to(pos_b) < (planet_a["radius"] + planet_b["radius"] + collision_effect_radius):
					# Start dissolving effect
					planet_a["dissolving"] = true
					planet_b["dissolving"] = true

func update_pixels(delta):
	var planets_to_remove = []  # List of planets to remove after updating
	for planet in planet_nodes:
		if planet["dissolving"]:
			for pixel in planet["pixels"]:
				# Move the pixel by its velocity
				pixel["position"] += pixel["velocity"] * delta
				
				# Reduce lifetime and scale
				pixel["lifetime"] -= delta
				pixel["scale"] = max(0.0, pixel["scale"] - delta * (1.0 / dissolve_duration))  # Gradually shrink the pixel
				
				# Remove the pixel when its lifetime is over
				if pixel["lifetime"] <= 0 or pixel["scale"] <= 0:
					planet["pixels"].erase(pixel)
			
			# If all pixels are gone, mark the planet for removal
			if len(planet["pixels"]) == 0:
				planets_to_remove.append(planet)

	# Remove the planets that have fully dissolved
	for planet in planets_to_remove:
		planet_nodes.erase(planet)

func _draw():
	var orbit_center = Vector2(0, 0)
	
	# Draw the sun
	draw_circle(orbit_center, sun_radius, Color(1, 1, 0))  # Sun color (yellow)

	# Draw orbit lines with isometric perspective
	for i in range(orbit_radii.size()):
		var radius_x = orbit_radii[i].x
		var radius_y = orbit_radii[i].y * (1 - perspective_strength * (i / orbit_radii.size())) # Apply perspective
		draw_isometric_ellipse(orbit_center, radius_x, radius_y, orbit_color, orbit_thickness) # Draw ellipse with adjustable thickness

	# Draw planets and dissolve effect
	for planet_data in planet_nodes:
		# Get orbit radii with perspective
		var orbit_index = planet_data["orbit_index"]  # Determine which orbit this planet belongs to
		var radius_x = orbit_radii[orbit_index].x
		var radius_y = orbit_radii[orbit_index].y * (1 - perspective_strength * (orbit_index / orbit_radii.size()))
		
		# Calculate planet's new position along the elliptical orbit
		var x = cos(planet_data["angle"]) * radius_x
		var y = sin(planet_data["angle"]) * radius_y
		
		# Apply perspective to planet position
		var planet_position = orbit_center + Vector2(x - y, (x + y) * perspective_strength)
		# Apply perspective effect on the planet size
		var planet_size = planet_data["radius"] * (1 - perspective_strength * (orbit_index / orbit_radii.size()))
		
		# Draw dissolving pixels
		if planet_data["dissolving"]:
			for pixel in planet_data["pixels"]:
				# Draw the pixel with its shrinking size (scale)
				draw_circle(planet_position + pixel["position"], (pixel_size / 2) * pixel["scale"], pixel["color"])
		else:
			draw_circle(planet_position, planet_size, planet_data["color"])

# Helper function to draw an ellipse (or a circle) using lines with isometric perspective
func draw_isometric_ellipse(center: Vector2, radius_x: float, radius_y: float, color: Color, thickness: int):
	var points = []
	var segments = 360  # Number of segments for the ellipse
	for i in range(segments):
		var angle = i * 2 * PI / segments
		var x = cos(angle) * radius_x
		var y = sin(angle) * radius_y
		# Apply isometric transformation
		var iso_x = x - y
		var iso_y = (x + y) * perspective_strength
		points.append(center + Vector2(iso_x, iso_y))
	
	# Draw the ellipse by connecting the points
	for i in range(segments):
		var next_index = (i + 1) % segments
		draw_line(points[i], points[next_index], color, thickness)

# Reset system when space bar is pressed
func _input(event):
	if event.is_action_pressed("ui_select"):  # "ui_select" is the default action for the space bar
		reset_system()

func reset_system():
	# Reinitialize the orbit radii and planets
	orbit_radii.clear()
	planet_nodes.clear()
	
	initialize_orbits()
	initialize_planets()  # Reinitialize planets with new sizes and angles
