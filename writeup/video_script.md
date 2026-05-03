# Final Showcase Video — Script & Shot List

**Target length:** 1m 30s (well under the 2-minute cap, leaves room to breathe).
**Constraint:** every team member must speak. Scenes below mark who talks where.

---

## Recording checklist

- [ ] Game running with our shader at a stable FPS.
- [ ] OBS / QuickTime screen recording at 1080p, 60 fps if possible.
- [ ] Audio: each speaker recorded close-mic; background music kept *very* low or absent.
- [ ] Iris shader menu pre-loaded so you can toggle on/off cleanly for the comparison.
- [ ] Pre-build a "demo world" with:
  - a forest stretch (for shadow shots),
  - a row of glass / ice / iron / gold / diamond blocks against a colorful backdrop,
  - a lake with shoreline, hills, or trees on the far side (so SSR has something to reflect).
- [ ] Day-time, sun at ~45° (best shadow length).

---

## Shot list (1m 30s total)

### 0:00 – 0:08 · Title card + hook *(8s, no narration)*
- Black background fades to a 2-second clip of water reflecting trees with ripples.
- Title overlay: **"Real-Time Shadows and Reflections in Minecraft"**.
- Subtitle: *CS184 Final Project — [Team Names]*.

### 0:08 – 0:18 · The hook *(10s — Member 1)*
> "We built a real-time Minecraft shader from scratch — sun shadows,
> reflections on shiny blocks, and animated water — all using techniques
> from CS184."

*Visual:* slow pan over the demo world with the shader on.

### 0:18 – 0:33 · Before/after comparison *(15s — Member 1 continues)*
> "Vanilla Minecraft is flat — no shadows, no reflections. We started
> from empty stub shaders and built every effect ourselves."

*Visual:* split screen or quick wipe — vanilla left, our shader right —
with the same camera position. Hold for 5 seconds so the difference reads.

### 0:33 – 0:53 · Shadows + reflections demo *(20s — Member 2)*
> "Sun shadows are a shadow map reprojected through the depth buffer.
>
> The reflections on these iron, gold, and diamond blocks come from
> screen-space ray marching — we tag blocks as shiny in a properties file,
> then march the reflection direction in view space and sample what we hit."

*Visual:* camera walks past a forest (shadow shot), then pans to the row of
shiny blocks. Optionally toggle SSR on/off mid-clip for emphasis.

### 0:53 – 1:13 · Animated water *(20s — Member 3)*
> "For water we needed normals that change over time. We treat the surface
> as a height field — a sum of sine waves over world coordinates and time —
> and compute the normal from its gradient using finite differences.
>
> That's what makes the reflected scene shimmer."

*Visual:* close-up shot of water with the shoreline reflected, zoomed
slightly. Camera holds while ripples animate. A subtle text overlay can
show the equation `n = (−∂h/∂x, 1, −∂h/∂z)` for ~3 seconds.

### 1:13 – 1:25 · Lessons + invitation *(12s — split: Member 1 + Member 2)*

*Member 1:*
> "Biggest lesson: the deferred-shading pattern is general — the same
> pipeline could host fog, bloom, ambient occlusion."

*Member 2:*
> "If you like graphics and you play Minecraft — try writing a shader.
> You learn an entire rendering pipeline by hand."

*Visual:* rapid-cut highlight reel of the best clips.

### 1:25 – 1:30 · Outro card *(5s)*
- "Thanks for watching."
- Team names.
- Source link: github.com/vejhawar0/cs184-project.

---

## Captions / on-screen text

Add subtle captions under technical claims so a viewer with sound off can still follow:

| Time | Caption |
|---|---|
| 0:33 | "Shadow map reprojected from sun's view" |
| 0:43 | "32-step screen-space ray march per pixel" |
| 0:53 | "Wave height field — sum of sines in world space" |
| 1:03 | "Normal = gradient of height field (finite differences)" |

---

## Hosting

- Upload to YouTube as **Unlisted** (not Private — TAs need the link to view without login).
- *Or* upload to Google Drive and set sharing to **"Anyone at Berkeley with the link"**.
- Paste the link into both `index.html` and the final PDF submission.
