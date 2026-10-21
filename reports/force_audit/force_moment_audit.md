# Force and moment audit (VITAL 0.8.1-OOP)

**46 of 46 checks pass.** Trim: 565.6854 ft/s, 10013 ft, CG 25 % MAC; alpha 2.6542 deg, theta 2.6542 deg.

Axes: body x forward, y right, z down. L roll (+ right wing down), M pitch (+ nose up), N yaw (+ nose right). SI units (N, N m, rad/s^2).

## 1. The four forces in four frames (N)

Columns: aero (lift+drag+side), thrust, weight.

**body**

| | aero | thrust | weight | sum |
|---|---|---|---|---|
| x | -6302.4 | 10525.2 | -4222.8 | 9.09e-13 |
| y | 0.0 | 0.0 | 0.0 | 0 |
| z | -91090.6 | 0.0 | 91090.6 | 2.91e-11 |

**wind**

| | aero | thrust | weight | sum |
|---|---|---|---|---|
| x | -10513.9 | 10513.9 | 0.0 | 1.82e-12 |
| y | 0.0 | 0.0 | 0.0 | 0 |
| z | -90701.0 | -487.4 | 91188.4 | 2.91e-11 |

**stability**

| | aero | thrust | weight | sum |
|---|---|---|---|---|
| x | -10513.9 | 10513.9 | 0.0 | 1.82e-12 |
| y | 0.0 | 0.0 | 0.0 | 0 |
| z | -90701.0 | -487.4 | 91188.4 | 2.91e-11 |

**ned**

| | aero | thrust | weight | sum |
|---|---|---|---|---|
| x | -10513.9 | 10513.9 | 0.0 | 1.82e-12 |
| y | 0.0 | 0.0 | 0.0 | 0 |
| z | -90701.0 | -487.4 | 91188.4 | 2.91e-11 |

Wind axes give: **lift 90701.0 N, drag 10513.9 N, side 0 N, thrust 10525.2 N, weight 91188.4 N** (L/D 8.63).

DCMs used (body->wind C_wb, NED->body C_bn):

```
C_wb =
  0.998927   0.000000   0.046308
 -0.000000   1.000000  -0.000000
 -0.046308   0.000000   0.998927

C_bn =
  0.998927   0.000000  -0.046308
  0.000000   1.000000   0.000000
  0.046308   0.000000   0.998927
```

## 2. Effect of one input (state held), change from trim

| case | dFx | dFy | dFz | dL | dM | dN | dp_dot | dq_dot | dr_dot | expected |
|---|---|---|---|---|---|---|---|---|---|---|
| elevator TE up (de = -5 deg) | -2800.5 | 0.0 | 14237.9 | 0.0 | 67111.0 | 0.0 | 0.0000 | 0.8868 | 0.0000 | nose-up pitch (Cm_de < 0, de < 0) |
| elevator TE down (de = +5 deg) | 739.4 | 0.0 | -14237.9 | 0.0 | -67459.5 | 0.0 | 0.0000 | -0.8915 | 0.0000 | nose-down pitch |
| aileron, roll right (da = -5 deg) | 0.0 | -1967.1 | 0.0 | 44137.4 | 0.0 | 8789.3 | 3.4444 | 0.0000 | 0.1563 | right wing down (Cl_da < 0, da < 0) |
| aileron, roll left (da = +5 deg) | 0.0 | 1967.1 | 0.0 | -44137.4 | 0.0 | -8789.3 | -3.4444 | 0.0000 | -0.1563 | left wing down |
| rudder, yaw right (dr = -5 deg) | 0.0 | -5370.5 | 0.0 | -8262.1 | 0.0 | 27548.7 | -0.6094 | 0.0000 | 0.3125 | nose right (Cn_dr < 0, dr < 0) |
| rudder, yaw left (dr = +5 deg) | 0.0 | 5370.5 | 0.0 | 8262.1 | 0.0 | -27548.7 | 0.6094 | 0.0000 | -0.3125 | nose left |
| roll rate p = +0.10 rad/s | 0.0 | -29.6 | 0.0 | -3913.7 | 0.0 | 174.0 | -0.3043 | -0.0002 | -0.0027 | roll damping opposes p (Cl_p < 0) |
| pitch rate q = +0.05 rad/s | 160.4 | 0.0 | -5665.9 | 0.0 | -5347.7 | 0.0 | 0.0000 | -0.0707 | 0.0000 | pitch damping opposes q (Cm_q < 0) |
| yaw rate r = +0.05 rad/s | 0.0 | 456.8 | 0.0 | 406.7 | 0.0 | -1893.9 | 0.0293 | 0.0000 | -0.0217 | yaw damping opposes r (Cn_r < 0) |
| throttle to idle (real F-16) | -12456.4 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0000 | 0.0000 | 0.0000 | centreline thrust: no roll/yaw moment expected |

## 3. Engine cases

Real F-16 (one centreline engine), thrust removed: dF = [-10525.2 0.0 0.0] N, dM = [0 0 0] N m: thrust loss only, no roll or yaw moment.

**HYPOTHETICAL twin** (same total thrust, engines at y = +/-1.50 m; the F-16 has no such engines; illustrative only). Right engine out:

- dF = [-5262.6 0.0 0.0] N, dM = [0.0 0.0 7893.9] N m, angular accel change [0.0096 0.0000 0.0924] rad/s^2
- dN > 0: the nose yaws **right** (clockwise seen from above), toward the dead engine: the live left engine pushes its side forward.
- Rudder to hold heading (framework rudder power): **1.43 deg** (limit +/-30 deg).

## 4. Every check

