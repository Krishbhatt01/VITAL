"""Coupled longitudinal TRIM loop in OpenMDAO, converged two ways.

SciComp test bench, separate from the VITAL MATLAB framework. The numbers are
F-16-like for scale only: a linear-aerodynamics surrogate, NOT the NASA F-16
model used by VITAL.

What the model solves
---------------------
Steady, wings-level, unaccelerated flight at speed V and altitude h needs two
balances (force along the lift direction, pitching moment), plus the thrust
that cancels drag. Written as five explicit components that pass data around a
loop:

    1 pitch  : elevator for zero pitching moment     alpha       -> de
    2 aero   : drag and pitching-moment coefficients  alpha, de   -> CD, Cm
    3 prop   : thrust that cancels drag               CD, alpha   -> T
    4 liftreq: lift coefficient still required        T, alpha    -> CL_req
    5 alphacl: angle of attack giving that lift        CL_req, de  -> alpha

alpha (output of component 5) feeds back into components 1, 2 and 4: one
coupling cycle (a strongly connected component of the data graph). The
group's nonlinear solver must iterate to make alpha consistent.

Physics (small set of explicit equations, units ft, lbf, slug, rad)
    CL  = CL0 + CLa*alpha + CLde*de          CD = CD0 + K*CL**2
    Cm  = Cm0 + Cma*alpha + Cmde*de          (pitch balance Cm = 0)
    T   = qbar*S*CD / cos(alpha)             (thrust along the body x axis; level flight)
    L   = qbar*S*CL ;  L + T*sin(alpha) = W  (lift + thrust component = weight)

Three solution approaches on the SAME model
    A  NonlinearBlockGS (block Gauss-Seidel: run the components in order, repeat)
    B  NewtonSolver with DirectSolver (Newton on the coupled residual, analytic partials)
    C  BroydenSolver (quasi-Newton: one exact Jacobian, then rank-1 updates of its inverse)
    D  NonlinearBlockGS with Aitken acceleration (dynamic relaxation of the Gauss-Seidel update)
For each: final result, tolerances, iterations, function calls (compute,
compute_partials and linear solves counted per component), residual history
(recorded with an OpenMDAO SqliteRecorder on the solver).

Checks
    * the converged trim is compared with an INDEPENDENT solve of the two
      balance equations with scipy.optimize.fsolve (no OpenMDAO involved);
    * the N2 data (the same data the .html shows) is checked programmatically:
      component inputs and outputs, every expected connection, and exactly one
      coupling cycle containing all five components, with the solver that owns it;
    * check_partials confirms the analytic derivatives used by Newton.

Run:  python trim_mda.py          (writes into results/ next to this file)
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
import openmdao
import openmdao.api as om
from scipy.optimize import fsolve

HERE = Path(__file__).resolve().parent
OUT = HERE / "results"

# --------------------------------------------------------------------------
# Flight condition and surrogate aerodynamic data (F-16-like scale)
# --------------------------------------------------------------------------
P = dict(
    W=20500.0,          # weight, lbf
    S=300.0,            # wing area, ft^2
    V=565.6854,         # true airspeed, ft/s
    rho=0.0017553,      # air density at ~10,013 ft (US 1976), slug/ft^3
    CL0=0.0, CLa=4.0, CLde=0.5,       # lift: per rad
    CD0=0.016, K=0.12,                # drag polar
    Cm0=0.0, Cma=-0.4, Cmde=-0.6,     # pitching moment: per rad (statically stable, Etkin signs)
)
P["qbar"] = 0.5 * P["rho"] * P["V"] ** 2          # psf

CALLS: dict[str, dict[str, int]] = {}


def _count(name: str, kind: str) -> None:
    CALLS.setdefault(name, {"compute": 0, "compute_partials": 0})[kind] += 1


# --------------------------------------------------------------------------
# Components (explicit: outputs computed directly from inputs)
# --------------------------------------------------------------------------
class PitchBalance(om.ExplicitComponent):
    """1: elevator that zeroes the pitching moment: de = -(Cm0 + Cma*alpha) / Cmde."""

    def setup(self):
        self.add_input("alpha", 0.0, units="rad")
        self.add_output("de", 0.0, units="rad")
        self.declare_partials("de", "alpha", val=-P["Cma"] / P["Cmde"])   # constant partial

    def compute(self, i, o):
        _count(self.pathname, "compute")
        o["de"] = -(P["Cm0"] + P["Cma"] * i["alpha"]) / P["Cmde"]


class Aero(om.ExplicitComponent):
    """2: CL, CD (parabolic polar) and Cm from alpha and elevator."""

    def setup(self):
        self.add_input("alpha", 0.0, units="rad")
        self.add_input("de", 0.0, units="rad")
        self.add_output("CL", 0.0)
        self.add_output("CD", P["CD0"])
        self.add_output("Cm", 0.0)
        self.declare_partials("*", "*")

    def compute(self, i, o):
        _count(self.pathname, "compute")
        CL = P["CL0"] + P["CLa"] * i["alpha"] + P["CLde"] * i["de"]
        o["CL"] = CL
        o["CD"] = P["CD0"] + P["K"] * CL ** 2
        o["Cm"] = P["Cm0"] + P["Cma"] * i["alpha"] + P["Cmde"] * i["de"]

    def compute_partials(self, i, J):
        _count(self.pathname, "compute_partials")
        CL = P["CL0"] + P["CLa"] * i["alpha"] + P["CLde"] * i["de"]
        J["CL", "alpha"] = P["CLa"]; J["CL", "de"] = P["CLde"]
        J["CD", "alpha"] = 2 * P["K"] * CL * P["CLa"]; J["CD", "de"] = 2 * P["K"] * CL * P["CLde"]
        J["Cm", "alpha"] = P["Cma"]; J["Cm", "de"] = P["Cmde"]


class Propulsion(om.ExplicitComponent):
    """3: thrust along body x that balances drag in level flight: T = qbar S CD / cos(alpha)."""

    def setup(self):
        self.add_input("CD", P["CD0"])
        self.add_input("alpha", 0.0, units="rad")
        self.add_output("T", 1000.0, units="lbf")
        self.declare_partials("T", ["CD", "alpha"])

    def compute(self, i, o):
        _count(self.pathname, "compute")
        o["T"] = P["qbar"] * P["S"] * i["CD"] / np.cos(i["alpha"])

    def compute_partials(self, i, J):
        _count(self.pathname, "compute_partials")
        qS = P["qbar"] * P["S"]; c = np.cos(i["alpha"])
        J["T", "CD"] = qS / c
        J["T", "alpha"] = qS * i["CD"] * np.sin(i["alpha"]) / c ** 2


class LiftRequired(om.ExplicitComponent):
    """4: lift coefficient still needed after thrust's vertical share: CL_req = (W - T sin a)/(qbar S)."""

    def setup(self):
        self.add_input("T", 1000.0, units="lbf")
        self.add_input("alpha", 0.0, units="rad")
        self.add_output("CL_req", 0.2)
        self.declare_partials("CL_req", ["T", "alpha"])

    def compute(self, i, o):
        _count(self.pathname, "compute")
        o["CL_req"] = (P["W"] - i["T"] * np.sin(i["alpha"])) / (P["qbar"] * P["S"])

    def compute_partials(self, i, J):
        _count(self.pathname, "compute_partials")
        qS = P["qbar"] * P["S"]
        J["CL_req", "T"] = -np.sin(i["alpha"]) / qS
        J["CL_req", "alpha"] = -i["T"] * np.cos(i["alpha"]) / qS


