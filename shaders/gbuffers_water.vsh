#version 120

attribute vec4 mc_Entity;

uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 color;
varying vec3 viewNormal;
varying vec3 worldPos;             // true world-space position (for wave evaluation)
varying float reflectivity;
varying float isWater;             // 1.0 if this fragment is real water, 0.0 otherwise

void main() {
    // Standard transform, but we keep view-space and world-space positions around.
    vec4 viewVertex = gl_ModelViewMatrix * gl_Vertex;
    gl_Position = gl_ProjectionMatrix * viewVertex;

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    color = gl_Color;

    // World position = camera-relative world coords + camera offset.
    // gbufferModelViewInverse undoes the view transform; cameraPosition is the world origin shift.
    worldPos = (gbufferModelViewInverse * viewVertex).xyz + cameraPosition;

    viewNormal = normalize(gl_NormalMatrix * gl_Normal);

    // Other translucents (stained glass) go through this stage too — only mark water.
    isWater = (int(mc_Entity.x + 0.5) == 102) ? 1.0 : 0.0;

    reflectivity = 0.6;
}
