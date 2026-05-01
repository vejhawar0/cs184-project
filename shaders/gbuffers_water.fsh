#version 120

uniform sampler2D gtexture;
uniform sampler2D lightmap;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 color;

/* DRAWBUFFERS:0 */
void main() {
    vec4 albedo = texture2D(gtexture, texcoord) * color;
    vec3 light = texture2D(lightmap, lmcoord).rgb;
    gl_FragData[0] = vec4(albedo.rgb * light, albedo.a);
}
