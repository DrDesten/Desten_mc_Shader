struct MaterialInfo {
    vec4  color;
    vec3  normal;

    float roughness;
    vec3  f0;
    float emission;
    float AO;
    float height;

    float subsurface;
    float porosity;
};

uniform sampler2D specular;
uniform sampler2D normals;

// TEXTURE READOUTS
vec4 NormalTex(vec2 coord) {
    return texture2D(normals, coord);
}
vec4 SpecularTex(vec2 coord) {
    return texture2D(specular, coord);
}


// NORMAL TEXTURE
vec3 extractNormal(vec4 nTex, vec4 sTex) {
    vec2 n = nTex.xy * 2 - 1;
    return vec3(n, sqrt(1.0 - dot(n, n)));
}
float extractAO(vec4 nTex, vec4 sTex) {
    return nTex.b;
}
float extractHeight(vec4 nTex, vec4 sTex) {
    return nTex.a;
}


// SPECULAR TEXTURE
float extractRoughness(vec4 nTex, vec4 sTex) {
    float tmp = 1. - sTex.r;
    return tmp*tmp;
}

float extractF0(vec4 nTex, vec4 sTex) {
    return sTex.g;
}
vec3 extractF0(vec4 nTex, vec4 sTex, vec3 albedo) {
    return sTex.g < 0.9 ? sTex.ggg : albedo;
}
bool isMetal(vec4 nTex, vec4 sTex) {
    return sTex.g > 0.9;
}

float extractSubsurf(vec4 nTex, vec4 sTex) {
    return sTex.z > 0.25294117647 && !isMetal(nTex, sTex) ? sTex.z : 0.0;
}
float extractPorosity(vec4 nTex, vec4 sTex) {
    return sTex.z < 0.25294117647 && !isMetal(nTex, sTex) ? sTex.z : 0.0;
}

float extractEmission(vec4 nTex, vec4 sTex) {
    return sTex.a * float(sTex.a != 1);
}


///////////////////////////////////////////////////////////////////////////////////////////////////////

MaterialInfo FullMaterial(vec2 coord, vec4 albedo) {
    vec4 NT = NormalTex(coord);
    vec4 ST = SpecularTex(coord);

    return MaterialInfo(
        albedo,
        extractNormal(NT, ST),

        extractRoughness(NT, ST),
        extractF0(NT, ST, albedo.rgb),
        extractEmission(NT, ST),
        extractAO(NT, ST),
        extractHeight(NT, ST),

        extractSubsurf(NT, ST),
        extractPorosity(NT, ST)
    );
}