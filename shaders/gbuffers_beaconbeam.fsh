

#include "/lib/math.glsl"
#include "/lib/gbuffers_basics.glsl"
#include "/lib/gamma.glsl"

varying vec3 normal;
varying vec2 coord;
varying vec4 glcolor;

/* DRAWBUFFERS:023 */
void main() {

	vec4 color = texture2D(texture, coord, 0) * glcolor;
	color.rgb *= 2;
	gamma(color.rgb);


	gl_FragData[0] = color;
	gl_FragData[1] = vec4(normal, 1);
	gl_FragData[2] = vec4(codeID(50), vec3(1));
}