class AlphaFromLift(om.ExplicitComponent):
    """5: angle of attack that produces CL_req with this elevator: alpha = (CL_req - CL0 - CLde de)/CLa."""

    def setup(self):
        self.add_input("CL_req", 0.2)
        self.add_input("de", 0.0, units="rad")
        self.add_output("alpha", 0.0, units="rad")
        self.declare_partials("alpha", "CL_req", val=1.0 / P["CLa"])
        self.declare_partials("alpha", "de", val=-P["CLde"] / P["CLa"])

    def compute(self, i, o):
        _count(self.pathname, "compute")
        o["alpha"] = (i["CL_req"] - P["CL0"] - P["CLde"] * i["de"]) / P["CLa"]


class LiftBalance(om.ImplicitComponent):
    """5 (implicit form): alpha is a STATE defined by the lift balance residual
        R(alpha) = CL0 + CLa*alpha + CLde*de - CL_req = 0.
    Same physics as AlphaFromLift; used for Broyden, whose state_vars must be implicit states
    (an explicit output would be overwritten by its own component on every sub-solve)."""

    def setup(self):
        self.add_input("CL_req", 0.2)
        self.add_input("de", 0.0, units="rad")
        self.add_output("alpha", 0.0, units="rad")
        self.declare_partials("alpha", ["CL_req", "de", "alpha"])

    def apply_nonlinear(self, i, o, r):
        _count(self.pathname, "compute")          # counted with compute(): one residual evaluation
        r["alpha"] = P["CL0"] + P["CLa"] * o["alpha"] + P["CLde"] * i["de"] - i["CL_req"]

    def linearize(self, i, o, J):
        _count(self.pathname, "compute_partials")
        J["alpha", "alpha"] = P["CLa"]; J["alpha", "de"] = P["CLde"]; J["alpha", "CL_req"] = -1.0


