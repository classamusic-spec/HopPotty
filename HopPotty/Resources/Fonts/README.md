# Bundled typefaces

HopPotty ships **Fredoka** (display and child surfaces) and **Nunito** (parent
surfaces and dense data). Both are under the **SIL Open Font License 1.1**,
which permits bundling in an application, including commercially, provided the
licence travels with the font — `OFL-Fredoka.txt` and `OFL-Nunito.txt` are here
for exactly that reason and must ship with the app.

## These are generated, not downloaded

`Scripts/build-fonts.py` instances them from the variable fonts in
`Scripts/fonts/`, which are the same files the render harness embeds. That is
the point: the app and the design renders are now set in the same faces from
the same source, so a render is a picture of the app rather than an
approximation of it.

## Why static instances rather than the variable fonts

Both source files are variable, and **their weight axis defaults to the
lightest instance** — Fredoka `wght` 300–700 defaults to 300, Nunito 200–1000
defaults to 200. `Font.custom("Fredoka", size:)` resolves that default, so
bundling the variable file directly would render every heading Light. The
browser avoids this because CSS declares the axis range and picks the weight;
iOS has no equivalent for a plain `Font.custom`. Shipping one static face per
weight the type scale actually asks for removes the whole class of problem.

## Fredoka has no weight above 700

The type scale asks for `heavy` (800) on `hero` and `celebration`. Fredoka's
axis stops at 700, so those clamp to Bold — which is exactly what the render
harness gets, because its `@font-face` declares `font-weight: 300 700` and the
browser clamps identically. The app and the render land on the same instance.

Regenerate with `python3 Scripts/build-fonts.py`.
