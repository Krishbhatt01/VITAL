# SciComp: OpenMDAO coupled-loop test bench

A self-contained test, separate from the VITAL MATLAB framework. Nothing here is used by VITAL's tests or gates.

| File | What it is |
|---|---|
| `trim_mda.py` | the model and the study: five coupled components with one feedback loop, converged with Nonlinear Block Gauss–Seidel (with and without Aitken acceleration), Newton + DirectSolver, and Broyden; two extra comparison runs (Newton on the implicit form, Broyden in full-model mode) |
| `N2_trim_nlbgs.html`, `N2_trim_nlbgs_aitken.html`, `N2_trim_newton.html`, `N2_trim_broyden.html` | **the N2 diagrams** (open in a browser), one per solver. Gauss–Seidel (both), and Newton use the explicit form; Broyden uses the implicit form, where component 5 (`liftbal`) holds alpha as a state with a lift-balance residual. The connections and the cycle are the same in all three |
| `results/convergence_report.md` | final values, tolerances, iterations, function calls, residual histories, the N2 checks, and the comparison |
| `results/residual_history.png` | residual vs iteration for the four solvers |
| `results/results.json`, `results/cases_*.sql` | the raw numbers and the OpenMDAO recorder files |
| `nz_loop_mda.py` | **second study: VITAL's nz controller loop** (ADR-026). Three components (aero, nzsens, ctrl) in one cycle: the controller sets the elevator from the load factor, which depends on the elevator. Same four solvers and settings, plus a loop-gain sweep and a NonlinearRunOnce run |
| `N2_nz_nlbgs.html`, `N2_nz_nlbgs_aitken.html`, `N2_nz_newton.html`, `N2_nz_broyden.html` | the N2 diagrams of the nz loop (Broyden on the implicit controller, where `ctrlbal` holds de as a state) |
| `results/nz_convergence_report.md`, `results/nz_residual_history.png`, `results/nz_gain_sweep.png`, `results/nz_results.json` | the nz-loop report, residual history at VITAL's gain, and iterations vs loop gain |
| `fit_nz_loop.m`, `nz_loop_data.json` | the MATLAB script that takes the nz-loop numbers from VITAL (CZ0, CZde, qbar S/W, nz0) and VITAL's own answers (closed-loop gain Kref from `vital.linear.linearize`, and the full-plant solve of a +1 deg command step) |
| `OPENMDAO_REVIEW.md` | what OpenMDAO is, its building blocks, solvers and use cases |
| `fit_f16_coefficients.m`, `f16_coefficients.json` | the MATLAB script that derives the 8 coefficients and the flight condition from VITAL's F-16, and its output (with VITAL's trim for comparison) |

**Run:** `python trim_mda.py` and `python nz_loop_mda.py`. It needs OpenMDAO 3.45.1, which is installed in the global Python 3.10. Exit code 0 means every check passed.

**The model:** longitudinal trim of the F-16 in steady level flight at 565.6854 ft/s, 10,013 ft, CG 25 % MAC. The 8 aerodynamic coefficients are NASA's F-16 table slopes at VITAL's trim point, made by `fit_f16_coefficients.m` (run once in MATLAB) and stored in `f16_coefficients.json`. At this one condition the result matches VITAL's own F-16 trim (alpha 2.6542 deg, elevator -3.2412 deg, thrust 2366.2 lbf) to about 1e-10 deg; away from it the straight-line coefficients drift from the full F-16 model.

```
alpha --> [1 pitch: de] --> [2 aero: CD] --> [3 dragbal: T] --> [4 liftreq: CL_req] --> [5 alphacl: alpha] --+
  ^                                                                                                       |
  +----------------------------- feedback: alpha into 1, 2, 3, 4 ------------------------------------------+
```

**Why Broyden uses the implicit form:** OpenMDAO's Broyden iterates on implicit *states*. Pointed at an explicit output, it fights the component that recomputes that output on every pass; the comparison run in the report shows this.

**How to read the N2:** components sit on the diagonal. Cells above the diagonal are feed-forward connections; cells below it are the feedback of alpha from component 5 (`alphacl`, or `liftbal` in the Broyden file) to the first four components. Those are the arrows that close the coupling cycle. The solver box beside the `trim` group shows which nonlinear solver converges the cycle: NLBGS (with or without Aitken; Aitken is a solver option, so both show NLBGS), Newton or Broyden, one per file. The viewer opens on the linear solver; a left-toolbar toggle switches it to the nonlinear one.


**The nz loop:** at VITAL's test gain (Knz = 0.05 rad/g, loop gain L = 0.0895) a +1 deg elevator command becomes 1.0982496 deg applied, matching VITAL's Kref and its full-plant solve to about 3e-12. Gauss-Seidel took 10 sweeps, Aitken 4, Newton 1, Broyden 1. The sweep shows Gauss-Seidel failing for |L| >= 1 (and too slowly near 1), Aitken rescuing negative L but not L >= 0.9, and Newton/Broyden converging in one step at every gain.

```
de_ref --> [3 ctrl: de = de_ref + Knz (nz - nz0)] --de--> [1 aero: CZ] --CZ--> [2 nzsens: nz] --+
                ^                                                                             |
                +------------------------------- nz ------------------------------------------+
```