def expected_connections(c5: str) -> set:
    """(source output, target input) pairs inside the "trim" group; c5 = name of component 5."""
    return {(f"trim.{c5}.alpha", "trim.pitch.alpha"), (f"trim.{c5}.alpha", "trim.aero.alpha"),
            (f"trim.{c5}.alpha", "trim.prop.alpha"), (f"trim.{c5}.alpha", "trim.liftreq.alpha"),
            ("trim.pitch.de", "trim.aero.de"), ("trim.pitch.de", f"trim.{c5}.de"),
            ("trim.aero.CD", "trim.prop.CD"), ("trim.prop.T", "trim.liftreq.T"),
            ("trim.liftreq.CL_req", f"trim.{c5}.CL_req")}


# run key -> (formulation, component-5 name)
FORM = {"nlbgs": ("explicit", "alphacl"), "nlbgs_aitken": ("explicit", "alphacl"), "newton": ("explicit", "alphacl"), "broyden_full": ("explicit", "alphacl"),
        "broyden": ("implicit", "liftbal"), "newton_implicit": ("implicit", "liftbal")}


def build(solver: str, recorder_file: Path | None = None, complex_step: bool = False) -> om.Problem:
    """The trim group with the requested nonlinear solver (keys of FORM)."""
    form, c5 = FORM[solver]
    prob = om.Problem(reports=False)
    g = prob.model.add_subsystem("trim", om.Group())
    g.add_subsystem("pitch", PitchBalance())
    g.add_subsystem("aero", Aero())
    g.add_subsystem("prop", Propulsion())
    g.add_subsystem("liftreq", LiftRequired())
    g.add_subsystem(c5, AlphaFromLift() if form == "explicit" else LiftBalance())
    g.connect(f"{c5}.alpha", ["pitch.alpha", "aero.alpha", "prop.alpha", "liftreq.alpha"])
    g.connect("pitch.de", ["aero.de", f"{c5}.de"])
    g.connect("aero.CD", "prop.CD")
    g.connect("prop.T", "liftreq.T")
    g.connect("liftreq.CL_req", f"{c5}.CL_req")

    if solver == "nlbgs":
        ns = g.nonlinear_solver = om.NonlinearBlockGS()
        ns.options.update(dict(maxiter=100, atol=1e-10, rtol=1e-12, iprint=0, err_on_non_converge=True))
        g.linear_solver = om.LinearBlockGS(maxiter=100, atol=1e-12, rtol=1e-12, iprint=-1)
    elif solver == "nlbgs_aitken":
        # same Gauss-Seidel sweep, but each update of the coupling variables is relaxed by a factor
        # theta_k computed from the last two residual vectors (Aitken's delta-squared idea, vector form);
        # theta starts at aitken_initial_factor and is clipped to [aitken_min_factor, aitken_max_factor].
        ns = g.nonlinear_solver = om.NonlinearBlockGS()
        ns.options.update(dict(maxiter=100, atol=1e-10, rtol=1e-12, iprint=0, err_on_non_converge=True,
                               use_aitken=True, aitken_initial_factor=1.0, aitken_min_factor=0.1, aitken_max_factor=1.5))
        g.linear_solver = om.LinearBlockGS(maxiter=100, atol=1e-12, rtol=1e-12, iprint=-1)
    elif solver in ("newton", "newton_implicit"):
        ns = g.nonlinear_solver = om.NewtonSolver(solve_subsystems=False)
        ns.options.update(dict(maxiter=20, atol=1e-10, rtol=1e-12, iprint=0, err_on_non_converge=True))
        g.linear_solver = om.DirectSolver()
    elif solver == "broyden":
        # intended use: Broyden iterates on the implicit STATE alpha; the explicit components are
        # re-run (a Gauss-Seidel sub-solve) each iteration. compute_jacobian=True: one exact Jacobian
        # of the state residual to start, then rank-1 Broyden updates (secant method in 1-D).
        ns = g.nonlinear_solver = om.BroydenSolver()
        ns.options.update(dict(maxiter=50, atol=1e-10, rtol=1e-12, iprint=0, err_on_non_converge=True,
                               compute_jacobian=True, max_jacobians=10, state_vars=[f"{c5}.alpha"]))
        g.linear_solver = om.DirectSolver()
    elif solver == "broyden_full":
        # diagnostic: full-model mode (no state_vars) on the all-explicit loop
        ns = g.nonlinear_solver = om.BroydenSolver()
        ns.options.update(dict(maxiter=50, atol=1e-10, rtol=1e-12, iprint=0, err_on_non_converge=True,
                               compute_jacobian=True, max_jacobians=10))
        g.linear_solver = om.DirectSolver()
    else:
        raise ValueError(solver)
    if recorder_file is not None:
        ns.recording_options["record_abs_error"] = True
        ns.recording_options["record_rel_error"] = True
        ns.add_recorder(om.SqliteRecorder(str(recorder_file)))
    prob.setup(force_alloc_complex=complex_step)   # complex step needs complex vectors allocated
    return prob


