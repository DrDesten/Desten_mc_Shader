#version 120

#include "/lib/settings.glsl"
#include "/lib/math.glsl"
#include "/lib/vertex_transform.glsl"

uniform float frameTimeCounter;
uniform vec3 cameraPosition;

attribute vec4 mc_Entity;

flat varying float blockId;

varying vec2 coord;
varying vec2 lmcoord;
varying vec3 worldPos;
varying vec3 viewPos;

varying vec4 glcolor;
varying mat3 tbn;
// tbn[0] = tangent vector
// tbn[1] = binomial vector
// tbn[2] = normal vector

void main(){

	vec4 viewPosition   = getView4();
	vec4 playerPosition = toPlayer(viewPosition);
	vec4 worldPosition  = playerPosition + vec4(cameraPosition, 0);

	#ifdef WATER_WAVES

		if (mc_Entity.x == 1001) {

			// "Physical" Wave Offsets
			float zOffset    = (sin((worldPosition.x * 0.1) + (frameTimeCounter)) - 0.5) * 0.05;
			float zOffset2   = (sin((worldPosition.z * 0.2) + (frameTimeCounter * 3)) - 0.5) * 0.025;
			// Appling them (y Direction aka "up")
			worldPosition.y += (zOffset + zOffset2) * WATER_WAVE_AMOUNT;

			vec4 clipPos = worldToClip(worldPosition - vec4(cameraPosition, 0));

			gl_Position = clipPos;

		} else {

			gl_Position = ftransform();

		}
	
	#else

		gl_Position = ftransform();

	#endif

	tbn			 = getTBN();
	
	worldPos	 = worldPosition.xyz + gbufferModelViewInverse[3].xyz;
	viewPos      = viewPosition.xyz;

	blockId 	 = mc_Entity.x;
    coord 		 = getCoord();
	lmcoord      = getLmCoord();
	glcolor 	 = gl_Color;

}