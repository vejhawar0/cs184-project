#version 120

uniform sampler2D gcolor;        // colortex0: lit scene color (from gbuffers)
uniform sampler2D colortex1;     // colortex1: packed normal (rgb) + reflectivity (a)
uniform sampler2D depthtex0;     // scene depth
uniform sampler2D shadow;        // shadow map depth texture

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

varying vec2 texcoord;

// Reconstruct view-space position from screen UV + depth.
// Inverse of: clip = Projection * view; ndc = clip / clip.w; uv,depth derived from ndc.
vec3 viewPosFromDepth(vec2 uv, float depth) {
    vec4 ndcPos = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * ndcPos;
    return viewPos.xyz / viewPos.w;
}

void main() {
    vec4 color = texture2D(gcolor, texcoord);
    float depth = texture2D(depthtex0, texcoord).r;

    // Sky pixel — nothing to shade.
    if (depth == 1.0) {
        gl_FragColor = color;
        return;
    }

    vec3 viewPos  = viewPosFromDepth(texcoord, depth);
    vec4 worldPos = gbufferModelViewInverse * vec4(viewPos, 1.0);

    // ---------- Shadow mapping (unchanged) ----------
    vec4 shadowViewPos = shadowModelView * worldPos;
    vec4 shadowClipPos = shadowProjection * shadowViewPos;
    vec3 shadowNDC = shadowClipPos.xyz / shadowClipPos.w;
    vec3 shadowUV  = shadowNDC * 0.5 + 0.5;

    float bias = 0.005;
    float shadowDepth = texture2D(shadow, shadowUV.xy).r;
    float inShadow = shadowUV.z - bias > shadowDepth ? 1.0 : 0.0;
    float shadowFactor = 1.0 - (inShadow * 0.6);
    vec3 shadedColor = color.rgb * shadowFactor;

    // ---------- Screen-Space Reflections ----------
    vec4 normalRefl = texture2D(colortex1, texcoord);
    float reflectivity = normalRefl.a;

    vec3 finalColor = shadedColor;

    if (reflectivity > 0.01) {
        vec3 normal     = normalize(normalRefl.rgb * 2.0 - 1.0);
        vec3 viewDir    = normalize(viewPos);            // camera → surface
        vec3 reflectDir = reflect(viewDir, normal);      // R = V − 2(V·N)N

        // March in view space. We bias the ray off the surface along the normal
        // so step 1 doesn't immediately self-intersect.
        vec3 rayPos  = viewPos + normal * 0.05;
        vec3 rayStep = reflectDir * 0.3;                 // ~0.3 view-space units per step
        vec3 reflColor = vec3(0.0);
        float hit = 0.0;

        for (int i = 0; i < 32; i++) {
            rayPos += rayStep;

            // Project the ray's current view-space position back to screen UV.
            vec4 clip = gbufferProjection * vec4(rayPos, 1.0);
            vec3 ndc  = clip.xyz / clip.w;
            vec2 uv   = ndc.xy * 0.5 + 0.5;

            // Off-screen: SSR can't help us, abort.
            if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) break;

            // What's actually visible at that screen point?
            float sampledDepth = texture2D(depthtex0, uv).r;
            vec3  sceneViewPos = viewPosFromDepth(uv, sampledDepth);

            // View-space z is negative going forward, so "ray went behind geometry" = rayPos.z < scene z.
            float diff = rayPos.z - sceneViewPos.z;
            if (diff < 0.0 && diff > -0.6) {
                reflColor = texture2D(gcolor, uv).rgb;
                hit = 1.0;
                break;
            }
        }

        // Schlick-style Fresnel: stronger reflection at grazing angles.
        float cosTheta = max(dot(-viewDir, normal), 0.0);
        float fresnel  = pow(1.0 - cosTheta, 5.0);
        float reflStrength = mix(reflectivity * 0.4, reflectivity, fresnel);

        finalColor = mix(shadedColor, reflColor, reflStrength * hit);
    }

    gl_FragColor = vec4(finalColor, color.a);
}