def independent_trim() -> tuple[float, float, float]:
    """Solve Cm = 0 and L + T sin(a) - W = 0 directly with scipy (no OpenMDAO)."""
    qS = P["qbar"] * P["S"]

    def f(z):
        a, de = z
        CL = P["CL0"] + P["CLa"] * a + P["CLde"] * de
        CD = P["CD0"] + P["K"] * CL ** 2
        T = qS * CD / math.cos(a)
        return [P["Cm0"] + P["Cma"] * a + P["Cmde"] * de, qS * CL + T * math.sin(a) - P["W"]]

    a, de = fsolve(f, [0.0, 0.0], xtol=1e-14)
    CL = P["CL0"] + P["CLa"] * a + P["CLde"] * de
    return a, de, qS * (P["CD0"] + P["K"] * CL ** 2) / math.cos(a)


def run(solver: str) -> dict:
    rec = OUT / f"cases_{solver}.sql"
    rec.unlink(missing_ok=True)
    prob = build(solver, rec)
    c5 = FORM[solver][1]
    prob.set_val(f"trim.{c5}.alpha", 0.0)                 # same initial guess for every solver
    prob.final_setup()
    CALLS.clear()
    prob.run_model()
    ns = prob.model.trim.nonlinear_solver
    lin = prob.model.trim.linear_solver
    prob.cleanup()
    cr = om.CaseReader(str(rec))
    hist = [(c.abs_err, c.rel_err) for c in (cr.get_case(n) for n in cr.list_cases(f"root.trim.nonlinear_solver", recurse=False, out_stream=None))]
    res = {
        "solver": type(ns).__name__ + (" + " + type(lin).__name__ if solver not in ("nlbgs", "nlbgs_aitken") else "") + {"nlbgs": " (no Aitken)", "nlbgs_aitken": " with Aitken acceleration", "broyden": " (implicit lift balance, state alpha)", "broyden_full": " (full-model mode, explicit loop)", "newton_implicit": " (implicit lift balance)"}.get(solver, ""),
        "atol": ns.options["atol"], "rtol": ns.options["rtol"], "maxiter": ns.options["maxiter"],
        "iterations": int(ns._iter_count),
        "alpha_deg": float(np.degrees(prob.get_val(f"trim.{c5}.alpha")[0])),
        "de_deg": float(np.degrees(prob.get_val("trim.pitch.de")[0])),
        "T_lbf": float(prob.get_val("trim.prop.T")[0]),
        "CL": float(prob.get_val("trim.aero.CL")[0]),
        "Cm": float(prob.get_val("trim.aero.Cm")[0]),
        "calls": {k.split(".")[-1]: v for k, v in sorted(CALLS.items())},
        "residual_history_abs": [h[0] for h in hist],
        "residual_history_rel": [h[1] for h in hist],
    }
    res["calls_total_compute"] = sum(v["compute"] for v in CALLS.values())
    res["calls_total_partials"] = sum(v["compute_partials"] for v in CALLS.values())
    res["prob"] = prob
    return res


