#version 130

#include "/lib/settings.glsl"
#include "/lib/math.glsl"
#include "/lib/kernels.glsl"
#include "/lib/transform.glsl"
#include "/lib/framebuffer.glsl"

uniform float nearInverse;
uniform float aspectRatio;

uniform vec3  fogColor;

uniform int   frameCounter;

in vec2 coord;


//////////////////////////////////////////////////////////////////////////////
//                     SCREEN SPACE AMBIENT OCCLUSION
//////////////////////////////////////////////////////////////////////////////


float depthToleranceAttenuation(float depthDiff, float peak) {
    return peak - abs(depthDiff - peak);
}
float AmbientOcclusionLOW_test1(vec3 screenPos, float sampleSize) {

    float linearDepth = linearizeDepthf(screenPos.z, 20);
    float size        = sampleSize / linearDepth * fovScale;

    float dither      = Bayer4(screenPos.xy * screenSize) * 64;

    float occlusion = 0;
    for (int i = 0; i < 8; i++) {
        vec2 sample       = blue_noise_disk[ int( mod(i + dither, 64) ) ] * size + screenPos.xy;

        float sampleDepth = linearizeDepthf(getDepth_int(sample), 20);
        float occ         = (linearDepth - sampleDepth);
        occlusion        += depthToleranceAttenuation(occ, 1);
    }
    occlusion = saturate(-occlusion * .3 + 1);
 
    return sq(occlusion);
}

float AmbientOcclusionLOW(vec3 screenPos, vec3 normal, float size) {
    vec3 viewPos           = toView(screenPos * 2 - 1);

    vec3 tangent           = normalize(vec3(normal.y - normal.z, -normal.x, normal.x));               //Simply Creating A orthogonal vector to the normals, actual tangent doesnt really matter
    mat3 TBN               = mat3(tangent, cross(tangent, normal), normal);

    float ditherTimesSize  = (Bayer4(screenPos.xy * screenSize) * 0.8 + 0.2) * size;
    float depthTolerance   = 0.075/-viewPos.z;

    float hits = 0;
    vec3 sample;
    for (int i = 0; i < 8; i++) {
        sample      = half_sphere_8[i] * ditherTimesSize; 
        sample.z   += 0.05;                                                       // Adding a small (5cm) z-offset to avoid clipping into the block due to precision errors
        sample      = TBN * sample;
        sample      = backToClip(sample + viewPos) * 0.5 + 0.5;                  // Converting Sample to screen space, since normals are in view space
    
        float hitDepth = getDepth_int(sample.xy);

        hits += float(sample.z > hitDepth && (sample.z - hitDepth) < depthTolerance);
    }

    hits  = -hits * 0.125 + 1;
    return sq(hits);
}

float AmbientOcclusionHIGH(vec3 screenPos, vec3 normal, float size) {
    vec3 viewPos           = toView(screenPos * 2 - 1);

    vec3 tangent           = normalize(cross(normal, vec3(0,0,1)));               //Simply Creating A orthogonal vector to the normals, actual tangent doesnt really matter
    mat3 TBN               = mat3(tangent, cross(tangent, normal), normal);

    float ditherTimesSize  = (Bayer4(screenPos.xy * screenSize) * 0.8 + 0.2) * size;
    float depthTolerance   = 0.075/-viewPos.z;

    float hits = 0;
    vec3 sample;
    for (int i = 0; i < 16; i++) {
        sample      = half_sphere_16[i] * ditherTimesSize; 
        sample.z   += 0.05;                                                       // Adding a small (5cm) z-offset to avoid clipping into the block due to precision errors
        sample      = TBN * sample;
        sample      = backToClip(sample + viewPos) * 0.5 + 0.5;                  // Converting Sample to screen space, since normals are in view space
    
        float hitDepth = getDepth_int(sample.xy);

        hits += float(sample.z > hitDepth && (sample.z - hitDepth) < depthTolerance);
    }

    hits  = -hits * 0.0625 + 1;
    return sq(hits);
}

float AmbientOcclusionOutline(vec3 screenPos, float depthfactor, float sizemultiplier) {
    float ldepth  = linearizeDepthf(screenPos.z, depthfactor);
    float AO      = 0;
    vec2  dither  = vec2(Bayer4(screenSize * screenPos.xy), Bayer4(screenSize * screenPos.xy + 1));
    vec2  size    = dither * fovScale * (1 - screenPos.z) * sizemultiplier;

    for (int x = -1; x <= 1; x+=2) {
        for (int y = -1; y <= 1; y+=2) {
            vec2 sample = vec2(x,y) * size + screenPos.xy;

            float sampleDepth = linearizeDepthf(getDepth_int(sample), depthfactor);
            AO               += depthToleranceAttenuation(ldepth - sampleDepth, 1);
        }
    }
    return 1 - saturate(AO);;
}


// Spins A point around the origin (negate for full coverage)
vec2 spiralOffset(float x, float expansion) {
    float n = fract(x * expansion) * PI;
    return vec2(cos(n), sin(n)) * x;
}

// Based on BSL's AO implementation
float BSLAO(vec3 screenPos, float radius) {
    if (screenPos.z >= 1.0 || screenPos.z < 0.56) {return 1.0;};

    #ifdef TAA
    float dither = fract(Bayer8(screenPos.xy * screenSize) + (frameCounter * 0.136)) * 0.2;
    #else
    float dither = Bayer8(screenPos.xy * screenSize) * 0.2;
    #endif 
    float depth  = linearizeDepthf(screenPos.z, nearInverse);

    float size   = clamp(aspectRatio * radius * gbufferProjection[1][1] * 1/depth, 0.01, 0.2);

    float occlusion = 0.0;
    float sample    = 0.3 + dither;
    for (int i = 0; i < 4; i++) {
        vec2 offs = spiralOffset(sample + dither, 8) * size;

        for (int o = 0; o < 2; o++) {
            float sdepth = linearizeDepthf(getDepth_int(screenPos.xy + offs), nearInverse);
            occlusion   += clamp((depth - sdepth) * 4, -1, 1);
            offs         = -offs;
        }

        sample += 0.2;
    }
    occlusion *= 0.125;

    return clamp(1 - occlusion, 0, 1);
}

/* DRAWBUFFERS:0 */
void main() {
    vec3  color       = getAlbedo(coord);
    float depth       = getDepth(coord);
    float type        = getType(coord);


    //////////////////////////////////////////////////////////
    //                  SSAO
    //////////////////////////////////////////////////////////

    #ifdef SCREEN_SPACE_AMBIENT_OCCLUSION

        if (abs(type - 50) > .2 && depth != 1) {

            #if   SSAO_QUALITY == 1

                //vec3 normal = getNormal(coord);
                //color      *= AmbientOcclusionLOW(vec3(coord, depth), normal, 0.5) * SSAO_STRENGTH + (1 - SSAO_STRENGTH);
                color      *= BSLAO(vec3(coord, depth), 0.1) * SSAO_STRENGTH + (1 - SSAO_STRENGTH);

            #elif SSAO_QUALITY == 2

                vec3 normal = getNormal(coord);
                color      *= AmbientOcclusionHIGH(vec3(coord, depth), normal, 0.5) * SSAO_STRENGTH + (1 - SSAO_STRENGTH);

            #endif
            
        }

    #endif

    //color = 1 - vec3(AmbientOcclusion(Bayer4(coord * screenSize)));
    //color = vec3(BSLAO(vec3(coord, depth), 0.1));

    FD0 = vec4(color, 1.0);
}