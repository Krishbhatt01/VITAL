# ADRs proposed by agent `linear` (M5-A)

## ADR-0xx: Linearization by a step-study central difference that detects table breakpoints (2026-09-29)
- **Context:** the NESC F-16 aero and propulsion tables are piecewise-multilinear. At a breakpoint the derivative is one-sided. A central difference there does NOT fail to plateau: for a piecewise-linear function it returns the average of the left and right slopes at every step. A plateau test alone therefore accepts a wrong number silently.
- **Decision:** `vital.linear.jacobian` evaluates each column at h0, h0/10, ..., h0/10^6.
  - Acceptance: three successive weighted estimates agree within RelTol = 1e-6 of the weighted column (plus AbsTol 1e-10). The middle estimate is accepted.
  - Breakpoint detection: the one-sided asymmetry s = ||W (f(z+h) - 2 f(z) + f(z-h))/h|| must shrink with h (ratio 1/10 per step for smooth functions). If s exceeds KinkTol = 1e-6 of the column at the accepted step and has not decayed (s_k >= 0.5 s_(k-1)), the column is a kink.
  - Any failed column is NaN and the status is `NOT_CONVERGED`, naming the column and its cause (FC-506, FC-510). A plausible number is never returned.
- **Rows and columns are weighted** by typical magnitudes, so that the acceptance norm does not mix units: FScale = [g g g, 1 rad/s^2 x3, 1 rad/s x3, V x3] and ZScale = [10 m/s x3, 1 rad/s x3, 1 rad x3, 1000 m x3, 0.1 rad x3, 1].
- **Consequence:** the F-16 README trim (alpha 2.65 deg, de -3.24 deg, beta 0, 13 ft above the 10,000 ft thrust-table breakpoint) linearizes with every column OK. The first 10 m altitude step straddles the breakpoint; the study converges at 0.1 m. beta = 0 is a breakpoint of the |beta| tables, but the NESC model makes Cl and Cn odd in beta (sign(beta) * table(|beta|)), and the da, dr products vanish at da = dr = 0, so no kink arises there.

## ADR-0xx: Flight modes are classified by participation factors, not eigenvector magnitudes (2026-09-29)
- **Context:** the AAMF classifier (StabilityAnalysis.m:448-696) decided longitudinal versus lateral, and picked the short period and Dutch roll, from raw right-eigenvector magnitudes summed across states with different units (m/s and rad/s). The result depends on the choice of units. It also labelled a real root as the "short period" with a period and damping.
- **Decision:** `vital.linear.modes` uses normalized participation factors p_k = |v_k w_k| (w = rows of inv(V)), which are invariant under a diagonal change of units. The classifier then works as follows:
  - Groups: lon if the participation in {u w q theta} exceeds 0.5.
  - Time scale inside a group:
    - Longitudinal: two pairs mean faster = short period.
    - Lateral: the real roots split as faster = roll, slower = spiral.
  - Participation signatures confirm each name:
    - short period: w + q > u + theta
    - phugoid: u + theta > w + q
    - Dutch roll: v + r > p + phi
    - roll: p is the largest
    - spiral: phi or r is the largest
  - A group of real roots where a pair is expected is `NOT_OSCILLATORY`, with wn, zeta and period NaN (FC-507).
  - Anything else is `other` / `UNCLASSIFIED`, with a reason.
  - An ill-conditioned eigenvector matrix (cond > 1e10) makes every mode UNCLASSIFIED.
- **Time constants:** tau = -1/lambda for real roots (negative means unstable). tHalf and tDouble are each NaN when they do not apply.

## ADR-0xx: Closed-loop linearization is limited to declared-static controllers (2026-09-29)
- **Decision:** `linearize(..., 'Controller', c)` follows the vital.sim.run semantics.
  - The controller output is u = step(0, x, y(x, u_ref), u_ref, state0), with y evaluated at (x, u_ref).
  - The closed loop is f = plant(x, u(x, u_ref)).
  - It returns closed-loop A and B, the open loop, and the controller Jacobians K and Kref.
- **Static only:** the controller must declare `static = true`, and every call must return the initial state.
  - Detection alone is not enough: an integrator of a trim-zero error is unchanged at the trim itself.
  - Otherwise the call fails with `vital:linear:dynamicController`.