def verify_n2(prob: om.Problem, solver_name: str, c5: str) -> list[tuple[str, bool, str]]:
    """Check the N2 data: variables, connections, the coupling cycle and its solver."""
    from openmdao.visualization.n2_viewer.n2_viewer import _get_viewer_data
    data = _get_viewer_data(prob)
    expected = expected_connections(c5)
    checks = []
    conns = {(c["src"], c["tgt"]) for c in data["connections_list"]}
    checks.append(("all 9 expected connections present, nothing else", conns == expected, f"{len(conns)} connections"))
    cyc = [c for c in data["connections_list"] if c.get("cycle_arrows")]
    feedback = {(c["src"], c["tgt"]) for c in data["connections_list"] if c["src"] == f"trim.{c5}.alpha"}
    want_fb = {e for e in expected if e[0] == f"trim.{c5}.alpha"}
    checks.append((f"feedback: alpha from component 5 ({c5}) back to components 1-4", feedback == want_fb, str(sorted(feedback))))
    checks.append(("N2 marks the connections that close a cycle", len(cyc) > 0, f"{len(cyc)} cycle-arrow connections"))

    def find(node, path):
        if not path:
            return node
        for ch in node.get("children", []):
            if ch["name"] == path[0]:
                return find(ch, path[1:])
        return None
    trim = find(data["tree"], ["trim"])
    comps = [c["name"] for c in trim.get("children", [])] if trim else []
    checks.append(("trim group holds the 5 components in run order", comps == ["pitch", "aero", "prop", "liftreq", c5], str(comps)))
    label = str(trim.get("nonlinear_solver", "")) if trim else ""
    checks.append(("solver shown on the trim group", solver_name.lower() in label.lower(), label))
    if c5 == "liftbal":
        node5 = find(trim, [c5])
        kind = f"{node5.get('subsystem_type', '')}/{node5.get('component_type', '')}"
        checks.append(("component 5 is implicit (alpha is a state)", "implicit" in kind.lower(), kind))
    io = {}
    for comp in comps:
        node = find(trim, [comp])
        io[comp] = sorted((v["name"], v["type"]) for v in node.get("children", []))
    expect_io = {
        "pitch": [("alpha", "input"), ("de", "output")],
        "aero": sorted([("alpha", "input"), ("de", "input"), ("CL", "output"), ("CD", "output"), ("Cm", "output")]),
        "prop": sorted([("CD", "input"), ("alpha", "input"), ("T", "output")]),
        "liftreq": sorted([("T", "input"), ("alpha", "input"), ("CL_req", "output")]),
        c5: sorted([("CL_req", "input"), ("de", "input"), ("alpha", "output")]),
    }
    checks.append(("each component's inputs and outputs as designed", io == expect_io, json.dumps(io)))
    import networkx as nx                       # cycle structure from the data graph itself
    G = nx.DiGraph()
    for src, tgt in expected:
        G.add_edge(src.split(".")[1], tgt.split(".")[1])
    sccs = [c for c in nx.strongly_connected_components(G) if len(c) > 1]
    checks.append(("exactly one coupling cycle, containing all 5 components", len(sccs) == 1 and len(sccs[0]) == 5,
                   str([sorted(c) for c in sccs])))
    return checks


