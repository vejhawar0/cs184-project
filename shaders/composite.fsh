#version 120

uniform sampler2D gcolor;        // scene color from gbuffers
uniform sampler2D depthtex0;     // scene depth
uniform sampler2D shadow;        // shadow map depth texture

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

varying vec2 texcoord;           // screen UV, passed from composite.vsh

void main() {
    vec4 color = texture2D(gcolor, texcoord);
    float depth = texture2D(depthtex0, texcoord).r;


    if (depth == 1.0) {
        gl_FragColor = color;
        return;
    }

    vec4 ndcPos = vec4(texcoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * ndcPos;
    viewPos /= viewPos.w;
    vec4 worldPos = gbufferModelViewInverse * viewPos;

    vec4 shadowViewPos = shadowModelView * worldPos;
    vec4 shadowClipPos = shadowProjection * shadowViewPos;
    vec3 shadowNDC = shadowClipPos.xyz / shadowClipPos.w;
    vec3 shadowUV = shadowNDC * 0.5 + 0.5;

    float bias = 0.005;
    float shadowDepth = texture2D(shadow, shadowUV.xy).r;
    float inShadow = shadowUV.z - bias > shadowDepth ? 1.0 : 0.0;

    // Darken shadowed pixels
    float shadowFactor = 1.0 - (inShadow * 0.6);  // 0.6 = shadow darkness
    gl_FragColor = vec4(color.rgb * shadowFactor, color.a);
}