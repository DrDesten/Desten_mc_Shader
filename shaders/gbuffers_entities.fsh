

uniform int worldTime;

#include "/lib/settings.glsl"
#include "/lib/math.glsl"
#include "/lib/gbuffers_basics.glsl"
#include "/lib/unpackPBR.glsl"

uniform vec4 entityColor;
uniform vec2 screenSize;
uniform vec2 screenSizeInverse;

in float id;
in vec2  lmcoord;
in vec2  coord;
in vec4  glcolor;
in mat3  tbn;
// tbn[0] = tangent vector
// tbn[1] = binomial vector
// tbn[2] = normal vector

/* DRAWBUFFERS:012345 */
void main() {
	vec4 albedo = getAlbedo(coord) * glcolor;
	albedo.rgb  = mix(albedo.rgb, entityColor.rgb, entityColor.a);

	MaterialInfo MatTex = FullMaterial(coord, albedo);

	float f0 = MatTex.f0;
	float emission = MatTex.emission;
	float smoothness = MatTex.roughness;
	float height = MatTex.height;
	float subsurface = MatTex.subsurface;
	float ao = MatTex.ao * glcolor.a;
	
	vec3  normal = tbn * MatTex.normal;

	#ifdef WHITE_WORLD
		albedo.rgb = vec3(1);
	#endif


	//mat3 tbn = cotangentFrame(normal, -viewpos, gl_FragCoord.xy * screenSizeInverse);


	gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(normal, 1);
	gl_FragData[2] = vec4(lmcoord, vec2(1));
	gl_FragData[3] = vec4(codeID(id), vec3(1));

	gl_FragData[4] = vec4(f0, emission, smoothness, subsurface);
	gl_FragData[5] = vec4(ao, height, vec2(1));
}