MAIN = ("nlbgs", "nlbgs_aitken", "newton", "broyden")  # the four approaches, each with an N2 diagram
EXTRA = ("newton_implicit", "broyden_full")          # comparison runs: same physics, other formulation or mode
N2LABEL = {"nlbgs": "NLBGS", "nlbgs_aitken": "NLBGS", "newton": "Newton", "broyden": "Broyden"}

NOTES = {
    "nlbgs": ("Reading the counts: {sweeps} Gauss-Seidel sweeps, each running all 5 components once ({calls} compute calls). "
              "With use_apply_nonlinear off, OpenMDAO measures the NLBGS residual as the change in outputs between consecutive "
              "sweeps, so the first sweep has no residual and the table has one row fewer."),
    "nlbgs_aitken": ("Reading the counts: {sweeps} Gauss-Seidel sweeps ({calls} compute calls), no derivatives. Aitken changes only "
                     "how far each sweep's update is applied: the new coupling values are x_k + theta_k (x_GS - x_k), with theta_k "
                     "from the last two residuals. When the plain iteration contracts by a steady factor r, the ideal relaxation is "
                     "about 1/(1 - r), which removes most of the error a plain sweep leaves behind. It costs nothing extra: the "
                     "same component calls per sweep plus a few vector operations."),
    "newton": ("Reading the counts: row 0 is the residual of the initial guess; rows 1 onward follow each Newton step. "
               "{sweeps} model evaluations x 5 components = {calls} compute calls. compute_partials ran {it} times in each of the "
               "3 components with non-constant derivatives (pitch and alphacl declare constant partials once), and DirectSolver "
               "did one LU solve per Newton step."),
    "newton_implicit": ("Same Newton + DirectSolver on the implicit formulation: the residual history matches the explicit run, "
                        "as it should, because both formulations define the same root."),
    "broyden": ("Reading the counts: Broyden iterates on ONE state, alpha (the residual of the implicit lift balance). Each "
                "iteration takes a quasi-Newton step on alpha, then re-runs the explicit components to refresh de, CD, T and "
                "CL_req, which is why compute calls ({calls}) exceed 5 x iterations. Exact derivatives were computed only for "
                "the first Jacobian ({partials} compute_partials/linearize calls); every later step uses a rank-1 (secant) "
                "update. With one state this is the secant method, order about 1.6."),
    "broyden_full": ("Comparison, not recommended: Broyden in full-model mode (no state_vars) on the all-explicit loop. It "
                     "converges, but only after the residual grows to about 1e7 and two extra exact Jacobians are computed "
                     "({partials} compute_partials calls in all). Each Broyden iteration also re-runs the explicit components, "
                     "which overwrite the outputs Broyden just updated, so the rank-1 secant updates see changes the step did "
                     "not make. OpenMDAO's Broyden is meant for implicit states; the implicit lift-balance run is the correct use."),
}


