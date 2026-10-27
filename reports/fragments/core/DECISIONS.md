# DECISIONS fragment (agent core, 2026-10-27): ADR-040

## ADR-040 (proposed; agent core, 2026-10-26/27): the object core: axes, vectors, loads, mass properties, components and AircraftModel

**Status:** proposed (docs/PLAN_CORE_FRAMES.md, from the user's whiteboard design). Version 0.9.1-CORE. Extends ADR-037 (objects outside, functional core inside) one level down: the aircraft itself becomes an object, while `vital.plant.derivatives`, `vital.loads.*`, `vital.frames.*` and `vital.mass.*` stay unchanged and are what the new classes are tested against.

**Context.** Every load in VITAL was a pair of numeric 3-vectors whose point and axes lived only in comments and variable names (CONVENTIONS 6). The F-16 was a struct with one `loadsFcn` that knew its own geometry. A second aircraft, a second engine or a station-frame import each needed hand-written frame code, the classic source of sign and point errors.

**Decision 1: three kinds of 3-vector, one rotation convention.**
- `vital.Axis`: origin in the parent (m) and `C` = C_this_parent (passive, CONVENTIONS 3). Orientation from a DCM (orthonormal, det +1), 3-2-1 Euler, a `quaternion` (VITAL meaning: `rotmat(q,'frame') = C`) or an `so3` (active: `C = rotm(R)'`); anything else is vital:badInput. Units "ft"/"deg" converted once. Factories: root, station (exact diag(-1,1,-1)), wind, stability, bodyInNed.
- `vital.Point` (changing axis rotates AND translates), `vital.Vector` (rotates only; quantity force/moment/velocity/rate/position/generic), `vital.Loads` (force + moment about the origin of its reference axis; transfer adds r x F). `plus` only within one axis / quantity / reference; `Loads.aggregate` transfers each load explicitly. Errors: vital:axis:mismatch, vital:vector:quantityMismatch, vital:loads:refMismatch, vital:axis:noCommonRoot.
- Toolbox conventions were probed before the tests (reports/work/core/probe_*.m) and are used as INDEP checks only (se3, transformTree, angle2dcm, dcmbody2wind, quaternion, so3), never in the hot path (ADR-037 decision 2 measurements).

**Decision 2: inertia lives with its CG.** `vital.InertiaTensor` (components in an axis, about the CG of its owner) and `vital.MassProperties(m, axis_cg, tensor)`: `about(b)` applies the parallel-axis theorem from the CG only; `combine` gives the composite CG and inertia (as `vital.mass.massProps`); `weightLoads` is the only load from mass properties. `dAlembertLoads` exists for static-balance checks and is never summed (CONVENTIONS 6; guard test and sabotage SC-6).

**Decision 3: components and the model.** `vital.Component` (abstract): `loads(flight)` in its own axis, reading its own named control channels; `enabled = false` is engine-out. `vital.AeroTableComponent` (coefficients about its axis origin) and `vital.PropulsorComponent` (thrust along +x, torque about +x). `vital.FlightContext`: state, controls by name, atmosphere and air data, computed once per evaluation with the plant's own functions. `vital.AircraftModel`: the axis tree rooted at the BFRP, components, mass properties, controls, limits; validates names, tree membership and channels.

**Decision 4: object path = definition; compiled path = speed; the existing plant = the reference.** `loadsTotal`/`derivativesObject` build Loads objects throughout. `compile()` reduces every component axis to a numeric (C, r) to the root, rebuilt on every call (never cached by name: sabotage SC-8), and `derivatives` then sums with `vital.loads.sumLoadsAtCG` and integrates with `vital.eom.rigidBodyDerivs`, the plant's own functions in the plant's order. Result: the F-16 model equals `vital.plant.derivatives` EXACTLY (max relative difference 0 over 1,100 seeded states, all 8 AeroScale multipliers, CG/BFRP-offset variants, 652 out-of-envelope points; gate 1e-12) and the README trim through `model.toRuntime()` is identical.

**Decision 5: one physics source for the F-16.** The F-16 aero component takes its coefficients from `vital.aircraft.f16.loads` (new optional `'aero'` part, default path unchanged), so the AeroScale build-up is not duplicated; the engine component calls the NASA engine model with the same conversion as `loads.m`.

**Consequences.**
- Performance (same process, interleaved, README trim state): compiled model / plant ~1.1-1.2 (target 1.25; numbers in the gate report); the object path is ~6-8 x (reference only).
- Today trim, linearize, sim, fq and uq still take the AC struct; `model.toRuntime()` produces it (4 controls). Migrating them to take an `AircraftModel` directly, component mass build-up (fuel, CG travel), landing gear and the X-57 are the next increments.
- Value classes: no hidden mutation; axis identity is by value (name + geometry).
- New error identifiers: vital:axis:noCommonRoot, vital:axis:mismatch, vital:vector:quantityMismatch, vital:loads:refMismatch, vital:model:duplicateAxis, vital:model:axisOutsideTree, vital:model:unknownControl, vital:model:duplicateComponent, vital:model:unknownAxis, vital:model:unknownComponent, vital:model:unsupported.
