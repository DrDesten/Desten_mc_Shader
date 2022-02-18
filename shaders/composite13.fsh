

#include "/lib/settings.glsl"
#include "/lib/math.glsl"
#include "/lib/composite_basics.glsl"

#ifdef TAA
#include "/lib/kernels.glsl"
#include "/lib/transform.glsl"
uniform int taaIndex;
uniform sampler2D colortex5;
#endif

#ifdef BLOOM
uniform sampler2D colortex4;
#endif

vec2 coord = gl_FragCoord.xy * screenSizeInverse;


void Vignette(inout vec3 color) { //Darken Screen Borders
    float dist = distance(coord.st, vec2(0.5));

    dist = (dist * dist) * (dist * 1.5);

    color.rgb *= 1 - dist;
}

vec2 scaleCoord_f(vec2 coord, float scale) { //Scales Coordinates from Screen Center
    //coord = (coord * scale) - (0.5 * (scale - 1));
    coord = scale * (coord - 0.5) + 0.5;
    return clamp(coord, 0, 0.999999);
}

vec2 lensDistorsion(vec2 coord, float scale, float distorsion) { //Distorts Image
    float dist = distance(coord, vec2(0.5));
    dist = pow(dist, 2);

    coord = mirrorClamp(coord * (scale - (dist*distorsion)));

    return coord;
}

vec3 radialBlur(vec2 coord, float samples, float amount) {
    vec3  col  = vec3(0);
    float sInv = 1 / samples;
    float mult = sInv * amount;
    for (float i = 0; i < samples; i++) {
        col += getAlbedo(scaleCoord_f(coord, (-i * mult) + 1));
    }
    return col * sInv;
}

vec3 ChromaticAbberation(vec2 coord, float amount) {
    vec3 col;
    amount = distance(coord, vec2(0.5)) * amount;

    //Red Channel
    col.r     = texture(colortex0, scaleCoord_f(coord, 1.0 - amount)).r;
    //Green Channel
    col.g     = texture(colortex0, coord).g;
    //Blue Channel
    col.b     = texture(colortex0, scaleCoord_f(coord, 1.0 + amount)).b;

    return col;
}

vec3 ChromaticAbberation_HQ(vec2 coord, float amount, int samples) {
    vec3 col;
    amount = sqmag(coord - 0.5) * amount;

    float dither = (Bayer4(coord * screenSize) * .75 + .5);

    //Red Channel
    col.r     = radialBlur(scaleCoord_f(coord, 1.0 - amount * dither), samples, amount).r;
    //Green Channel
    col.g     = radialBlur(coord, samples, amount).g;
    //Blue Channel
    col.b     = radialBlur(scaleCoord_f(coord, 1.0 + amount * dither), samples, amount).b;

    return col;
}

vec3 luminanceNeutralize(vec3 col) {
    return (col * col) / (sum(col) * sum(col));
}

// TONEMAPPING
/////////////////////////////////////////////////////////////////////////////////////////

vec3 reinhard_tonemap(vec3 color, float a) {
    return color / (a + color);
}
vec3 reinhard_luminance_tonemap(vec3 color, float a) {
    float l = luminance(color);
    return color / (a+l);
}
vec3 reinhard_jodie_tonemap(vec3 color, float a) {
    float l   = luminance(color);
    vec3 tmc  = color / (color + a);
    return mix(color / (l+a), tmc, tmc);
}
vec3 reinhard_sqrt_tonemap(vec3 color, float a) {
    return color / sqrt(color * color + a);
}


vec3 unreal_tonemap(vec3 color) {
  return color / (color + 0.155) * 1.019;
}


vec3 exp_tonemap(vec3 color, float a) {
    return 1 - exp(-color * a);
}



float PeakAttenuation(float depthDiff, float peak) {
    return peak - abs(depthDiff - peak);
}


