shader_type canvas_item;
// Outcome gauge ring: one continuous disaster -> jackpot gradient, ordered-dithered to a small palette.

uniform int count = 0;
uniform vec4 colors[10];
uniform float starts[10];
uniform float ends[10];
uniform float mids[10];
uniform float angle = 0.0;
uniform int focus = -1;
uniform float pulse = 0.0;
uniform float ring_in = 0.25;
uniform float ring_out = 0.40;

const float BAYER[16] = float[16](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);

vec3 color_at(float a) {
	if (count == 0) {
		return vec3(0.15, 0.15, 0.27);
	}
	if (a <= mids[0]) {
		return colors[0].rgb;
	}
	if (a >= mids[count - 1]) {
		return colors[count - 1].rgb;
	}
	for (int i = 0; i < 9; i++) {
		if (i >= count - 1) {
			break;
		}
		if (a <= mids[i + 1]) {
			float t = (a - mids[i]) / max(mids[i + 1] - mids[i], 0.0001);
			t = t * t * (3.0 - 2.0 * t);
			t = t * t * (3.0 - 2.0 * t);
			return mix(colors[i].rgb, colors[i + 1].rgb, t);
		}
	}
	return colors[count - 1].rgb;
}

int slice_at(float a) {
	for (int i = 0; i < 10; i++) {
		if (i >= count) {
			break;
		}
		if (a >= starts[i] && a < ends[i]) {
			return i;
		}
	}
	return count - 1;
}

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float r = length(uv);
	vec4 outc = vec4(0.0);
	if (r <= ring_out + 0.008 && r >= ring_in - 0.02) {
		if (r < ring_in) {
			if (r > ring_in - 0.016) {
				outc = vec4(0.04, 0.08, 0.27, 1.0);
			}
		} else if (r > ring_out) {
			outc = vec4(0.024, 0.043, 0.133, 1.0);
		} else {
			float th = atan(uv.x, -uv.y);
			float a = fract((th - angle) / TAU);
			vec3 c = color_at(a);
			float rr = (r - ring_in) / (ring_out - ring_in);
			float shade = 0.55 + 0.55 * sin(PI * rr);
			float glint = max(0.0, cos(th + 2.2));
			shade += 0.35 * pow(glint, 10.0) * pow(sin(PI * rr), 2.0);
			if (focus >= 0) {
				shade *= (slice_at(a) == focus) ? (1.12 + pulse) : 0.38;
			}
			if (a < 0.004 || a > 0.996) {
				c = vec3(0.024, 0.043, 0.133);
				shade = 1.0;
			}
			// tick marks on the inner edge
			float tk = abs(fract(a * 40.0) - 0.5);
			if (rr < 0.16 && tk > 0.44) {
				c = vec3(0.024, 0.043, 0.133);
				shade = 1.0;
			}
			int bx = int(mod(FRAGCOORD.x, 4.0));
			int by = int(mod(FRAGCOORD.y, 4.0));
			float b = (BAYER[by * 4 + bx] + 0.5) / 16.0 - 0.5;
			vec3 q = clamp(c * shade, 0.0, 1.0) * 6.0 + b;
			q = floor(q + 0.5) / 6.0;
			outc = vec4(q, 1.0);
		}
	}
	COLOR = outc;
}
