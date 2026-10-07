# SciComp: OpenMDAO trim-loop test bench

A self-contained test, separate from the VITAL MATLAB framework. Nothing here is used by VITAL's tests or gates.

| File | What it is |
|---|---|
| `trim_mda.py` | the model and the study: five coupled components with one feedback loop, converged with Nonlinear Block Gauss–Seidel (with and without Aitken acceleration), Newton + DirectSolver, and Broyden; two extra comparison runs (Newton on the implicit form, Broyden in full-model mode) |
| `N2_trim_nlbgs.html`, `N2_trim_nlbgs_aitken.html`, `N2_trim_newton.html`, `N2_trim_broyden.html` | **the N2 diagrams** (open in a browser), one per solver. Gauss–Seidel (both), and Newton use the explicit form; Broyden uses the implicit form, where component 5 (`liftbal`) holds alpha as a state with a lift-balance residual. The connections and the cycle are the same in all three |
| `results/convergence_report.md` | final values, tolerances, iterations, function calls, residual histories, the N2 checks, and the comparison |
| `results/residual_history.png` | residual vs iteration for all solvers, including the Broyden full-model comparison |
| `results/results.json`, `results/cases_*.sql` | the raw numbers and the OpenMDAO recorder files |
| `OPENMDAO_REVIEW.md` | what OpenMDAO is, its building blocks, solvers and use cases |

**Run:** `python trim_mda.py`. It needs OpenMDAO 3.45.1, which is installed in the global Python 3.10. Exit code 0 means every check passed.

**The model:** longitudinal trim for steady level flight, at F-16-like scale but with surrogate linear aerodynamics, not VITAL's NASA F-16 model.

```
alpha --> [1 pitch: de] --> [2 aero: CD] --> [3 prop: T] --> [4 liftreq: CL_req] --> [5 alphacl: alpha] --+
  ^                                                                                                       |
  +----------------------------- feedback: alpha into 1, 2, 3, 4 ------------------------------------------+
```

**Why Broyden uses the implicit form:** OpenMDAO's Broyden iterates on implicit *states*. Pointed at an explicit output, it fights the component that recomputes that output on every pass; the comparison run in the report shows this.

**How to read the N2:** components sit on the diagonal. Cells above the diagonal are feed-forward connections; cells below it are the feedback of alpha from component 5 (`alphacl`, or `liftbal` in the Broyden file) to the first four components. Those are the arrows that close the coupling cycle. The solver box beside the `trim` group shows which nonlinear solver converges the cycle: NLBGS (with or without Aitken; Aitken is a solver option, so both show NLBGS), Newton or Broyden, one per file. The viewer opens on the linear solver; a left-toolbar toggle switches it to the nonlinear one.
