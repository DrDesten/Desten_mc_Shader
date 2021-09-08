#version 120

#include "/lib/gamma.glsl"

uniform sampler2D lightmap;
uniform sampler2D texture;

varying vec2 lmcoord;
varying vec2 coord;
varying vec4 glcolor;

/* DRAWBUFFERS:03 */
void main() {
	vec4 color = texture2D(texture, coord, 0) * glcolor;
	color 	  *= texture2D(lightmap, lmcoord);
	gamma(color.rgb);

	gl_FragData[0] = color; //gcolor
	gl_FragData[1] = vec4(1); //set type to water
}