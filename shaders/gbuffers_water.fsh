#version 120

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform mat4 gbufferModelView;
uniform float frameTimeCounter;     // seconds since shader load — drives the animation

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 color;
varying vec3 viewNormal;
varying vec3 worldPos;
varying float reflectivity;
varying float isWater;

// One sine wave evaluated at world-XZ position `p`:
//   amplitude * sin(k · (dir·p) + ω·t)
// where k = 2π / wavelength, ω = phase speed.
float wave(vec2 p, vec2 dir, float wavelength, float speed, float amp, float t) {
    float k = 6.2831853 / wavelength;
    return amp * sin(dot(p, dir) * k + speed * t);
}

// Sum a couple of waves traveling in different directions to break up the regularity.
float heightField(vec2 p, float t) {
    return wave(p, normalize(vec2( 1.0,  0.6)), 4.0, 1.5, 0.04, t)
         + wave(p, normalize(vec2(-0.7,  1.0)), 2.5, 2.1, 0.025, t);
}

/* DRAWBUFFERS:01 */
void main() {
    vec4 albedo = texture2D(gtexture, texcoord) * color;
    vec3 light  = texture2D(lightmap, lmcoord).rgb;

    vec3 outNormalView = viewNormal;

    if (isWater > 0.5) {
        // Build a normal from the heightfield's gradient using finite differences.
        // h(x,z) is a tiny vertical displacement; the surface normal is
        //   n = normalize( -∂h/∂x, 1, -∂h/∂z )
        // Approximated as ( h(x,z) - h(x+ε,z) ) / ε, etc.
        vec2 p = worldPos.xz;
        float t = frameTimeCounter;
        float eps = 0.05;

        float hC = heightField(p,                  t);
        float hX = heightField(p + vec2(eps, 0.0), t);
        float hZ = heightField(p + vec2(0.0, eps), t);

        vec3 worldNormal = normalize(vec3(-(hX - hC) / eps, 1.0, -(hZ - hC) / eps));

        // Rotate world-space normal into view space. gbufferModelView is rotation+translation;
        // for direction vectors (w = 0) the translation drops out, so this is just the rotation.
        outNormalView = normalize((gbufferModelView * vec4(worldNormal, 0.0)).xyz);
    }

    gl_FragData[0] = vec4(albedo.rgb * light, albedo.a);
    gl_FragData[1] = vec4(outNormalView * 0.5 + 0.5, reflectivity);
}
