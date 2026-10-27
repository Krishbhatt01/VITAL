# FRAMEWORK_GUIDE fragment (agent core, 2026-10-27): chapter draft

## 12c. The object core: axes, vectors, loads and mass properties

**Why.** To fly, the simulator needs one thing from the aircraft at every instant: the total force and moment about the body-fixed reference point (the BFRP). Before 0.9.1, each load was two bare 3-vectors, and which point the moment was about, and which axes the numbers were in, lived only in comments. That is where frame bugs hide. The object core makes the point and the axes part of the data, so the code refuses to add things that do not belong together.

**Three kinds of 3-vector.**

| Object | What it is | Changing axis... |
|---|---|---|
| `vital.Point` | a position | rotates **and** translates |
| `vital.Vector` | a free vector: force, moment, velocity, rate | only rotates |
| `vital.Loads` | a force and a moment **about a point** | rotates, and the moment picks up r × F |

A thrust `Vector` says how big and which way. *Where* it acts is the origin of the axis its `Loads` is about.

**Axes.** `vital.Axis(translation, orientation, parent, 'Name', ...)` places an axis relative to another. The orientation is a DCM, 3-2-1 Euler angles, a `quaternion` or an `so3`, always with VITAL's one convention: `C` maps the parent's components to this axis' components (CONVENTIONS 3). The aircraft's own axes (BFRP, MRC, CG, engines) form a fixed tree; the wind, stability and body-in-NED axes depend on the state and are built per evaluation (`Axis.wind`, `Axis.stability`, `Axis.bodyInNed`). The station frame (x aft, z up) is just another axis, body rotated 180° about y: `Axis.station(...)`.

**Mass.** `vital.MassProperties(m, axis_cg, inertia)` keeps the inertia tensor with its CG, so the parallel-axis theorem can only be applied from the CG (`mp.about(axis)`). `MassProperties.combine` builds an aircraft from parts. The only load that comes from mass is the weight, `mp.weightLoads(C_bn, g)`. The d'Alembert terms are never added: the equations of motion already have them.

**Components and the model.** A component (aero database, engine, later propeller, gear) gives its loads in its own axis and reads its own controls by name. `vital.AircraftModel` holds the axes, the components and the mass properties, and checks them (unique names, everything in one tree, no unknown control). A failed engine is a component with `enabled = false`.

**Example** (the whiteboard, in VITAL):
```matlab
f16 = vital.aircraft.f16.model();                  % the NESC F-16 as an AircraftModel
axis_bfrp = f16.axis('bfrp');  axis_cg = f16.axis('cg');
Ls = f16.componentLoads(x, u, env);                % one Loads per component, own axis
loads_aero = Ls{1};  loads_engine = Ls{2};
loads_weight = f16.MassProps.weightLoads(C_bn, env.g);
loads_total = vital.Loads.aggregate({loads_aero, loads_engine, loads_weight}, axis_bfrp);
loads_total.transform(axis_cg)                     % about the CG: zero at a trim

% a left engine 1.5 m to the left of the MRC
axis_le = vital.Axis([0 -1.5 0], eye(3), f16.axis('mrc'), 'Name', 'axis_le');
force_thrust_le = vital.Vector([T/2 0 0], axis_le, 'Quantity', "force");
loads_le = vital.Loads(force_thrust_le, vital.Vector([0 0 0], axis_le, 'Quantity', "moment"));
loads_le.transform(axis_cg)                        % yaw moment +1.5 T/2 about the CG
```
`run_core_example` does all of this at the README trim and runs the hypothetical twin with its right engine out.

**Fast and exact.** Building objects costs microseconds, and the plant runs up to a million times in an uncertainty study. So `model.compile()` turns the fixed axis tree into plain numbers once, and `model.derivatives(x, u, env)` uses them, with the same functions in the same order as `vital.plant.derivatives`. The object path (`loadsTotal`, `derivativesObject`) stays the definition; a test proves the two equal. For the F-16 the model and the existing plant agree **exactly** (difference 0) on 1,100 random states, including every AeroScale multiplier and states outside the NASA data, and the README trim is unchanged. The compiled model costs about 1.1-1.2 times the old plant per call.

**Using it with the existing tools.** Trim, linearization, simulation, flying qualities and uncertainty still take the AC struct. `model.toRuntime()` produces one that evaluates the model, so `vital.trim.solve(f16.toRuntime(), env, cond)` already works. Moving those tools to take an `AircraftModel` directly is the next increment.

**How we know it is right.** 36 tests in `tests/M9/core`, written before the classes: the toolbox (se3, transformTree, angle2dcm, dcmbody2wind) as independent checks, power invariance of every load transfer, the M1 1,000-box inertia, the NASA F-16 mass data, the force audit's equilibrium and sign checks, and the twin's engine-out moment. Eight sabotages (passive/active swap, a point losing its translation, a vector gaining one, the r × F sign, the parallel axis about the wrong point, d'Alembert loads in the total, a wrong control channel, a stale compiled chain) are each caught.