def main() -> int:
    OUT.mkdir(exist_ok=True)
    a_ref, de_ref, T_ref = independent_trim()
    results = {s: run(s) for s in MAIN + EXTRA}
    ok = True
    report = ["# Coupled trim loop in OpenMDAO: Gauss-Seidel (with and without Aitken), Newton and Broyden", "",
              f"OpenMDAO {openmdao.__version__}. Flight condition: V = {P['V']} ft/s, rho = {P['rho']} slug/ft^3, "
              f"qbar = {P['qbar']:.3f} psf, W = {P['W']} lbf, S = {P['S']} ft^2 (F-16-like scale; surrogate aerodynamics).", "",
              f"Independent check (scipy fsolve on the two balance equations): alpha = {math.degrees(a_ref):.10f} deg, "
              f"de = {math.degrees(de_ref):.10f} deg, T = {T_ref:.6f} lbf.", "",
              "Two formulations of the same physics. **Explicit**: component 5 computes alpha = (CL_req - CL0 - CLde de)/CLa "
              "(used by Gauss-Seidel and Newton). **Implicit**: component 5 holds alpha as a state with residual "
              "R = CL0 + CLa alpha + CLde de - CL_req (used by Broyden, which needs a state; Newton is repeated on it for "
              "comparison). Same tolerances (atol 1e-10, rtol 1e-12) and the same initial guess alpha = 0 for every run.", ""]
    for s, r in results.items():
        prob = r.pop("prob")
        c5 = FORM[s][1]
        errs = {"alpha": abs(r["alpha_deg"] - math.degrees(a_ref)), "de": abs(r["de_deg"] - math.degrees(de_ref)),
                "T": abs(r["T_lbf"] - T_ref)}
        agree = errs["alpha"] < 1e-8 and errs["de"] < 1e-8 and errs["T"] < 1e-6
        checks = []
        n2file = None
        if s in MAIN:
            n2file = HERE / f"N2_trim_{s}.html"
            om.n2(prob, outfile=str(n2file), show_browser=False, title=f"Trim loop, {r['solver']}")
            checks = verify_n2(prob, N2LABEL[s], c5)
        ok &= agree and all(c[1] for c in checks)
        report += [f"## {r['solver']}" + ("" if s in MAIN else "  (comparison run)"), "",
                   "| quantity | value |", "|---|---|",
                   f"| alpha | {r['alpha_deg']:.10f} deg |", f"| elevator de | {r['de_deg']:.10f} deg |",
                   f"| thrust T | {r['T_lbf']:.6f} lbf |", f"| CL | {r['CL']:.10f} |", f"| Cm (should be 0) | {r['Cm']:.3e} |",
                   f"| tolerances | atol {r['atol']:g}, rtol {r['rtol']:g}, maxiter {r['maxiter']} |",
                   f"| iterations | {r['iterations']} |",
                   f"| compute() calls (all components; implicit residual evaluations included) | {r['calls_total_compute']} |",
                   f"| compute_partials() / linearize() calls | {r['calls_total_partials']} |",
                   f"| agreement with independent fsolve | alpha {errs['alpha']:.1e} deg, de {errs['de']:.1e} deg, T {errs['T']:.1e} lbf |", "",
                   "Calls per component: " + ", ".join(f"{k} {v['compute']}+{v['compute_partials']}" for k, v in r["calls"].items())
                   + " (compute + partials)", "",
                   "Residual history (absolute norm of the solver's residual per iteration):", "",
                   "| iter | abs residual | rel residual |", "|---|---|---|"]
        report += [f"| {k} | {a:.3e} | {b:.3e} |" for k, (a, b) in enumerate(zip(r["residual_history_abs"], r["residual_history_rel"]))]
        report += ["", NOTES[s].format(sweeps=r["calls_total_compute"] // 5, calls=r["calls_total_compute"], it=r["iterations"],
                                       partials=r["calls_total_partials"]), ""]
        if checks:
            report += [f"N2 diagram: `{n2file.name}`. Programmatic N2 checks:", ""]
            report += [f"- [{'PASS' if c[1] else 'FAIL'}] {c[0]} ({c[2]})" for c in checks]
            report += [""]
        r["n2_checks"] = [(c[0], bool(c[1])) for c in checks]
        r["agreement"] = errs
    worst = 0.0                                  # analytic partials vs complex step, both formulations
    for key in ("newton", "broyden"):
        pc = build(key, complex_step=True)
        pc.run_model()
        data = pc.check_partials(out_stream=None, compact_print=True, method="cs")
        worst = max([worst] + [float(np.max(v["rel error"].forward)) for comp in data.values() for v in comp.values()])
    report += [f"Analytic partial derivatives vs complex step (force_alloc_complex=True), both formulations: "
               f"worst relative error {worst:.1e}.", ""]
    ok &= worst < 1e-10
    a, b, c, d = results["nlbgs"], results["newton"], results["broyden"], results["nlbgs_aitken"]
    rates = np.array(a["residual_history_abs"][1:]) / np.array(a["residual_history_abs"][:-1])
    report += ["## Comparison", "",
               "| approach | iterations | compute calls | derivative calls | convergence |", "|---|---|---|---|---|",
               f"| Gauss-Seidel | {a['iterations']} | {a['calls_total_compute']} | 0 | linear, factor {np.median(rates):.3f} per iteration |",
               f"| Gauss-Seidel + Aitken | {d['iterations']} | {d['calls_total_compute']} | 0 | linear with adaptive relaxation; see history |",
               f"| Newton | {b['iterations']} | {b['calls_total_compute']} | {b['calls_total_partials']} | quadratic |",
               f"| Broyden (state alpha) | {c['iterations']} | {c['calls_total_compute']} | {c['calls_total_partials']} | superlinear (secant) |",
               "",
               "- **Gauss-Seidel** needs no derivatives and is cheapest per iteration. It converges at a fixed rate set by the loop "
               "gain (how strongly alpha feeds back through the elevator and thrust); it would slow as the gain nears 1 and diverge above it.",
               f"- **Aitken acceleration** keeps Gauss-Seidel's zero derivative cost and cut the iterations from {a['iterations']} "
               f"to {d['iterations']} here. It works best when the plain iteration contracts at a steady rate, as here; it can "
               "also rescue a Gauss-Seidel loop whose gain is near or above 1, which plain Gauss-Seidel cannot converge.",
               "- **Newton** uses an exact Jacobian every iteration (derivatives + one linear solve), so each iteration costs most, "
               "but it converges quadratically: the number of correct digits roughly doubles per step.",
               "- **Broyden** gets most of Newton's speed with almost none of its derivative cost: one exact Jacobian, then cheap "
               "rank-1 updates. Its catch, shown by the comparison run, is that in OpenMDAO it must iterate on implicit states; "
               "pointed at explicit outputs it fights the components that recompute them.",
               "- **All runs give the same trim**, agreeing with the independent fsolve to round-off (Broyden to its tolerance).",
               "- **Residuals are not on one scale.** Newton reports the norm of the whole group residual; Broyden only the "
               "residual of its state (the lift balance, in CL units); Gauss-Seidel the change in outputs between sweeps. Each "
               "met the same atol/rtol on its own measure, so compare iteration counts and convergence shape, not raw magnitudes.", ""]
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        fig, ax = plt.subplots(figsize=(7.5, 4.6))
        for s, lab, st in (("nlbgs", "Nonlinear Block Gauss-Seidel", "o-"), ("nlbgs_aitken", "Gauss-Seidel + Aitken", "s-"),
                           ("newton", "Newton + DirectSolver", "o-"),
                           ("broyden", "Broyden, state alpha (1 Jacobian + rank-1 updates)", "o-"),
                           ("broyden_full", "Broyden full-model mode (comparison, explicit loop)", "x:")):
            h = results[s]["residual_history_abs"]
            ax.semilogy(range(len(h)), h, st, label=lab)
        ax.axhline(1e-10, color="grey", ls="--", lw=0.8, label="atol 1e-10")
        ax.set_xlabel("iteration"); ax.set_ylabel("absolute residual norm"); ax.grid(True, which="both", alpha=0.3)
        ax.set_title("Trim loop: residual history"); ax.legend(fontsize=8)
        fig.tight_layout(); fig.savefig(OUT / "residual_history.png", dpi=130)
        report += ["![residual history](residual_history.png)", ""]
    except Exception as e:  # plotting is optional
        report += [f"(plot skipped: {e})", ""]
    report += [f"**Overall: {'ALL CHECKS PASS' if ok else 'SOME CHECKS FAIL'}**"]
    (OUT / "convergence_report.md").write_text("\n".join(report), encoding="utf-8")
    (OUT / "results.json").write_text(json.dumps(
        {k: {kk: vv for kk, vv in v.items()} for k, v in results.items()}, indent=1, default=float), encoding="utf-8")
    print("\n".join(report))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
