shader_type spatial;
render_mode cull_back, diffuse_burley, specular_disabled;

// Port of Unity SVOM/Gradient/Emission/Smooth.
uniform vec4 top_color : source_color = vec4(0.15930933, 0.33061928, 0.4716981, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.2671057, 0.6257078, 0.7735849, 1.0);
uniform vec3 split_pos = vec3(1.0, 1.0, 1.0);
uniform vec3 split_normal_vector = vec3(0.0, 1.0, 0.0);
uniform float gradient_power : hint_range(0.001, 10.0, 0.01) = 2.0;
uniform vec4 reflect_color : source_color = vec4(2.9960787, 2.9960787, 2.9960787, 1.0);
uniform float reflect_power : hint_range(0.1, 16.0, 0.1) = 8.0;

varying vec3 object_position;

void vertex() {
	object_position = VERTEX;
}

void fragment() {
	float normal_length = max(length(split_normal_vector), 0.0001);
	float split_distance = dot(split_pos - object_position, split_normal_vector);
	float gradient_position = max(split_distance, 0.0) / normal_length;
	float gradient = smoothstep(0.0, gradient_power, gradient_position);
	vec3 gradient_color = mix(top_color.rgb, bottom_color.rgb, gradient);

	vec3 view_direction = normalize(VIEW);
	vec3 surface_normal = normalize(NORMAL);
	float fresnel = pow(max(1.0 - dot(surface_normal, view_direction), 0.0), reflect_power);
	vec3 crystal_color = gradient_color + reflect_color.rgb * fresnel;

	ALBEDO = crystal_color;
	EMISSION = crystal_color;
	ROUGHNESS = 0.5;
}
