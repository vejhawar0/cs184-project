#version 120

attribute vec4 mc_Entity;          // mc_Entity.x = integer block ID from block.properties

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 color;
varying vec3 viewNormal;           // surface normal in camera/view space
varying float reflectivity;        // 0 = matte, 1 = mirror

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    color = gl_Color;

    // Transform the object-space normal into view space so SSR can use it directly.
    viewNormal = normalize(gl_NormalMatrix * gl_Normal);

    int id = int(mc_Entity.x + 0.5);
    if (id == 100) {
        reflectivity = 0.7;        // glass / ice — strong, near-mirror
    } else if (id == 101) {
        reflectivity = 0.5;        // metal & gem blocks — moderate
    } else {
        reflectivity = 0.0;        // everything else stays matte
    }
}