#ifdef BLOOM

    vec3 readBloomTile(vec2 coord, float tile) {
        float tileScale  = exp2(-tile);
        vec2  tileOffset = vec2(1 - exp2(1-tile));
        vec2  tileCoord  = coord * tileScale  + tileOffset;

        return texture(colortex4, tileCoord).rgb;
    }

    vec3 readBloomTileHQ(vec2 coord, float tile) {
        float tileScale  = exp2(-tile);
        vec2  tileOffset = vec2(1 - exp2(1-tile));
        vec2  tileCoord  = coord * tileScale  + tileOffset;

        return textureBicubic(colortex4, tileCoord).rgb;
    }

    /* vec3 getBloom(vec2 coord, int tileLevel) {
        vec3 bloomColor = vec3(0);
        for (int i = 0; i < tileLevel; i++) {
            bloomColor += readBloomTile(coord, i);
        }
        return bloomColor / tileLevel;
    } */
    vec3 getBloom(vec2 coord, int tileLevel) {
        vec3 bloomColor = vec3(0);
        for (int i = 1; i <= tileLevel; i++) {
            float tileScale  = exp2(-i);
            vec2  tileOffset = vec2(1 - exp2(1-i));
            vec2  tileCoord  = coord * tileScale  + tileOffset;

            bloomColor     += texture(colortex4, tileCoord).rgb;
        }
        return bloomColor / tileLevel;
    }

    float edgeFade(vec2 coord) {
        return saturate( -4 * max(abs(0.5 - coord.x), abs(0.5 - coord.y)) + 2);
    }

    vec3 getLensFlare(vec2 coord) {
        vec2 invCoord = coord * -2 + 1; //Note: This is NDC

        vec3 lf = vec3(0);
        for (int i = 1; i <= 3; i++) {
            vec2  lfco = (invCoord * sq( 2. / i ) ) * 0.5 + 0.5;
            float w    = edgeFade(lfco);

            lf += max(readBloomTile(lfco, 4).rgb - 2.5, 0) * w;
        }
        for (int i = 1; i <= 2; i++) {
            vec2  lfco = (invCoord * -sq( 3. / i ) ) * 0.5 + 0.5;
            float w    = edgeFade(lfco);

            lf += max(readBloomTile(lfco, 4).rgb - 2.5, 0) * w;
        }

        lf = lf * lf * (1./5);

        return lf;
    }

#endif

/* DRAWBUFFERS:0 */
void main() {

    #if CHROMATIC_ABERRATION != 0
        vec3 color = ChromaticAbberation_HQ(coord, chromaticAberrationSimple, 5);
    #else
        vec3 color = getAlbedo(coord);
    #endif

    #ifdef BLOOM
        color += sq( getBloom(coord, BLOOM_RADIUS) * BLOOM_AMOUNT);
    #endif

    #if TONEMAP == 1
    color = reinhard_sqrt_tonemap(color * EXPOSURE, .5); // Tone mapping 
    color = gamma_inv(color);
    #elif TONEMAP == 2
    color = unreal_tonemap(color * EXPOSURE); // Tone mapping
    #endif

    #if CONTRAST != 0
		const float contrastAmount = 1 / (1 - (CONTRAST / 300. + 0.5)) - 1;
		color = applyContrast(color, contrastAmount);
	#endif
	#if VIBRANCE != 0
		const float vibranceAmount = (VIBRANCE / 100.);
		color = applyVibrance(color, vibranceAmount);
	#endif
	#if SATURATION != 0
		const float saturationAmount = SATURATION / 100. + 1.;
		color = applySaturation(color, saturationAmount);
	#endif
	#if BRIGHTNESS != 0
		const float brightnessAmount      = 1 / (BRIGHTNESS / 250. + 0.5) - 1;
		const float brightnessColorOffset = abs(BRIGHTNESS - 50.) / 500.;
		color = applyBrightness(color, brightnessAmount, brightnessColorOffset);
	#endif


    gl_FragData[0] = vec4(color, 1.0);
}

