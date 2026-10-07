# Coupled trim loop in OpenMDAO: Gauss-Seidel (with and without Aitken), Newton and Broyden

OpenMDAO 3.45.1. Flight condition: V = 565.6854 ft/s, rho = 0.0017553 slug/ft^3, qbar = 280.848 psf, W = 20500.0 lbf, S = 300.0 ft^2 (F-16-like scale; surrogate aerodynamics).

Independent check (scipy fsolve on the two balance equations): alpha = 3.7782530922 deg, de = -2.5188353948 deg, T = 1943.383957 lbf.

Two formulations of the same physics. **Explicit**: component 5 computes alpha = (CL_req - CL0 - CLde de)/CLa (used by Gauss-Seidel and Newton). **Implicit**: component 5 holds alpha as a state with residual R = CL0 + CLa alpha + CLde de - CL_req (used by Broyden, which needs a state; Newton is repeated on it for comparison). Same tolerances (atol 1e-10, rtol 1e-12) and the same initial guess alpha = 0 for every run.

## NonlinearBlockGS (no Aitken)

| quantity | value |
|---|---|
| alpha | 3.7782530922 deg |
| elevator de | -2.5188353948 deg |
| thrust T | 1943.383957 lbf |
| CL | 0.2417908403 |
| Cm (should be 0) | 3.469e-18 |
| tolerances | atol 1e-10, rtol 1e-12, maxiter 100 |
| iterations | 14 |
| compute() calls (all components; implicit residual evaluations included) | 70 |
| compute_partials() / linearize() calls | 0 |
| agreement with independent fsolve | alpha 8.9e-16 deg, de 5.8e-15 deg, T 3.0e-12 lbf |

Calls per component: aero 14+0, alphacl 14+0, liftreq 14+0, pitch 14+0, prop 14+0 (compute + partials)

