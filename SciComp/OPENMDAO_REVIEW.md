# OpenMDAO: what it is, how it works, where it is used

Written for this SciComp test bench (October 2026). The building-block names below were checked against the installed OpenMDAO 3.45.1 (`openmdao.api`). The history and application notes come from my knowledge of the project and its literature, not from fresh browsing; treat version-specific details as indicative.

## 1. What it is

OpenMDAO is an open-source Python framework for **multidisciplinary analysis and optimization (MDAO)**. NASA Glenn Research Center leads it under the Apache 2.0 licence. Its job is to wire many separate analyses (aerodynamics, structures, propulsion, trajectory, cost) into one coupled model. It then does three things for that model:

1. converges the couplings between the disciplines (an MDA: multidisciplinary analysis)
2. computes **total derivatives** of the whole model efficiently
3. hands those to an optimizer or design-of-experiments driver

Its core idea is the **Modular Analysis and Unified Derivatives (MAUD)** architecture (Hwang and Martins, 2018). Every model is a set of components with inputs, outputs and residuals. Total derivatives come from the partial derivatives each component provides, solving one unified linear system in forward (direct) or reverse (adjoint) mode. The framework paper is Gray, Hwang, Martins, Moore and Naylor, "OpenMDAO: an open-source framework for multidisciplinary design, analysis, and optimization", *Structural and Multidisciplinary Optimization*, 2019.

## 2. Building blocks

| Concept | What it is | Examples in `openmdao.api` |
|---|---|---|
| **Problem** | top-level container: model + driver + recorders | `om.Problem` |
| **Group** | a container of subsystems; owns a nonlinear and a linear solver | `om.Group` |
| **ExplicitComponent** | outputs computed directly from inputs: `compute()`, `compute_partials()` | every component in `trim_mda.py` |
| **ImplicitComponent** | defines residuals R(inputs, outputs) = 0: `apply_nonlinear()`, `linearize()`, optional `solve_nonlinear()` | state solvers, balance equations |
| Ready-made components | equation strings, balances, surrogates, external codes | `ExecComp`, `BalanceComp`, `EQConstraintComp`, `MetaModelStructuredComp`, `MetaModelUnStructuredComp`, `SplineComp`, `ExternalCodeComp`, `KSComp`, `MuxComp`, `SubmodelComp` |
| **Connections** | data links, either explicit `connect(src, tgt)` or by promoting matching names | units are converted automatically when declared |
| **Nonlinear solvers** | converge the couplings inside a group | `NonlinearRunOnce`, `NonlinearBlockGS`, `NonlinearBlockJac`, `NewtonSolver`, `BroydenSolver` |
| **Line searches** | globalize Newton and Broyden | `BoundsEnforceLS`, `ArmijoGoldsteinLS` |
| **Linear solvers** | solve Newton steps and derivative systems | `DirectSolver`, `LinearBlockGS`, `LinearBlockJac`, `ScipyKrylov`, `PETScKrylov`, `PETScDirectSolver`, `LinearUserDefined` |
| **Drivers** | iterate on the whole model | `ScipyOptimizeDriver`, `pyOptSparseDriver` (SNOPT, IPOPT, etc.), `DOEDriver`, `SimpleGADriver`, `DifferentialEvolutionDriver`, `pymooDriver`, `AnalysisDriver` |
| **Derivatives** | analytic partials; or finite difference / complex step per component; total derivatives in forward or reverse mode | `declare_partials`, `check_partials`, `check_totals`, `compute_totals` |
| **Recording** | every solver or driver iteration saved to SQLite | `SqliteRecorder`, `CaseReader` |
| **Visualization** | N2 diagram (`om.n2` or `openmdao n2`), optimization reports, connection viewer | `trim_mda.py` writes two N2s |

### The solver hierarchy, and why the N2 shows it
Each group has its own nonlinear and linear solver, so solvers nest the way the model does. An outer Newton can converge a group whose subgroups each run Gauss–Seidel, and so on. The N2 diagram draws the model tree with the solver of every group beside it. Its off-diagonal blocks are connections: above the diagonal is feed-forward, below it is feedback. It marks connections that close a **coupling cycle**, which is the strongly connected part of the data graph that a nonlinear solver must iterate. That makes it the quickest way to see whether a cycle is owned by a solver able to converge it. Leaving a cycle under the default `NonlinearRunOnce` is the classic OpenMDAO mistake: it silently returns an unconverged answer.

### Gauss–Seidel vs Newton (what the trim study shows)
- **NonlinearBlockGS** runs the subsystems in order and repeats, which is a fixed-point iteration. It needs no derivatives and is cheap per iteration. It converges linearly at a rate set by the loop gain of the coupling, slows as the gain nears 1, and diverges above it. Aitken relaxation (`use_aitken`) helps.
- **NewtonSolver** linearizes the coupled residual and solves for a step with a linear solver (here `DirectSolver`). It needs partial derivatives (analytic, finite difference or complex step). Close to the answer it converges quadratically and copes with strong coupling. Far away it needs a line search, and each iteration costs more.

## 3. Use cases and tools built on OpenMDAO

| Tool or application | Area |
|---|---|
| **Aviary** (NASA) | aircraft conceptual design and mission analysis; the modern NASA aircraft-sizing tool |
| **pyCycle** (NASA) | thermodynamic cycle analysis of gas-turbine engines, with derivatives |
| **Dymos** | optimal control and trajectory optimization (pseudospectral methods) |
| **OpenAeroStruct** | coupled vortex-lattice aerodynamics and beam structures for wing design |
| **OpenConcept** | conceptual design of electric and hybrid aircraft |
| **WEIS / WISDEM** (NREL) | wind-turbine and wind-plant design |
| **CADRE** | CubeSat design (an early large OpenMDAO demonstration) |
| research uses | electric VTOL and distributed-propulsion sizing, coupled aero-propulsive design, thermal management, space mission design |

Typical pattern: physics codes become components; couplings are closed with Newton or Gauss–Seidel; a gradient optimizer drives hundreds or thousands of design variables using adjoint total derivatives.

## 4. How this relates to VITAL (for later)

VITAL's trim is a single plant with an `lsqnonlin` solve. The OpenMDAO version in `trim_mda.py` instead splits the same balance into disciplines (elevator balance, aerodynamics, drag balance, lift) and lets a framework solver close the loop.

It would become useful if VITAL grows into design work, for example the X-57 with many propeller components and an optimizer sizing them. MATLAB code could be wrapped with `ExternalCodeComp`, or through MATLAB's Python engine. That was not done here, and this bench is deliberately independent of VITAL.
