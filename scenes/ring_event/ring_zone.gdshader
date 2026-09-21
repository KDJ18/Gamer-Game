shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always, blend_mix;
// Flat "magic circle" for the ring timing event (DESIGN.md section 4).
// Renders the same annulus zones and shrinking marker as RingWidget's 2D
// _draw(), from the same distance formula d = abs(r - target_radius), just
// evaluated per-pixel here instead of via painter's-algorithm circles.
// All radii are in world units (RingWidget3D converts from the design's px
// values with RingWidget3D.WORLD_UNITS_PER_PX).

uniform float mesh_radius = 4.5;
uniform float target_radius = 1.33;
uniform float good_half = 1.1;
uniform float great_half = 0.4;
uniform float crit_half = 0.05;
uniform float ring_radius = 3.83;
uniform float stroke_width = 0.035;

uniform vec4 good_color : source_color = vec4(0.20, 0.75, 0.30, 0.75);
uniform vec4 great_color : source_color = vec4(0.85, 0.75, 0.15, 0.8);
uniform vec4 crit_color : source_color = vec4(0.80, 0.20, 0.20, 0.85);
uniform vec4 bg_color : source_color = vec4(0.05, 0.05, 0.09, 0.0);
uniform vec4 marker_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float r = length(local_pos.xz);

	if (r > mesh_radius) {
		discard;
	}

	float d = abs(r - target_radius);
	vec4 col = bg_color;
	if (d <= good_half) {
		col = good_color;
	}
	if (d <= great_half) {
		col = great_color;
	}
	if (d <= crit_half) {
		col = crit_color;
	}

	float marker_d = abs(r - ring_radius);
	float marker_mask = 1.0 - smoothstep(0.0, stroke_width, marker_d);
	col = mix(col, marker_color, marker_mask);

	ALBEDO = col.rgb;
	ALPHA = col.a;
}
