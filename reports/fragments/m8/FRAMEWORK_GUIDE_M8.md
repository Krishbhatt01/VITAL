## 12a. M8: uncertainty and robustness

**What it is.** M7 lifted every in-envelope group to Level 1, using NASA's aerodynamic tables exactly as published. Those tables come from wind-tunnel and flight data, and real data carry error. M8 asks: **does each Level 1 grade still hold if the aerodynamics are somewhat off?** The answer is a verdict per requirement group: **ROBUST**, **NOT_ROBUST** or **NOT_ASSESSABLE**. A number comes with it that says how much error the grade tolerates.

### The uncertain parameters
Each uncertain quantity is a **multiplier on one term of NASA's tables** (`AeroScale`, nominal 1; ADR-032, amendment R4-5). A multiplier equal to 1 leaves the model bit-identical.

| Parameter | What it scales | Group | 1-sigma |
|---|---|---|---|
| Cm_q | pitch damping cmq | pitchDamping | 0.10 |
| Cm_basic | static pitching moment cmt(el = 0) | pitchStatic | 0.05 |
| Cm_de | elevator power cmt - cmt(el = 0) | pitchStatic | 0.05 |
| Cl_p, Cn_r | roll and yaw damping clp, cnr | latDamping | 0.10 |
| Cl_table, Cnt_table | sideslip roll and yaw tables clt, cnt | latStatic | 0.05 |

NASA publishes no uncertainty for these tables. **The sigmas are therefore engineering JUDGMENT**, and every report labels them so. The method is designed so that the conclusion depends on them as little as possible.

**The judged box.** Each group gets a half-width k_g · sigma, with k_g = sqrt(chi2inv(0.99, d)), so the box contains that group's 99 % ellipsoid. The full box is the product of the group boxes, with joint coverage 0.9758.

### The headline number: CSR
The Critical Similitude Ratio (Crespo, Kenny and Giesy, NASA LaRC) works like this:
- Take the judged box and scale it by a factor alpha about the nominal: R(alpha) = [1 - alpha·m, 1 + alpha·m].
- **alpha\*** is the largest alpha for which the margin to the nominal Level stays >= 0 everywhere in R(alpha), searched over alpha in [0, 3].
- **alpha\* >= 1** means the whole judged box passes. alpha\* = 0.4 means the grade survives only 40 % of the judged uncertainty.
- The **CPV** (critical parameter value) is the point where failure first appears. A fresh assessment confirms it.
- A second reference shape, a 10 % tolerance on every parameter, gives a check that does not depend on the judged ratios between the parameters.

### How the worst case is found
- **Longitudinal groups (3.2.x), with 3 parameters (Cm_q, Cm_basic, Cm_de),** use one **shared adaptive lattice** per candidate condition. The lattice is refined only near where the margin crosses zero.
  - A cell is *certified* when its lowest vertex margin minus L·h/2 is >= 0. L is twice the measured local slopes (amendment R5-1).
  - Where the trim crosses a table breakpoint (for example alpha = 5°), the margin jumps. Each side of the jump is certified from its own vertices (R5-3).
  - The certificate is labelled "grid-certified (Lipschitz estimate)". It is an estimate, not a proof: a feature narrower than one cell would be invisible to it.
- **Lateral groups (3.3.x)** use a hybrid search: seeded differential evolution, then Nelder-Mead. Cm_q is dropped, because the pitch rate is zero at a wings-level trim (R4-9); a test gates that assumption.
  - Longitudinal groups likewise hold the lateral multipliers at 1 (R3-M3a, also gated).
- **The spiral (3.3.1.3)** has an infinite nominal margin, so it is searched on a smooth surrogate: the real part of the spiral root.
- **Moving limit.** Every worst point is re-checked with a fresh full in-envelope assessment. If that check finds a worse condition, the condition is added and the search re-runs, up to 3 rounds (R3-M4). The 2^d corners of R(1) are checked in the same way (R5-5).
- **Breakpoint bracketing (R4-7).** A linearization that fails exactly at a table breakpoint is evaluated just on either side, and the worse of the two margins counts.
- **Monte Carlo.** N = 200 samples at the critical condition. The one-sided 95 % Clopper–Pearson lower bound on the success rate must be >= 0.95.
- **Staged run (R4-8).** Stage 1 runs everything on a reduced budget. Stage 2 repeats, at full budget, only the groups whose CSR falls in the measured uncertainty band [0.8, 1.2] (R5-4).

### The verdict (amendment R5-2)
- **ROBUST:** the judged box R(1) is certified (lattice) or searched clean (hybrid), **and** the Clopper–Pearson lower bound is >= 0.95.
- **NOT_ROBUST:** a confirmed failing point inside R(1), or the Clopper–Pearson lower bound is < 0.95.
- **NOT_ASSESSABLE:** anything else. It means "not established", not "fails".

### Result (full default run, `reports/uq/f16_uq_default.md`)
HEADLINE_TABLE

### Files
| File | What it does |
|---|---|
| `+uq\loadSpec`, `box`, `boxCoverage` | the uncertainty specification, the judged box and its coverage |
| `+uq\lattice`, `breakpoints`, `bracket` | the shared certified lattice, the table breakpoints and breakpoint bracketing |
| `+uq\boundWorst`, `diffEvolution`, `searchMethod`, `surrogateWorst` | the worst-case searches |
| `+uq\csr`, `lowerEnd`, `stageBand`, `stagePlan` | CSR, its bracket, and the staged run |
| `+uq\monteCarlo`, `clopperPearson`, `verdict`, `headline` | the Monte Carlo, the binomial bound and the verdict |
| `+uq\F16Evaluator`, `analyze`, `writeReport`, `statements` | the F-16 margin evaluator (with caching), the driver, and the report with its judgment statements |
| `run_f16_uq.m` | the command you type |

### Tests
`tests\M8`:
- toy counterexamples: a cliff outside the box, an interaction valley, a moving limit, an active-set switch, a kinked valley;
- Clopper–Pearson against its closed forms;
- lattice certificates on toys with known answers;
- CSR known answers;
- F-16 structural invariants;
- the invariance gates;
- the report text.

Every planted bug in the `sabotages_uq*.json` and `sabotages_R*.json` files is caught. Reviews R3 and R5 checked the whole section, and amendments R3, R4, R4b and R5 record what changed in response.

### Limits
- The sigmas are judgment.
- The certificates are Lipschitz estimates.
- Only wings-level, 1-g trims are covered.
- The Monte Carlo runs at the critical condition only.
- Cm_basic and Cm_de are treated as independent, although both come from one table.

### What it feeds
Robust gain design (maximizing CSR with the M7 search) is the next increment.

---