Residual history (absolute norm of the solver's residual per iteration):

| iter | abs residual | rel residual |
|---|---|---|
| 0 | 5.064e+02 | 1.455e+00 |
| 1 | 8.207e+01 | 2.358e-01 |
| 2 | 6.360e+00 | 1.827e-02 |
| 3 | 4.725e-01 | 1.357e-03 |
| 4 | 3.499e-02 | 1.005e-04 |
| 5 | 2.591e-03 | 7.444e-06 |
| 6 | 1.918e-04 | 5.511e-07 |
| 7 | 1.420e-05 | 4.081e-08 |
| 8 | 1.052e-06 | 3.021e-09 |
| 9 | 7.787e-08 | 2.237e-10 |
| 10 | 5.765e-09 | 1.656e-11 |
| 11 | 4.266e-10 | 1.225e-12 |
| 12 | 3.160e-11 | 9.080e-14 |

Reading the counts: 14 Gauss-Seidel sweeps, each running all 5 components once (70 compute calls). With use_apply_nonlinear off, OpenMDAO measures the NLBGS residual as the change in outputs between consecutive sweeps, so the first sweep has no residual and the table has one row fewer.

N2 diagram: `N2_trim_nlbgs.html`. Programmatic N2 checks:

- [PASS] all 9 expected connections present, nothing else (9 connections)
- [PASS] feedback: alpha from component 5 (alphacl) back to components 1-4 ([('trim.alphacl.alpha', 'trim.aero.alpha'), ('trim.alphacl.alpha', 'trim.liftreq.alpha'), ('trim.alphacl.alpha', 'trim.pitch.alpha'), ('trim.alphacl.alpha', 'trim.prop.alpha')])
- [PASS] N2 marks the connections that close a cycle (4 cycle-arrow connections)
- [PASS] trim group holds the 5 components in run order (['pitch', 'aero', 'prop', 'liftreq', 'alphacl'])
- [PASS] solver shown on the trim group (NL: NLBGS)
- [PASS] each component's inputs and outputs as designed ({"pitch": [["alpha", "input"], ["de", "output"]], "aero": [["CD", "output"], ["CL", "output"], ["Cm", "output"], ["alpha", "input"], ["de", "input"]], "prop": [["CD", "input"], ["T", "output"], ["alpha", "input"]], "liftreq": [["CL_req", "output"], ["T", "input"], ["alpha", "input"]], "alphacl": [["CL_req", "input"], ["alpha", "output"], ["de", "input"]]})
- [PASS] exactly one coupling cycle, containing all 5 components ([['aero', 'alphacl', 'liftreq', 'pitch', 'prop']])

## NonlinearBlockGS with Aitken acceleration

| quantity | value |
|---|---|
| alpha | 3.7782530922 deg |
| elevator de | -2.5188353948 deg |
| thrust T | 1943.383957 lbf |
| CL | 0.2417908403 |
| Cm (should be 0) | 3.775e-18 |
| tolerances | atol 1e-10, rtol 1e-12, maxiter 100 |
| iterations | 11 |
| compute() calls (all components; implicit residual evaluations included) | 55 |
| compute_partials() / linearize() calls | 0 |
| agreement with independent fsolve | alpha 0.0e+00 deg, de 1.8e-15 deg, T 1.3e-11 lbf |

Calls per component: aero 11+0, alphacl 11+0, liftreq 11+0, pitch 11+0, prop 11+0 (compute + partials)

Residual history (absolute norm of the solver's residual per iteration):

| iter | abs residual | rel residual |
|---|---|---|
| 0 | 5.064e+02 | 1.455e+00 |
| 1 | 9.794e+01 | 2.814e-01 |
| 2 | 8.976e+00 | 2.579e-02 |
| 3 | 3.335e-02 | 9.581e-05 |
| 4 | 5.045e-03 | 1.449e-05 |
| 5 | 3.991e-04 | 1.147e-06 |
| 6 | 1.353e-06 | 3.887e-09 |
| 7 | 2.629e-07 | 7.553e-10 |
| 8 | 2.262e-08 | 6.499e-11 |
| 9 | 8.367e-11 | 2.404e-13 |

Reading the counts: 11 Gauss-Seidel sweeps (55 compute calls), no derivatives. Aitken changes only how far each sweep's update is applied: the new coupling values are x_k + theta_k (x_GS - x_k), with theta_k from the last two residuals. When the plain iteration contracts by a steady factor r, the ideal relaxation is about 1/(1 - r), which removes most of the error a plain sweep leaves behind. It costs nothing extra: the same component calls per sweep plus a few vector operations.

N2 diagram: `N2_trim_nlbgs_aitken.html`. Programmatic N2 checks:

- [PASS] all 9 expected connections present, nothing else (9 connections)
- [PASS] feedback: alpha from component 5 (alphacl) back to components 1-4 ([('trim.alphacl.alpha', 'trim.aero.alpha'), ('trim.alphacl.alpha', 'trim.liftreq.alpha'), ('trim.alphacl.alpha', 'trim.pitch.alpha'), ('trim.alphacl.alpha', 'trim.prop.alpha')])
- [PASS] N2 marks the connections that close a cycle (4 cycle-arrow connections)
- [PASS] trim group holds the 5 components in run order (['pitch', 'aero', 'prop', 'liftreq', 'alphacl'])
- [PASS] solver shown on the trim group (NL: NLBGS)
- [PASS] each component's inputs and outputs as designed ({"pitch": [["alpha", "input"], ["de", "output"]], "aero": [["CD", "output"], ["CL", "output"], ["Cm", "output"], ["alpha", "input"], ["de", "input"]], "prop": [["CD", "input"], ["T", "output"], ["alpha", "input"]], "liftreq": [["CL_req", "output"], ["T", "input"], ["alpha", "input"]], "alphacl": [["CL_req", "input"], ["alpha", "output"], ["de", "input"]]})
- [PASS] exactly one coupling cycle, containing all 5 components ([['aero', 'alphacl', 'liftreq', 'pitch', 'prop']])

## NewtonSolver + DirectSolver

| quantity | value |
|---|---|
| alpha | 3.7782530922 deg |
| elevator de | -2.5188353948 deg |
| thrust T | 1943.383957 lbf |
| CL | 0.2417908403 |
| Cm (should be 0) | 6.939e-19 |
| tolerances | atol 1e-10, rtol 1e-12, maxiter 20 |
| iterations | 4 |
| compute() calls (all components; implicit residual evaluations included) | 25 |
| compute_partials() / linearize() calls | 12 |
| agreement with independent fsolve | alpha 8.9e-16 deg, de 0.0e+00 deg, T 0.0e+00 lbf |

Calls per component: aero 5+4, alphacl 5+0, liftreq 5+4, pitch 5+0, prop 5+4 (compute + partials)

Residual history (absolute norm of the solver's residual per iteration):

| iter | abs residual | rel residual |
|---|---|---|
| 0 | 3.481e+02 | 1.000e+00 |
| 1 | 2.954e+00 | 8.488e-03 |
| 2 | 7.840e-03 | 2.252e-05 |
| 3 | 4.563e-10 | 1.311e-12 |
| 4 | 3.207e-17 | 9.213e-20 |

Reading the counts: row 0 is the residual of the initial guess; rows 1 onward follow each Newton step. 5 model evaluations x 5 components = 25 compute calls. compute_partials ran 4 times in each of the 3 components with non-constant derivatives (pitch and alphacl declare constant partials once), and DirectSolver did one LU solve per Newton step.

N2 diagram: `N2_trim_newton.html`. Programmatic N2 checks:

- [PASS] all 9 expected connections present, nothing else (9 connections)
- [PASS] feedback: alpha from component 5 (alphacl) back to components 1-4 ([('trim.alphacl.alpha', 'trim.aero.alpha'), ('trim.alphacl.alpha', 'trim.liftreq.alpha'), ('trim.alphacl.alpha', 'trim.pitch.alpha'), ('trim.alphacl.alpha', 'trim.prop.alpha')])
- [PASS] N2 marks the connections that close a cycle (4 cycle-arrow connections)
- [PASS] trim group holds the 5 components in run order (['pitch', 'aero', 'prop', 'liftreq', 'alphacl'])
- [PASS] solver shown on the trim group (NL: Newton)
- [PASS] each component's inputs and outputs as designed ({"pitch": [["alpha", "input"], ["de", "output"]], "aero": [["CD", "output"], ["CL", "output"], ["Cm", "output"], ["alpha", "input"], ["de", "input"]], "prop": [["CD", "input"], ["T", "output"], ["alpha", "input"]], "liftreq": [["CL_req", "output"], ["T", "input"], ["alpha", "input"]], "alphacl": [["CL_req", "input"], ["alpha", "output"], ["de", "input"]]})
- [PASS] exactly one coupling cycle, containing all 5 components ([['aero', 'alphacl', 'liftreq', 'pitch', 'prop']])

## BroydenSolver + DirectSolver (implicit lift balance, state alpha)

| quantity | value |
|---|---|
| alpha | 3.7782530919 deg |
| elevator de | -2.5188353946 deg |
| thrust T | 1943.383957 lbf |
| CL | 0.2417908402 |
| Cm (should be 0) | 0.000e+00 |
| tolerances | atol 1e-10, rtol 1e-12, maxiter 50 |
| iterations | 3 |
| compute() calls (all components; implicit residual evaluations included) | 51 |
| compute_partials() / linearize() calls | 4 |
| agreement with independent fsolve | alpha 3.0e-10 deg, de 2.0e-10 deg, T 9.6e-08 lbf |

Calls per component: aero 11+1, liftbal 7+1, liftreq 11+1, pitch 11+0, prop 11+1 (compute + partials)

Residual history (absolute norm of the solver's residual per iteration):

| iter | abs residual | rel residual |
|---|---|---|
| 0 | 2.433e-01 | 1.000e+00 |
| 1 | 4.675e-04 | 1.921e-03 |
| 2 | 1.791e-06 | 7.359e-06 |
| 3 | 1.965e-11 | 8.075e-11 |

Reading the counts: Broyden iterates on ONE state, alpha (the residual of the implicit lift balance). Each iteration takes a quasi-Newton step on alpha, then re-runs the explicit components to refresh de, CD, T and CL_req, which is why compute calls (51) exceed 5 x iterations. Exact derivatives were computed only for the first Jacobian (4 compute_partials/linearize calls); every later step uses a rank-1 (secant) update. With one state this is the secant method, order about 1.6.

N2 diagram: `N2_trim_broyden.html`. Programmatic N2 checks:

- [PASS] all 9 expected connections present, nothing else (9 connections)
- [PASS] feedback: alpha from component 5 (liftbal) back to components 1-4 ([('trim.liftbal.alpha', 'trim.aero.alpha'), ('trim.liftbal.alpha', 'trim.liftreq.alpha'), ('trim.liftbal.alpha', 'trim.pitch.alpha'), ('trim.liftbal.alpha', 'trim.prop.alpha')])
- [PASS] N2 marks the connections that close a cycle (4 cycle-arrow connections)
- [PASS] trim group holds the 5 components in run order (['pitch', 'aero', 'prop', 'liftreq', 'liftbal'])
- [PASS] solver shown on the trim group (NL: BROYDEN)
- [PASS] component 5 is implicit (alpha is a state) (component/implicit)
- [PASS] each component's inputs and outputs as designed ({"pitch": [["alpha", "input"], ["de", "output"]], "aero": [["CD", "output"], ["CL", "output"], ["Cm", "output"], ["alpha", "input"], ["de", "input"]], "prop": [["CD", "input"], ["T", "output"], ["alpha", "input"]], "liftreq": [["CL_req", "output"], ["T", "input"], ["alpha", "input"]], "liftbal": [["CL_req", "input"], ["alpha", "output"], ["de", "input"]]})
- [PASS] exactly one coupling cycle, containing all 5 components ([['aero', 'liftbal', 'liftreq', 'pitch', 'prop']])

## NewtonSolver + DirectSolver (implicit lift balance)  (comparison run)

| quantity | value |
|---|---|
| alpha | 3.7782530922 deg |
| elevator de | -2.5188353948 deg |
| thrust T | 1943.383957 lbf |
| CL | 0.2417908403 |
| Cm (should be 0) | 6.939e-19 |
| tolerances | atol 1e-10, rtol 1e-12, maxiter 20 |
| iterations | 4 |
| compute() calls (all components; implicit residual evaluations included) | 25 |
| compute_partials() / linearize() calls | 16 |
| agreement with independent fsolve | alpha 0.0e+00 deg, de 0.0e+00 deg, T 2.3e-13 lbf |

Calls per component: aero 5+4, liftbal 5+4, liftreq 5+4, pitch 5+0, prop 5+4 (compute + partials)

Residual history (absolute norm of the solver's residual per iteration):

| iter | abs residual | rel residual |
|---|---|---|
| 0 | 3.481e+02 | 1.000e+00 |
| 1 | 2.954e+00 | 8.488e-03 |
| 2 | 7.840e-03 | 2.252e-05 |
| 3 | 4.563e-10 | 1.311e-12 |
| 4 | 8.239e-18 | 2.367e-20 |

Same Newton + DirectSolver on the implicit formulation: the residual history matches the explicit run, as it should, because both formulations define the same root.

## BroydenSolver + DirectSolver (full-model mode, explicit loop)  (comparison run)

| quantity | value |
|---|---|
| alpha | 3.7782530922 deg |
| elevator de | -2.5188353948 deg |
| thrust T | 1943.383957 lbf |
| CL | 0.2417908403 |
| Cm (should be 0) | 0.000e+00 |
| tolerances | atol 1e-10, rtol 1e-12, maxiter 50 |
| iterations | 11 |
| compute() calls (all components; implicit residual evaluations included) | 175 |
| compute_partials() / linearize() calls | 9 |
| agreement with independent fsolve | alpha 0.0e+00 deg, de 8.9e-16 deg, T 6.8e-13 lbf |

Calls per component: aero 35+3, alphacl 35+0, liftreq 35+3, pitch 35+0, prop 35+3 (compute + partials)

Residual history (absolute norm of the solver's residual per iteration):

| iter | abs residual | rel residual |
|---|---|---|
| 0 | 2.510e+00 | 1.000e+00 |
| 1 | 2.531e+00 | 1.008e+00 |
| 2 | 1.607e+06 | 6.402e+05 |
| 3 | 5.152e+05 | 2.052e+05 |
| 4 | 5.390e+06 | 2.147e+06 |
| 5 | 9.689e+06 | 3.860e+06 |
| 6 | 2.431e+03 | 9.686e+02 |
| 7 | 7.447e-02 | 2.967e-02 |
| 8 | 5.319e-03 | 2.119e-03 |
| 9 | 4.362e-06 | 1.738e-06 |
| 10 | 2.511e-10 | 1.001e-10 |
| 11 | 5.648e-17 | 2.250e-17 |

Comparison, not recommended: Broyden in full-model mode (no state_vars) on the all-explicit loop. It converges, but only after the residual grows to about 1e7 and two extra exact Jacobians are computed (9 compute_partials calls in all). Each Broyden iteration also re-runs the explicit components, which overwrite the outputs Broyden just updated, so the rank-1 secant updates see changes the step did not make. OpenMDAO's Broyden is meant for implicit states; the implicit lift-balance run is the correct use.

Analytic partial derivatives vs complex step (force_alloc_complex=True), both formulations: worst relative error 3.0e-16.

## Comparison

| approach | iterations | compute calls | derivative calls | convergence |
|---|---|---|---|---|
| Gauss-Seidel | 14 | 70 | 0 | linear, factor 0.074 per iteration |
| Gauss-Seidel + Aitken | 11 | 55 | 0 | linear with adaptive relaxation; see history |
| Newton | 4 | 25 | 12 | quadratic |
| Broyden (state alpha) | 3 | 51 | 4 | superlinear (secant) |

- **Gauss-Seidel** needs no derivatives and is cheapest per iteration. It converges at a fixed rate set by the loop gain (how strongly alpha feeds back through the elevator and thrust); it would slow as the gain nears 1 and diverge above it.
- **Aitken acceleration** keeps Gauss-Seidel's zero derivative cost and cut the iterations from 14 to 11 here. It works best when the plain iteration contracts at a steady rate, as here; it can also rescue a Gauss-Seidel loop whose gain is near or above 1, which plain Gauss-Seidel cannot converge.
- **Newton** uses an exact Jacobian every iteration (derivatives + one linear solve), so each iteration costs most, but it converges quadratically: the number of correct digits roughly doubles per step.
- **Broyden** gets most of Newton's speed with almost none of its derivative cost: one exact Jacobian, then cheap rank-1 updates. Its catch, shown by the comparison run, is that in OpenMDAO it must iterate on implicit states; pointed at explicit outputs it fights the components that recompute them.
- **All runs give the same trim**, agreeing with the independent fsolve to round-off (Broyden to its tolerance).
- **Residuals are not on one scale.** Newton reports the norm of the whole group residual; Broyden only the residual of its state (the lift balance, in CL units); Gauss-Seidel the change in outputs between sweeps. Each met the same atol/rtol on its own measure, so compare iteration counts and convergence shape, not raw magnitudes.

![residual history](residual_history.png)

**Overall: ALL CHECKS PASS**