- **Equilibrium:** a controller whose trim output differs from u0 is refused (`vital:linear:controllerNotAtTrim`).
- **Sampling:** it is a continuous approximation; the ZOH delay is not modelled.
- **Later:** dynamic controllers (filters, integrators) need an augmented-state linearization, which is left for M7.

## ADR-0xx: Optional height state in modal analysis (2026-09-29)
- **Decision:** `modes(lin, 'IncludeHeight', true)` analyses [u v w p q r phi theta h] and names the extra real root 'height'. The default stays at 8 states per the contract.
- **Reason:** the 8-state phugoid is 7 % off the nonlinear plant at the README trim (tLinearVsNonlinear).

## ADR-0xx: Review R1 fixes to linearization and modes (2026-09-30; agent `linear`)
- **Equilibrium (R1 B1).** `linearize` requires ||W f0(1:8)||_inf <= TrimTol = 1e-8 for the (AC, env) it is given, with W = [1/g x3, 1 x5]. Otherwise it raises `vital:linear:notEquilibrium`.
  - The trim solver accepts a scaled residual < 1e-9, and R1 measured 3e-16.
  - A trim made with another CG or g is refused rather than silently linearized. That is exactly how R1-L12/L13 escaped.
- **MIL n/alpha (R1 B2).** `lin.n_alpha_ss` is MIL-F-8785C 6.2 n/alpha: the steady state at constant speed per pitch-control deflection, (V/g) q/alpha, including Z_de and Z_q. It is computed by `vital.linear.nAlphaSteady` and is identical to `vital.fq.metrics` n_alpha_g_per_rad.
  - It is defined for level trims only (NaN with status NOT_LEVEL otherwise).
  - `lin.n_alpha` stays as the alpha-only partial and is documented as NOT the MIL quantity.
- **Round-off-limited plateaus (R1 B3).** The step study refuses a plateau when the value-rounding error eps * max|W f| * ZScale / h exceeds 1 % of the plateau tolerance. The column status is ROUNDOFF and the model is NOT_CONVERGED.
- **Accuracy (R1 MINOR 10).** Accuracy is column-relative (inf-norm): entries are accurate to about RelTol of the column maximum, and sub-KinkTol kinks are averaged.
- **Per-column status (R1 M1).** `lin.columnStatus` gives one status per column (16).
  - `lin.status` stays NOT_CONVERGED if any column fails.
  - `modes` needs only the columns it uses: 1-8, plus 12 with IncludeHeight.
  - Consequence: a round-number altitude (thrust-table breakpoint in h) no longer blocks the 8-state modes.
- **Phugoid default (R1 M5).** `modes` stays 8-state (contract) and says so. `run_f16_modes` also prints the phugoid and height mode with altitude coupling (IncludeHeight), labelled 'phugoid (with h)'. M6 phugoid rules use IncludeHeight.
- **Closed loop (ADR-026).** The controller is called through `vital.sim.sampleController` with y evaluated at the applied command u. The algebraic loop u = step(x, y(x, u)) is solved by one fixed-point step and then Newton's method.
  - Converged: residual <= 1e-14 (1 + |u|), or a stalled residual <= 1e-11 (1 + |u|).
  - Otherwise `vital:linear:algebraicLoop`. A controller error gives `vital:linear:controllerError`.
- **Classifier and controller design constants (R1 MINOR 9; not published values):**
  - lonFraction 0.5
  - dominant: 80 % cumulative participation
  - oscillatory if |Im| > 1e-9 |lambda|
  - cond(V) > 1e10 means UNCLASSIFIED
  - third-oscillatory note at p_w + p_q > 0.2
  - controllerNotAtTrim at 1e-9 (1 + |u0|)
  - TrimTol 1e-8
  - round-off factor 0.01 of the plateau tolerance
- **Static-controller check (R1 MINOR 12).** The `isequal(state, state0)` test also refuses static laws that keep bookkeeping state. This is conservative.
- **Sampling (R1 MINOR 11).** The ZOH half-sample delay is not modelled in the closed loop. tClosedLoopSimAgreement shows the sim-vs-linear difference is first order in dt.