| id | check | actual | expected | tol | result |
|---|---|---|---|---|---|
| F1 | C_bn: framework quaternion vs toolbox angle2dcm (max abs diff) | 0 | 0 | 1e-12 | PASS |
| F2 | C_wb: hand formula vs toolbox dcmbody2wind (max abs diff) | 0 | 0 | 1e-14 | PASS |
| F3 | DCM orthonormal: max |C C' - I| | 0 | 0 | 1e-12 | PASS |
| F3 | DCM det = +1 (right-handed) | 1 | 1 | 1e-12 | PASS |
| F3 | DCM orthonormal: max |C C' - I| | 0 | 0 | 1e-12 | PASS |
| F3 | DCM det = +1 (right-handed) | 1 | 1 | 1e-12 | PASS |
| F3 | DCM orthonormal: max |C C' - I| | 0 | 0 | 1e-12 | PASS |
| F3 | DCM det = +1 (right-handed) | 1 | 1 | 1e-12 | PASS |
| F4 | weight in body = [-W sin(theta); W sin(phi)cos(theta); W cos(phi)cos(theta)] (analytic) | 0 | 0 | 9.12e-05 | PASS |
| F5 | |aero force| same in body and wind axes | 0 | 0 | 9.13e-05 | PASS |
| F6 | lift positive (aero force points up off the flight path) | 1 | 1 | 0 | PASS |
| F6 | drag positive (aero force opposes the airflow) | 1 | 1 | 0 | PASS |
| F7 | thrust along +x body only (F_prop y, z = 0) | 0 | 0 | 0 | PASS |
| F8 | equilibrium along flight path: T cos(a) - D - W sin(g) (N) | 1.81899e-12 | 0 | 0.0912 | PASS |
| F8 | equilibrium normal to path: L + T sin(a) - W cos(g) (N) | -2.91038e-11 | 0 | 0.0912 | PASS |
| F9 | plant total force at trim |F_b| (N) | 2.9118e-11 | 0 | 0.0912 | PASS |
| F10 | M_cg recomputed by hand from MRC moments vs plant (N m) | 0 | 0 | 9.12e-05 | PASS |
| F11 | plant moment about CG at trim |M_cg| (N m) | 1.81899e-11 | 0 | 0.315 | PASS |
| F12 | weight in NED = [0 0 +W] (points down) | 0 | 0 | 9.12e-05 | PASS |
| F12 | NED: aero + thrust balance weight (sum of NED z) (N) | 2.91038e-11 | 0 | 0.0912 | PASS |
| E1 | elevator TE up (de = -5 deg): sign of dM | 1 | 1 | 0 | PASS |
| E1 | elevator TE up (de = -5 deg): sign of angular accel dqdot | 1 | 1 | 0 | PASS |
| E2 | elevator TE down (de = +5 deg): sign of dM | -1 | -1 | 0 | PASS |
| E2 | elevator TE down (de = +5 deg): sign of angular accel dqdot | -1 | -1 | 0 | PASS |
| E3 | aileron, roll right (da = -5 deg): sign of dL | 1 | 1 | 0 | PASS |
| E3 | aileron, roll right (da = -5 deg): sign of angular accel dpdot | 1 | 1 | 0 | PASS |
| E4 | aileron, roll left (da = +5 deg): sign of dL | -1 | -1 | 0 | PASS |
| E4 | aileron, roll left (da = +5 deg): sign of angular accel dpdot | -1 | -1 | 0 | PASS |
| E5 | rudder, yaw right (dr = -5 deg): sign of dN | 1 | 1 | 0 | PASS |
| E5 | rudder, yaw right (dr = -5 deg): sign of angular accel drdot | 1 | 1 | 0 | PASS |
| E6 | rudder, yaw left (dr = +5 deg): sign of dN | -1 | -1 | 0 | PASS |
| E6 | rudder, yaw left (dr = +5 deg): sign of angular accel drdot | -1 | -1 | 0 | PASS |
| E7 | roll rate p = +0.10 rad/s: sign of dL | -1 | -1 | 0 | PASS |
| E7 | roll rate p = +0.10 rad/s: sign of angular accel dpdot | -1 | -1 | 0 | PASS |
| E8 | pitch rate q = +0.05 rad/s: sign of dM | -1 | -1 | 0 | PASS |
| E8 | pitch rate q = +0.05 rad/s: sign of angular accel dqdot | -1 | -1 | 0 | PASS |
| E9 | yaw rate r = +0.05 rad/s: sign of dN | -1 | -1 | 0 | PASS |
| E9 | yaw rate r = +0.05 rad/s: sign of angular accel drdot | -1 | -1 | 0 | PASS |
| E10 | idle: |dL|, |dN| (N m) zero for a centreline engine | 0 | 0 | 9.12e-05 | PASS |
| E10 | idle: thrust decreases (dFx < 0) | 1 | 1 | 0 | PASS |
| T1 | twin, both engines = single centreline engine: |dM_cg| (N m) | 0 | 0 | 9.12e-05 | PASS |
| T2 | right engine out: dN = +d T/2 (analytic, N m) | 7893.92 | 7893.92 | 1.05e-05 | PASS |
| T2 | right engine out: nose yaws RIGHT (clockwise from above), sign dN | 1 | 1 | 0 | PASS |
| T2 | right engine out: dFx = -T/2 (N) | -5262.61 | -5262.61 | 1.05e-05 | PASS |
| T2 | right engine out: no roll moment (engines on the y axis of the MRC) | 0 | 0 | 9.12e-05 | PASS |
| T3 | left engine out: mirror image, dN(left out) = -dN(right out) | 0 | 0 | 1.05e-05 | PASS |
