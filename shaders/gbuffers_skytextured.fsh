#version 120

uniform sampler2D texture;

varying vec2 coord;
varying vec4 glcolor;

/* DRAWBUFFERS:0 */

void main() {
	vec4 color = texture2D(texture, coord) * glcolor;

	color.rgb *= 1 + (1 * float(color.r > 0.5));

	gl_FragData[0] = color; //gcolor
}