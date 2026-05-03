# Real-Time Shadows and Reflections in Minecraft

*A custom Iris/Optifine shader pack implementing deferred shadow mapping, screen-space reflections, and animated water.*

**CS184 Final Project, Spring 2026** — [Team Member 1], [Team Member 2], [Team Member 3]

[[Source Code]](https://github.com/vejhawar0/cs184-project) · [[Showcase Video]](#showcase-video) · [[Slides]](slides.pdf)

---

## Abstract

We built a custom Minecraft shader pack from scratch using the Iris/Optifine shader API, taking a vanilla, fully-lit-but-flat scene and turning it into one with directional sun shadows, screen-space reflections on shiny materials (glass, ice, iron, gold, diamond), and animated water whose ripples deform the reflected world. Our goal was to take the core real-time graphics ideas from CS184 — deferred rendering, shadow mapping, screen-space techniques, and the relationship between height fields and surface normals — and put them to work in a system we and our friends actually use every day. Starting from a minimal shader template that did nothing but pass colors through, we implemented every shading effect ourselves and the result runs live in-game at interactive frame rates on consumer hardware.

## Technical Approach

### Pipeline overview and starting point

Our starter code was a near-empty Iris shader pack — the gbuffer fragment shaders simply output `albedo * lightmap`, the shadow stage wrote a constant white, and the composite pass did nothing more than blit the framebuffer. Iris/Optifine itself imposes the high-level pipeline structure, which is essentially deferred rendering:

```
gbuffers_terrain / gbuffers_water  →  colortex0..N (G-buffer)
                                  →  composite (full-screen lighting)
                                  →  final (output)
shadow.vsh / shadow.fsh            →  shadowtex (depth from sun)
```

Every shading effect we wanted needed two things the starter pipeline didn't produce: per-pixel *geometric* information (depth, normal, material reflectivity) packed into the G-buffer, and a screen-space pass in `composite` that consumes that information.

### 1 · Directional sun shadows

Shadow mapping required two pieces. First, the `shadow.vsh / shadow.fsh` stage renders the scene from the sun's point of view, using an orthographic projection (`shadowProjection * shadowModelView`), and stores only depth in `shadowtex0`. Second, in `composite.fsh` we reconstruct each visible pixel's world position from the depth buffer:

```glsl
vec4 ndcPos    = vec4(uv * 2 - 1, depth * 2 - 1, 1);
vec4 viewPos   = gbufferProjectionInverse * ndcPos;
viewPos       /= viewPos.w;
vec4 worldPos  = gbufferModelViewInverse * viewPos;
```

We then re-project that world position into the sun's clip space, sample `shadowtex0` at the resulting UV, and compare depths. A pixel whose recorded depth from the sun is shallower than the depth in the shadow map is occluded: `inShadow = (shadowUV.z − bias > shadowDepth)`. We darken occluded pixels by 60%. A small constant bias of `0.005` avoids shadow acne from depth quantization on flat surfaces.

### 2 · Material tagging via `block.properties`

To make blocks like glass and iron behave differently, the shader needs to know what kind of block each fragment came from. Vanilla Minecraft's geometry stream doesn't carry that information, so we used Iris's `block.properties` mechanism, which lets us declare integer IDs for sets of block names:

```
block.100 = minecraft:glass minecraft:ice minecraft:packed_ice ...
block.101 = minecraft:iron_block minecraft:gold_block minecraft:diamond_block ...
block.102 = minecraft:water minecraft:flowing_water
```

Iris then exposes those IDs to the vertex shader as a per-vertex attribute, `mc_Entity.x`. We use that attribute to assign a per-material reflectivity value at the gbuffer stage, packed into `colortex1.a`.

### 3 · Augmented G-buffer

Both `gbuffers_terrain` and `gbuffers_water` were extended to write a second target via `/* DRAWBUFFERS:01 */`. `colortex0` still holds lit color; `colortex1` now packs the view-space normal and reflectivity:

```glsl
gl_FragData[1] = vec4(viewNormal * 0.5 + 0.5, reflectivity);
```

The view-space normal is computed in the vertex shader as `normalize(gl_NormalMatrix * gl_Normal)`. `gl_NormalMatrix` is the inverse-transpose of the upper-3×3 of the modelview matrix — the correct transform for direction vectors under arbitrary linear deformations. The `* 0.5 + 0.5` remap converts the signed normal into the `[0,1]` range required by the unsigned RGBA8 backing texture; the inverse remap is applied on read.

### 4 · Screen-Space Reflections (SSR)

In `composite.fsh`, after computing the shadowed scene color, we read the packed normal and reflectivity from `colortex1`. For pixels with non-trivial reflectivity we run a screen-space ray march:

1. Compute the reflection direction in view space: `reflectDir = reflect(viewDir, normal)`, which expands to *R = V − 2(V·N)N*.
2. March 32 steps of 0.3 view-space units, starting just off the surface (offset along the normal to avoid self-intersection).
3. At each step, project the ray's view-space position back to a screen UV using `gbufferProjection`, sample `depthtex0` at that UV, convert the sampled depth back to view space, and compare z-values. A "hit" is when the ray has just passed behind the visible surface.
4. On hit, sample `colortex0` at the UV — that's the reflected color.

We then modulate the reflection by a **Schlick-style Fresnel** term, *F = (1 − cos θ)⁵*, which captures the well-known fact that smooth dielectric surfaces become more reflective at grazing angles. The final composite is `mix(shadedColor, reflectedColor, reflectivity * fresnel * hit)`.

SSR's well-known limitation is that it can only reflect what is already on screen. Reflections of off-camera geometry vanish, and we accept this: a sky/cubemap fallback would be the natural extension.

### 5 · Animated water with wave normals

Water with a flat normal reflects only what is directly overhead and reads as static glass. To get the characteristic shimmer of real water we needed time-varying normals. We treat the water surface as a height field *y = h(x, z, t)* defined in world coordinates, then derive the surface normal from its gradient.

The height field is a small sum of two traveling sine waves with different directions, wavelengths, and phase speeds:

```
h(x, z, t) = A₁ · sin(k₁(d₁·p) + ω₁·t)
           + A₂ · sin(k₂(d₂·p) + ω₂·t)
```

At each fragment we compute `h(p)`, `h(p + (ε, 0))` and `h(p + (0, ε))`, then take forward finite differences to estimate *∂h/∂x* and *∂h/∂z*. The unit normal of the height field is *n = normalize(−∂h/∂x, 1, −∂h/∂z)* (this comes from the cross product of the two natural surface tangents). We chose *ε = 0.05* as a balance between smoothing and floating-point noise.

Two implementation details mattered. First, the wave field has to be evaluated in *world* space, not view or screen space, otherwise the ripples slide across the surface as the camera moves. Iris stores camera-relative positions for floating-point precision, so we recover absolute world position as `(gbufferModelViewInverse * viewVertex).xyz + cameraPosition`. Second, Iris routes *all* translucent geometry — including stained glass — through `gbuffers_water`, so we gate the wave perturbation on `mc_Entity.x == 102` (the block ID we assigned to water) to avoid making stained glass jiggle.

### Problems encountered

- **Distinguishing materials** in vanilla Minecraft was the first wall: gbuffer attributes don't say "this is glass." We learned that Iris exposes `block.properties` + `mc_Entity` precisely for this case.
- **View-space z sign convention.** OpenGL view space looks down −Z, so "the ray went behind the geometry" means `rayPos.z < sceneViewPos.z`, not the reverse. We had backwards-facing reflections until we worked this out on paper.
- **Self-intersection** in the ray march produced a noisy mottled surface. Offsetting the ray's start point by `normal * 0.05` instead of stepping straight from the surface fixed it.
- **Stained glass riding the water shader.** The first water-wave version made stained glass blocks ripple, which was both wrong and funny. The `mc_Entity` gate solved it cleanly.
- **Wave anchoring.** Initial wave evaluation in camera-relative coordinates made waves "scroll" with the player. Adding `cameraPosition` anchored them to the world.

### Lessons learned

- The **deferred shading pattern** — geometry pass writes materials, screen-space pass consumes them — is enormously general. The same scaffolding can host SSAO, bloom, volumetric lighting, etc.
- **Screen-space techniques are pragmatic but lossy.** SSR is fast and visually convincing inside-frustum but degrades gracefully (sometimes ungracefully) at the edges. Knowing those edges is part of the art.
- **Heightfield → normal via gradient** is one of those tricks that shows up everywhere — terrain, water, normal mapping — and we now genuinely understand it rather than copy-pasting it.
- **Coordinate systems demand discipline.** Most of our debugging was not algorithmic, it was tracking what frame a vector was in.

## Results

> **To do before submission:** Drop your screenshots and animated GIF into `writeup/images/` and uncomment the image lines below. Suggested captures:
>
> 1. Before/after side-by-side: vanilla Minecraft vs. our shader.
> 2. Sun shadows under a tree canopy.
> 3. A row of glass / ice / iron / gold / diamond blocks in front of a colorful background to show off SSR.
> 4. An animated GIF of water reflecting a shoreline, with the wave ripples in motion.

<!-- ![Vanilla vs. our shader pack](images/comparison.png) -->

*Figure 1. Vanilla Minecraft (left) vs. our shader pack (right). Note the cast shadows under foliage and the reflections on the iron block.*

<!-- ![Sun shadows under a tree canopy](images/shadows.png) -->

*Figure 2. Directional sun shadows reconstructed by reprojecting the depth buffer into the sun's orthographic clip space.*

<!-- ![SSR on glass, ice, iron, diamond, gold blocks](images/ssr-blocks.png) -->

*Figure 3. Five reflective materials — glass, ice, iron, gold, diamond — each reflecting the surrounding scene via screen-space ray marching. Reflection strength is modulated by a Schlick Fresnel term.*

<!-- ![Animated water with wave-perturbed reflections](images/water.gif) -->

*Figure 4. Water surface with procedural wave normals derived from the gradient of a sum-of-sines height field. The reflected world ripples in real time.*

## Showcase Video

[Watch the 1–2 minute showcase video]([INSERT YOUTUBE OR GOOGLE DRIVE LINK]).

## References

- Iris Shaders documentation, [shaders.properties](https://shaders.properties/current/) reference and Optifine shader pack format.
- Williams, L. (1978). *Casting curved shadows on curved surfaces.* SIGGRAPH — the original shadow-map paper.
- Schlick, C. (1994). *An Inexpensive BRDF Model for Physically-based Rendering.* Source of the Schlick Fresnel approximation used for reflectivity falloff.
- de Vries, J. *LearnOpenGL — Screen Space Reflection.* [learnopengl.com](https://learnopengl.com/).
- Tessendorf, J. (2001). *Simulating Ocean Water.* Background reading on sum-of-sines and Gerstner wave models.
- Akenine-Möller, T., Haines, E., Hoffman, N. *Real-Time Rendering, 4th ed.* Reference for deferred shading and screen-space techniques.

## Contributions

> **Fill this in before submission** — TAs grade for clarity here.

| Team Member | Contributions |
|---|---|
| [Name 1] | [e.g. Set up the Iris/Optifine project scaffolding, implemented the shadow pass (shadow.vsh/fsh and the composite shadow code), wrote the project README, recorded the showcase video.] |
| [Name 2] | [e.g. Implemented the augmented G-buffer (colortex1 packing) and the SSR ray march in composite.fsh, including the Fresnel and self-intersection fixes. Designed block.properties.] |
| [Name 3] | [e.g. Designed and implemented the water height field, gradient-based normal perturbation, and the cameraPosition-anchored coordinate setup. Authored the writeup.] |
