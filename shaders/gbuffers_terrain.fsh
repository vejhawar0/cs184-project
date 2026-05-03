#version 120

uniform sampler2D gtexture;
uniform sampler2D lightmap;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 color;
varying vec3 viewNormal;
varying float reflectivity;

/* DRAWBUFFERS:01 */
void main() {
    vec4 albedo = texture2D(gtexture, texcoord) * color;
    vec3 light  = texture2D(lightmap, lmcoord).rgb;

    // colortex0: lit color (unchanged from before)
    gl_FragData[0] = vec4(albedo.rgb * light, albedo.a);

    // colortex1: pack view-space normal into rgb (mapped 0..1) and reflectivity into alpha.
    gl_FragData[1] = vec4(viewNormal * 0.5 + 0.5, reflectivity);
}
