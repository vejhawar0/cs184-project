# Presentation Notes — CS184 Final Project

Two presentations on showcase day. Below: speaker scripts with timing,
slide-by-slide breakdown, and what to have ready on the laptop.

> **Have queued up on the laptop, in this order:**
> 1. A vanilla-Minecraft world (no shader) — for the "before" reference shot.
> 2. The same world with our shader pack loaded, ready to walk to:
>    - a forest with sun shadows,
>    - a row of placed glass/ice/iron/gold/diamond blocks against a colorful background,
>    - water with shoreline visible.
> 3. Iris shader menu open in another tab so you can hit "Reload" if a TA asks
>    "what happens if you turn off shadows / SSR."

---

## A. The 1.5-Minute Pitch (Professor Ren)

**Goal:** background + best results. No deep technical detail.

### Slide 1 — Title (10 sec)
> "Hi Professor — we're [names]. We built a real-time Minecraft shader pack
> from scratch: shadows, reflections, and animated water. Everything you'll
> see is running live."

*(Have the game already running with the shader on, mid-scene.)*

### Slide 2 — The "before" shot (15 sec)
> "Vanilla Minecraft has no real shadows and no reflections — it's
> visually flat. We wanted to take what we learned in 184 — deferred
> rendering, shadow mapping, screen-space techniques — and apply it to a
> system millions of people already use."

### Slide 3 — Live demo: shadows + reflections (45 sec)
*Walk the camera through the scene as you talk. Hit each beat once.*

> "Here are sun shadows under the trees — that's a shadow map projected
> back through the depth buffer.
>
> These iron, gold, and diamond blocks are reflecting their surroundings
> with screen-space ray marching — we mark blocks as 'shiny' via a tag
> file, then march the reflection direction in view space.
>
> And here's the water — the ripples you see distorting those reflections
> come from animated wave normals derived from the gradient of a sum-of-sines
> height field, evaluated in true world space so they don't drift with the
> camera."

### Slide 4 — Wrap (10 sec)
> "Everything we showed is custom — we started from empty stub shaders.
> Thanks!"

---

## B. The 5-Minute TA Presentation

**Goal:** show off, explain what we built, distinguish starter from our work.

### Slide 1 — Title (15 sec)
- Title: *Real-Time Shadows and Reflections in Minecraft*
- Subtitle: one sentence — *"We took our own custom Minecraft shader from a
  flat passthrough into a deferred renderer with shadows, screen-space
  reflections, and animated water — running live in-game."*
- Team names + 184/284 designation.
- An iconic screenshot or short looping GIF of the water reflections.

### Slide 2 — Background & starting point (30 sec)
> "Iris and Optifine give you a fixed shader-pipeline scaffold — vertex
> and fragment shaders for each gbuffer stage, a composite stage, a final
> stage, a shadow pass — but the *contents* are yours.
>
> Our starting point was the bare minimum: gbuffer shaders that just
> output `albedo * lightmap`, a shadow pass that wrote a constant white,
> and a composite that did nothing. We wanted to see how far we could push
> visual fidelity using the techniques from CS184."

*Bullet on slide:* "Starter = stubs. Built: shadows + SSR + animated water."

### Slide 3 — Demo / final results teaser (45 sec)
*Live game window full-screen. Walk through scene.*

> "Before we explain how it works — here's what it does."
>
> 1. Pan to forest: *"Sun shadows under foliage."*
> 2. Pan to block row: *"Reflections on glass, ice, iron, gold, diamond."*
> 3. Pan to water: *"Animated water reflections — these ripples are the
>    SSR rays getting steered by procedural wave normals."*

### Slide 4 — The deferred pipeline (45 sec)
*Diagram on slide:*

```
gbuffers_terrain ┐
gbuffers_water   ├─►  colortex0 (lit color)
                 └─►  colortex1 (normal + reflectivity)   ◄── new!
                              │
                              ▼
                          composite  ──►  final
                              ▲
                shadow ─► shadowtex0
```

> "Everything is deferred. The geometry pass writes per-pixel *material*
> info into a fat framebuffer — color, depth, normal, reflectivity. The
> composite pass runs full-screen and does all the lighting from those
> textures. We extended the gbuffer with a second color attachment that
> packs view-space normals and per-pixel reflectivity."

### Slide 5 — Shadow mapping (45 sec)
*Visual: side-by-side shadow on/off plus a small diagram of sun-frustum projection.*

> "First effect: shadow mapping. We render depth from the sun in
> `shadow.vsh/fsh`, and in composite we reproject every visible pixel back
> into the sun's clip space and compare depths. Pixels whose depth from
> the sun exceeds what's stored in the shadow map are occluded, and we
> darken them by 60%."
>
> "We had to add a small bias — about 0.005 — to fight shadow acne on flat
> surfaces; that's quantization in the shadow map showing through."

### Slide 6 — Material tagging + SSR (75 sec)
*Slide: code snippet of `block.properties` + the reflect math.*

> "For reflections, we needed two things vanilla Minecraft doesn't give
> us. First, *which blocks are shiny.* We solved that with Iris's
> `block.properties` — a file mapping block names to integer IDs that
> show up in our vertex shader as the `mc_Entity` attribute. Glass and
> ice get one ID, metal and gem blocks another, water a third."
>
> "Second, the *reflection itself.* We use screen-space reflections.
> For every reflective pixel, we reflect the view direction about the
> normal and ray-march along that vector — 32 steps in view space.
> At each step we project back to screen UV, sample the depth buffer,
> and check whether our ray has just passed behind a visible surface.
> If yes, that's our reflection color."
>
> "We multiply by a Schlick Fresnel — `(1 − cos θ)⁵` — so reflections
> get stronger at grazing angles, which is what real dielectrics do."

*Optional toggle moment:* "Here's SSR off — and on. You can see how it
fills in only what's on-screen; that's the well-known SSR limitation."

### Slide 7 — Animated water (60 sec)
*Slide: equation for the height field, gradient → normal, world-space anchoring.*

> "Water with a flat normal reflects only what's straight overhead and
> looks like glass. To get water to *look* like water, we treated the
> surface as a height field — a sum of two traveling sine waves over
> world XZ plus time."
>
> "The trick to getting normals out of a height field is the gradient.
> The unit normal is `(−∂h/∂x, 1, −∂h/∂z)`, normalized. We approximate
> those partial derivatives with finite differences — sample at the
> point, sample at +ε in x and z, divide by ε. That's it."
>
> "Two subtleties. We have to evaluate the wave field in *world* space,
> not view space, or the waves slide as the player moves. And Iris routes
> all translucent geometry — including stained glass — through
> `gbuffers_water`, so we use `mc_Entity` again to gate waves on water
> only."

### Slide 8 — More results (45 sec)
*Looping GIF or short clip; talk over it.*

> "Some shots we like — sunset reflecting off a diamond block, the
> shoreline bending in the water, ice with subtle reflections of trees
> behind. Note the Fresnel falloff on the glass — head-on it's mostly
> transparent, at grazing angles it goes mirror-like."

### Slide 9 — Lessons + thanks (20 sec)
> "Three takeaways. The deferred-shading pattern is enormously general —
> the same pipeline could host SSAO, bloom, volumetrics. Screen-space
> techniques are great when you accept their limits. And most of our
> debugging was not algorithmic — it was keeping coordinate systems
> straight."
>
> "Thanks to [team members] for being amazing collaborators, and thanks
> to the staff."

---

## Anticipated Q&A

| Likely question | One-sentence answer |
|---|---|
| "What's the cost of SSR?" | 32-step ray march per reflective pixel — runs at game framerate on consumer GPUs because non-reflective pixels early-out. |
| "Why SSR over real reflections?" | Real reflections require re-rendering the scene; SSR uses information we already have in the depth and color buffers. The cost is that off-screen geometry can't reflect. |
| "How would you extend it?" | Sky/cubemap fallback for when SSR misses, soft shadows via PCF, parallax-corrected reflections, godrays. |
| "Why finite differences for the gradient?" | The waves are analytical sines so we *could* derive the gradient symbolically, but FD generalizes to any height field including textures, so it was worth the tiny extra cost. |
| "What's the precision of the normal in colortex1?" | RGBA8 — 8 bits per channel — which is enough for visibly clean reflections; RGBA16F would help at grazing angles. |
| "Could you do refraction too?" | Yes, with the same scaffolding — sample colortex0 at a UV offset by the perturbed normal. We didn't have time. |
