"""VITAL's controller-plant nz LOOP (ADR-026) in OpenMDAO, solved four ways.

SciComp test bench, separate from the VITAL MATLAB code (VITAL is only used,
once, by fit_nz_loop.m to produce the numbers this file reads).

THE LOOP (VITAL: vital.linear.linearize with a Controller; test tests/M5/tClosedLoopR1.m)
    An nz-feedback controller sets the elevator from the measured load factor:
        de = de_ref + Knz (nz - nz0)                  Knz = 0.05 rad/g
    but the load factor itself depends on the elevator (the tail's own lift):
        nz = -(qbar S / W) CZ(de)                     CZ = CZ0 + CZde (de - de0)
    The controller needs nz and nz needs de: an ALGEBRAIC loop at one instant.
    VITAL solves it with one fixed-point step and then Newton (ADR-026/028).

THE NUMBERS (nz_loop_data.json, made by fit_nz_loop.m)
    F-16 frozen at VITAL's trim point (565.6854 ft/s, 10,013 ft, CG 25 % MAC):
    CZ0 and the elevator slope CZde from NASA's tables, qbar S / W, nz0, and
    VITAL's own answers (closed-loop gain Kref and the applied elevator for a
    +1 deg command step, solved on VITAL's full plant).
    NASA's CZ table is linear in the elevator, so the straight line is exact here.

THE COMPONENTS (one cycle of three)
    1 aero  : normal-force coefficient       de        -> CZ
    2 nzsens: load factor sensor              CZ        -> nz
    3 ctrl  : nz-feedback control law         nz, de_ref -> de      (feeds back into 1)
    de_ref (the pilot's command) comes from outside the loop (the "cmd" component).

THE SOLVERS (same four as trim_mda.py, same settings, same stopping rule)
    A  NonlinearBlockGS              Gauss-Seidel: run 1..3 in order, repeat
    B  NonlinearBlockGS + Aitken     same, with an automatic step-size boost
    C  NewtonSolver + DirectSolver   Newton
    D  BroydenSolver + DirectSolver  quasi-Newton on the implicit form (ctrl holds de as a state)
    plus NonlinearRunOnce, OpenMDAO's default: ONE pass, the loop is never closed.

THE GAIN SWEEP
    The loop gain is L = Knz * dnz/dde (0.0895 in VITAL's test). Gauss-Seidel
    contracts by |L| per sweep, so it slows as |L| -> 1 and diverges above it.
    The sweep changes Knz (only) and reruns all four solvers.

THE CHECKS
    * every run against the exact answer de - de0 = (de_ref - de0) / (1 - L);
    * the VITAL-gain runs against VITAL's own Kref and its full-plant solve;
    * the N2 data: inputs, outputs, connections, the one cycle, its solver;
    * the hand-written derivatives against complex step.

Run:  python nz_loop_mda.py       (writes into results/ next to this file)
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
import openmdao
import openmdao.api as om

HERE = Path(__file__).resolve().parent
OUT = HERE / "results"

# --------------------------------------------------------------------------
# INPUT NUMBERS: F-16 at VITAL's trim point, from nz_loop_data.json
# (written by fit_nz_loop.m in MATLAB). Nothing below hard-codes an aircraft number.
# --------------------------------------------------------------------------
_D = json.loads((HERE / "nz_loop_data.json").read_text(encoding="utf-8"))
P = dict(
    de0=math.radians(_D["trim"]["de0_deg"]),   # trim elevator, rad
    nz0=_D["trim"]["nz0_g"],                   # load factor at trim, g
    CZ0=_D["trim"]["CZ0"],                     # body z-force coefficient at trim
    CZde=_D["plant"]["CZde_per_rad"],          # its elevator slope, per rad (NASA table, linear in de)
    qSW=_D["plant"]["qbarS_over_W"],           # qbar S / W
    Knz=_D["controller"]["Knz_rad_per_g"],     # VITAL test gain, rad/g
)
GDE = -P["qSW"] * P["CZde"]                    # dnz/dde, g/rad (the plant half of the loop gain)
VITAL = _D["vital"]
DE_REF = P["de0"] + math.radians(VITAL["step_deg"])   # pilot command: trim + 1 deg

CALLS: dict[str, dict[str, int]] = {}


def _count(name: str, kind: str) -> None:
    CALLS.setdefault(name, {"compute": 0, "compute_partials": 0})[kind] += 1


# --------------------------------------------------------------------------
# THE 3 COMPONENTS (+ the implicit form of 3 for Broyden)
# --------------------------------------------------------------------------
class Aero(om.ExplicitComponent):
    """1: body z-force coefficient at the frozen trim state: CZ = CZ0 + CZde (de - de0)."""

    def setup(self):
        self.add_input("de", P["de0"], units="rad")
        self.add_output("CZ", P["CZ0"])
        self.declare_partials("CZ", "de", val=P["CZde"])              # constant partial

    def compute(self, i, o):
        _count(self.pathname, "compute")
        o["CZ"] = P["CZ0"] + P["CZde"] * (i["de"] - P["de0"])


class NzSensor(om.ExplicitComponent):
    """2: load factor nz = -(body z force)/W = -(qbar S / W) CZ (thrust has no body z part)."""

    def setup(self):
        self.add_input("CZ", P["CZ0"])
        self.add_output("nz", P["nz0"])
        self.declare_partials("nz", "CZ", val=-P["qSW"])

    def compute(self, i, o):
        _count(self.pathname, "compute")
        o["nz"] = -P["qSW"] * i["CZ"]


class Controller(om.ExplicitComponent):
    """3: nz-feedback control law: de = de_ref + Knz (nz - nz0)."""

    def initialize(self):
        self.options.declare("Knz", default=P["Knz"])

    def setup(self):
        self.add_input("nz", P["nz0"])
        self.add_input("de_ref", P["de0"], units="rad")
        self.add_output("de", P["de0"], units="rad")
        self.declare_partials("de", "nz", val=self.options["Knz"])
        self.declare_partials("de", "de_ref", val=1.0)

    def compute(self, i, o):
        _count(self.pathname, "compute")
        o["de"] = i["de_ref"] + self.options["Knz"] * (i["nz"] - P["nz0"])


class ControllerBalance(om.ImplicitComponent):
    """3 (implicit form): de is a STATE with residual R = de - de_ref - Knz (nz - nz0).
    Same law; Broyden's state_vars must be implicit states."""

    def initialize(self):
        self.options.declare("Knz", default=P["Knz"])

    def setup(self):
        self.add_input("nz", P["nz0"])
        self.add_input("de_ref", P["de0"], units="rad")
        self.add_output("de", P["de0"], units="rad")
        self.declare_partials("de", ["de", "nz", "de_ref"])

    def apply_nonlinear(self, i, o, r):
        _count(self.pathname, "compute")          # one residual evaluation
        r["de"] = o["de"] - i["de_ref"] - self.options["Knz"] * (i["nz"] - P["nz0"])

    def linearize(self, i, o, J):
        _count(self.pathname, "compute_partials")
        J["de", "de"] = 1.0; J["de", "nz"] = -self.options["Knz"]; J["de", "de_ref"] = -1.0


def expected_connections(c3: str) -> set:
    """(source, target) pairs; c3 = name of component 3."""
    return {(f"loop.{c3}.de", "loop.aero.de"), ("loop.aero.CZ", "loop.nzsens.CZ"),
            ("loop.nzsens.nz", f"loop.{c3}.nz"), ("cmd.de_ref", f"loop.{c3}.de_ref")}


# run key -> (formulation, component-3 name)
FORM = {"nlbgs": ("explicit", "ctrl"), "nlbgs_aitken": ("explicit", "ctrl"), "newton": ("explicit", "ctrl"),
        "broyden": ("implicit", "ctrlbal"), "runonce": ("explicit", "ctrl")}


def build(solver: str, Knz: float = P["Knz"], recorder_file: Path | None = None,
          complex_step: bool = False, strict: bool = True) -> om.Problem:
    """The loop group with the requested nonlinear solver (keys of FORM)."""
    form, c3 = FORM[solver]
    # MODEL SETUP: the pilot command outside, the loop group with the 3 components inside
    prob = om.Problem(reports=False)
    cmd = prob.model.add_subsystem("cmd", om.IndepVarComp())
    cmd.add_output("de_ref", DE_REF, units="rad")
    g = prob.model.add_subsystem("loop", om.Group())
    g.add_subsystem("aero", Aero())
    g.add_subsystem("nzsens", NzSensor())
    g.add_subsystem(c3, Controller(Knz=Knz) if form == "explicit" else ControllerBalance(Knz=Knz))
    # CONNECTIONS: the first line is the FEEDBACK (de back into the aerodynamics)
    g.connect(f"{c3}.de", "aero.de")
    g.connect("aero.CZ", "nzsens.CZ")
    g.connect("nzsens.nz", f"{c3}.nz")
    prob.model.connect("cmd.de_ref", f"loop.{c3}.de_ref")

    # SOLVER SETUP: identical to trim_mda.py (stop at residual 1e-10, or 1e-12 of its start)
    common = dict(atol=1e-10, rtol=1e-12, iprint=0, err_on_non_converge=strict)
    if solver == "nlbgs":
        # SOLVER A: Gauss-Seidel. Runs the 3 components in order, repeats. No derivatives.
        ns = g.nonlinear_solver = om.NonlinearBlockGS()
        ns.options.update(dict(maxiter=100, **common))
        g.linear_solver = om.LinearBlockGS(maxiter=100, atol=1e-12, rtol=1e-12, iprint=-1)
    elif solver == "nlbgs_aitken":
        # SOLVER B: Gauss-Seidel + Aitken (OpenMDAO's default factor limits 0.1 to 1.5)
        ns = g.nonlinear_solver = om.NonlinearBlockGS()
        ns.options.update(dict(maxiter=100, use_aitken=True, aitken_initial_factor=1.0,
                               aitken_min_factor=0.1, aitken_max_factor=1.5, **common))
        g.linear_solver = om.LinearBlockGS(maxiter=100, atol=1e-12, rtol=1e-12, iprint=-1)
    elif solver == "newton":
        # SOLVER C: Newton. Exact derivatives each step; DirectSolver solves J dx = -R exactly.
        ns = g.nonlinear_solver = om.NewtonSolver(solve_subsystems=False)
        ns.options.update(dict(maxiter=20, **common))
        g.linear_solver = om.DirectSolver()
    elif solver == "broyden":
        # SOLVER D: Broyden on the implicit state de. One exact Jacobian, then rank-1 updates.
        ns = g.nonlinear_solver = om.BroydenSolver()
        ns.options.update(dict(maxiter=50, compute_jacobian=True, max_jacobians=10,
                               state_vars=[f"{c3}.de"], **common))
        g.linear_solver = om.DirectSolver()
    elif solver == "runonce":
        # OpenMDAO's default: each component runs once, the loop is NOT closed
        ns = g.nonlinear_solver = om.NonlinearRunOnce()
    else:
        raise ValueError(solver)
    # RECORDER: saves the residual of every iteration
    if recorder_file is not None:
        ns.recording_options["record_abs_error"] = True
        ns.recording_options["record_rel_error"] = True
        ns.add_recorder(om.SqliteRecorder(str(recorder_file)))
    prob.setup(force_alloc_complex=complex_step)
    return prob


def exact_de(Knz: float) -> float:
    """CHECK: the loop is linear, so de - de0 = (de_ref - de0) / (1 - L), L = Knz dnz/dde."""
    return P["de0"] + (DE_REF - P["de0"]) / (1.0 - Knz * GDE)


def run(solver: str, Knz: float = P["Knz"], record: bool = True, strict: bool = True) -> dict:
    """RUN ONE SOLVER: build, start from de = de_ref (as VITAL does), run_model(), read back."""
    rec = None
    if record:
        rec = OUT / f"nz_cases_{solver}.sql"
        rec.unlink(missing_ok=True)
    prob = build(solver, Knz, rec, strict=strict)
    c3 = FORM[solver][1]
    prob.set_val(f"loop.{c3}.de", DE_REF)                 # initial guess: the command itself
    prob.final_setup()
    CALLS.clear()
    error = None
    with np.errstate(all="ignore"):
        try:
            prob.run_model()                              # <- this is where the solver closes the loop
        except om.AnalysisError as e:
            error = str(e).splitlines()[0]
    ns = prob.model.loop.nonlinear_solver
    de = float(prob.get_val(f"loop.{c3}.de")[0])
    res = {"solver": solver, "Knz": Knz, "loop_gain": Knz * GDE,
           "iterations": int(getattr(ns, "_iter_count", 1)),
           "de_deg": math.degrees(de), "nz": float(prob.get_val("loop.nzsens.nz")[0]),
           "error_vs_exact_deg": abs(math.degrees(de - exact_de(Knz))) if math.isfinite(de) else float("inf"),
           "calls_total_compute": sum(v["compute"] for v in CALLS.values()),
           "calls_total_partials": sum(v["compute_partials"] for v in CALLS.values()),
           "calls": {k.split(".")[-1]: v for k, v in sorted(CALLS.items())},
           "solver_error": error}
    res["converged"] = error is None and res["error_vs_exact_deg"] < 1e-8
    res["start_error_deg"] = abs(math.degrees(DE_REF - exact_de(Knz)))     # error of the initial guess de = de_ref
    res["diverged"] = not res["converged"] and not res["error_vs_exact_deg"] < res["start_error_deg"]
    if record:
        prob.cleanup()
        cr = om.CaseReader(str(rec))
        hist = [(c.abs_err, c.rel_err) for c in (cr.get_case(n) for n in
                cr.list_cases("root.loop.nonlinear_solver", recurse=False, out_stream=None))]
        res["residual_history_abs"] = [h[0] for h in hist]
        res["residual_history_rel"] = [h[1] for h in hist]
        res["prob"] = prob
    return res


def verify_n2(prob: om.Problem, solver_name: str, c3: str) -> list[tuple[str, bool, str]]:
    """CHECK THE N2: the same data the .html shows: connections, cycle, solver, variables."""
    from openmdao.visualization.n2_viewer.n2_viewer import _get_viewer_data
    data = _get_viewer_data(prob)
    expected = expected_connections(c3)
    checks = []
    conns = {(c["src"], c["tgt"]) for c in data["connections_list"]}
    checks.append(("all 4 expected connections present, nothing else", conns == expected, f"{len(conns)} connections"))
    fb = [c for c in data["connections_list"] if c["src"] == f"loop.{c3}.de"]
    checks.append((f"feedback: de from component 3 ({c3}) back to component 1 (aero)",
                   [(c["src"], c["tgt"]) for c in fb] == [(f"loop.{c3}.de", "loop.aero.de")], str([(c["src"], c["tgt"]) for c in fb])))
    cyc = [c for c in data["connections_list"] if c.get("cycle_arrows")]
    checks.append(("N2 marks the connections that close a cycle", len(cyc) > 0, f"{len(cyc)} cycle-arrow connections"))

    def find(node, path):
        if not path:
            return node
        for ch in node.get("children", []):
            if ch["name"] == path[0]:
                return find(ch, path[1:])
        return None
    loop = find(data["tree"], ["loop"])
    comps = [c["name"] for c in loop.get("children", [])] if loop else []
    checks.append(("loop group holds the 3 components in run order", comps == ["aero", "nzsens", c3], str(comps)))
    label = str(loop.get("nonlinear_solver", "")) if loop else ""
    checks.append(("solver shown on the loop group", solver_name.lower() in label.lower(), label))
    if c3 == "ctrlbal":
        node3 = find(loop, [c3])
        kind = f"{node3.get('subsystem_type', '')}/{node3.get('component_type', '')}"
        checks.append(("component 3 is implicit (de is a state)", "implicit" in kind.lower(), kind))
    io = {comp: sorted((v["name"], v["type"]) for v in find(loop, [comp]).get("children", [])) for comp in comps}
    expect_io = {"aero": [("CZ", "output"), ("de", "input")], "nzsens": [("CZ", "input"), ("nz", "output")],
                 c3: sorted([("nz", "input"), ("de_ref", "input"), ("de", "output")])}
    checks.append(("each component's inputs and outputs as designed", io == expect_io, json.dumps(io)))
    import networkx as nx
    G = nx.DiGraph()
    for src, tgt in expected:
        G.add_edge(src.split(".")[-2], tgt.split(".")[-2])
    sccs = [c for c in nx.strongly_connected_components(G) if len(c) > 1]
    checks.append(("exactly one coupling cycle, containing the 3 loop components (cmd outside it)",
                   len(sccs) == 1 and sccs[0] == {"aero", "nzsens", c3}, str([sorted(c) for c in sccs])))
    return checks


MAIN = ("nlbgs", "nlbgs_aitken", "newton", "broyden")
LABEL = {"nlbgs": "Gauss-Seidel", "nlbgs_aitken": "Gauss-Seidel + Aitken", "newton": "Newton + DirectSolver",
         "broyden": "Broyden (state de)", "runonce": "NonlinearRunOnce (default, loop not closed)"}
N2LABEL = {"nlbgs": "NLBGS", "nlbgs_aitken": "NLBGS", "newton": "Newton", "broyden": "Broyden"}
NOTES = {
    "nlbgs": ("Reading the counts: {it} sweeps x 3 components = {calls} compute calls, no derivatives. The residual is the change "
              "in outputs between sweeps, so the first sweep has no row. It shrinks by L = {L:.4f} per sweep: the error left "
              "after a sweep is L times the one before."),
    "nlbgs_aitken": ("Reading the counts: {it} sweeps ({calls} compute calls), no derivatives. After two sweeps Aitken has measured "
                     "the contraction L and stretches the update by 1/(1 - L); on a linear loop that lands on the answer."),
    "newton": ("Reading the counts: one Newton step solves a linear loop exactly. compute_partials ran 0 times because every "
               "partial in this model is a constant declared once in setup(); DirectSolver did one LU solve."),
    "broyden": ("Reading the counts: Broyden iterates on the ONE state de of the implicit controller. One exact Jacobian "
                "({partials} linearize call) makes its first step a Newton step, which is exact here. The extra compute calls "
                "are the Gauss-Seidel sub-solves that refresh CZ and nz around each Broyden update."),
}
SWEEP_L = (-3.0, -1.5, -0.9, -0.5, VITAL["loop_gain"], 0.5, 0.9, 0.99, 1.5, 3.0)


def main() -> int:
    OUT.mkdir(exist_ok=True)
    ok = True
    step = math.degrees(DE_REF - P["de0"])
    L0 = P["Knz"] * GDE
    rep = ["# VITAL's nz controller loop in OpenMDAO: Gauss-Seidel (with and without Aitken), Newton and Broyden", "",
           f"OpenMDAO {openmdao.__version__}. F-16 frozen at VITAL's trim point (565.6854 ft/s, 10,013 ft, CG 25 % MAC; "
           f"trim elevator {math.degrees(P['de0']):.6f} deg, nz0 = {P['nz0']:.8f} g). Numbers from nz_loop_data.json, made by fit_nz_loop.m.", "",
           "The loop (VITAL ADR-026; the fixture of tests/M5/tClosedLoopR1.m):", "",
           "```",
           "de_ref --> [3 ctrl: de = de_ref + Knz (nz - nz0)] --de--> [1 aero: CZ] --CZ--> [2 nzsens: nz] --+",
           "                ^                                                                             |",
           "                +------------------------------- nz ------------------------------------------+",
           "```", "",
           f"Plant: CZ = CZ0 + CZde (de - de0), CZ0 = {P['CZ0']:.8f}, CZde = {P['CZde']:.6f}/rad; nz = -(qbar S/W) CZ, "
           f"qbar S/W = {P['qSW']:.6f}. So dnz/dde = {GDE:.6f} g/rad. Controller gain Knz = {P['Knz']} rad/g. "
           f"**Loop gain L = Knz dnz/dde = {L0:.6f}.**", "",
           f"Test input: a +{step:g} deg elevator command, de_ref = {math.degrees(DE_REF):.6f} deg. Exact answer (the loop is "
           f"linear): de - de0 = {step:g} deg / (1 - L) = {math.degrees(exact_de(P['Knz']) - P['de0']):.10f} deg. "
           "Every solver starts from de = de_ref, as VITAL does. Same solver settings and stopping rule as trim_mda.py.", ""]

    # ---- the four solvers at VITAL's gain -----------------------------------------
    results = {s: run(s) for s in MAIN + ("runonce",)}
    for s in MAIN:
        r = results[s]
        prob = r.pop("prob")
        n2file = HERE / f"N2_nz_{s}.html"
        om.n2(prob, outfile=str(n2file), show_browser=False, title=f"nz controller loop, {LABEL[s]}")
        checks = verify_n2(prob, N2LABEL[s], FORM[s][1])
        ok &= r["converged"] and all(c[1] for c in checks)
        rep += [f"## {LABEL[s]}", "", "| quantity | value |", "|---|---|",
                f"| applied elevator de | {r['de_deg']:.10f} deg |",
                f"| step through the loop, de - de0 | {r['de_deg'] - math.degrees(P['de0']):.10f} deg |",
                f"| load factor nz | {r['nz']:.10f} g |",
                f"| iterations | {r['iterations']} |",
                f"| compute() calls (implicit residual evaluations included) | {r['calls_total_compute']} |",
                f"| compute_partials() / linearize() calls | {r['calls_total_partials']} |",
                f"| error vs exact answer | {r['error_vs_exact_deg']:.1e} deg |", "",
                "Residual history:", "", "| iter | abs residual | rel residual |", "|---|---|---|"]
        rep += [f"| {k} | {a:.3e} | {b:.3e} |" for k, (a, b) in enumerate(zip(r["residual_history_abs"], r["residual_history_rel"]))]
        rep += ["", NOTES[s].format(it=r["iterations"], calls=r["calls_total_compute"], partials=r["calls_total_partials"], L=L0)]
        rep += ["", f"N2 diagram: `{n2file.name}`. Programmatic N2 checks:", ""]
        rep += [f"- [{'PASS' if c[1] else 'FAIL'}] {c[0]} ({c[2]})" for c in checks] + [""]
        r["n2_checks"] = [(c[0], bool(c[1])) for c in checks]
    ro = results["runonce"]; ro.pop("prob")
    rep += ["## What happens with no solver (OpenMDAO's default NonlinearRunOnce)", "",
            f"One pass: de = {ro['de_deg']:.10f} deg, step {ro['de_deg'] - math.degrees(P['de0']):.6f} deg instead of "
            f"{math.degrees(exact_de(P['Knz']) - P['de0']):.6f} deg (error {ro['error_vs_exact_deg']:.2e} deg, no warning). "
            "This is the pre-ADR-026 answer in VITAL too: the controller saw nz at the old command, so the loop was "
            "never closed. Leaving a cycle on RunOnce is the classic OpenMDAO mistake.", ""]
    ok &= not ro["converged"]                             # it must NOT match: shows the loop matters

    # ---- partials vs complex step ---------------------------------------------------
    worst = 0.0
    for key in ("newton", "broyden"):
        pc = build(key, complex_step=True)
        pc.run_model()
        data = pc.check_partials(out_stream=None, compact_print=True, method="cs")
        worst = max([worst] + [float(np.max(v["rel error"].forward)) for comp in data.values() for v in comp.values()])
    rep += [f"Hand-written partial derivatives vs complex step, both formulations: worst relative error {worst:.1e}.", ""]
    ok &= worst < 1e-10

    # ---- CHECK AGAINST VITAL ----------------------------------------------------------
    kref = max(abs((results[s]["de_deg"] - math.degrees(P["de0"])) / step - VITAL["Kref_de_de"]) for s in MAIN)
    dfull = max(abs(results[s]["de_deg"] - VITAL["de_applied_deg"]) for s in MAIN)
    nfull = max(abs(results[s]["nz"] - VITAL["nz_applied_g"]) for s in MAIN)
    vital_ok = kref < 1e-8 and dfull < 1e-8 and nfull < 1e-8
    ok &= vital_ok
    a = results["nlbgs"]
    rep += ["## Comparison with VITAL", "", "| | SciComp (all four solvers) | VITAL | largest difference |", "|---|---|---|---|",
            f"| closed-loop gain du/du_ref | {(a['de_deg'] - math.degrees(P['de0'])) / step:.10f} | {VITAL['Kref_de_de']:.10f} "
            f"(vital.linear.linearize, Kref(de,de)) | {kref:.1e} |",
            f"| applied elevator for +1 deg | {a['de_deg']:.10f} deg | {VITAL['de_applied_deg']:.10f} deg (fzero on the full plant) | {dfull:.1e} deg |",
            f"| load factor | {a['nz']:.10f} g | {VITAL['nz_applied_g']:.10f} g | {nfull:.1e} g |", "",
            f"{'PASS' if vital_ok else 'FAIL'}: within 1e-8. VITAL's Kref is itself a finite-difference Jacobian of its Newton "
            "loop solve, so it agrees to about its step accuracy; the full-plant solve agrees to round-off because NASA's CZ "
            "is linear in the elevator.", ""]

    # ---- the four solvers vs loop gain ------------------------------------------------
    sweep = []
    for L in SWEEP_L:
        row = {"L": L}
        for s in MAIN:
            r = run(s, Knz=L / GDE, record=False, strict=False)
            row[s] = {k: r[k] for k in ("iterations", "converged", "diverged", "error_vs_exact_deg", "start_error_deg",
                                        "calls_total_compute", "calls_total_partials")}
        sweep.append(row)

    def cell(v):
        if v["converged"]:
            return f"{v['iterations']}"
        if v["diverged"]:
            return "diverged"
        return f"not conv. ({v['iterations']}), error {v['start_error_deg']:.2g} -> {v['error_vs_exact_deg']:.2g} deg"
    rep += ["## Loop-gain sweep (only Knz changes)", "",
            "Iterations to the stopping rule; 'not conv.' = stopped at maxiter (100 Gauss-Seidel, 20 Newton, 50 Broyden) "
            "still shrinking the error (shown: start -> end), 'diverged' = error ended larger than the starting guess's.", "",
            "| loop gain L | Knz (rad/g) | Gauss-Seidel | GS + Aitken | Newton | Broyden |", "|---|---|---|---|---|---|"]
    for row in sweep:
        tag = " (VITAL test)" if abs(row["L"] - L0) < 1e-12 else ""
        rep.append(f"| {row['L']:+.4f}{tag} | {row['L'] / GDE:+.4f} | " + " | ".join(cell(row[s]) for s in MAIN) + " |")
    # pre-registered: GS contracts (error shrinks) exactly when |L| < 1, diverges when |L| > 1, and reaches the
    # stop line within 100 sweeps when |L| <= 0.5 (0.5^100 ~ 1e-30; 0.9^100 ~ 3e-5 is not enough)
    gs_ok = all((not row["nlbgs"]["diverged"]) == (abs(row["L"]) < 1) for row in sweep) and         all(row["nlbgs"]["converged"] for row in sweep if abs(row["L"]) <= 0.5)
    nb_ok = all(row["newton"]["converged"] and row["broyden"]["converged"] for row in sweep)
    ok &= gs_ok and nb_ok
    rep += ["",
            f"- [{'PASS' if gs_ok else 'FAIL'}] Gauss-Seidel shrinks the error exactly when |L| < 1 and diverges when |L| > 1, "
            "and reaches the stop line within 100 sweeps for |L| <= 0.5, as predicted: each sweep multiplies the error by L.",
            f"- [{'PASS' if nb_ok else 'FAIL'}] Newton and Broyden converge at every gain: the loop is linear, so the first "
            "exact Jacobian gives the answer in one step, whatever L is (except L = 1 exactly, where no solution exists).", "",
            "- **Gauss-Seidel** contracts by |L| per sweep. At VITAL's gain (L = 0.09) that is fast; at L = 0.9 it needs "
            "about 230 sweeps for 1e-10; at L = 0.99 about 2,300; for |L| > 1 it diverges. Negative L (the sign of Knz "
            "flipped) makes it oscillate, same rule.",
            "- **Aitken** measures the contraction and stretches the step by about 1/(1 - L). Its OpenMDAO limits "
            "(0.1 to 1.5) decide when that is allowed: for negative L the ideal factor 1/(1 - L) is below 1 and inside the "
            "limits, so Aitken converges in a few sweeps even where Gauss-Seidel diverges (L = -1.5, -3). For L near +1 the "
            "ideal factor is large (10 at L = 0.9) and is clipped to 1.5, so Aitken only speeds the slow contraction a "
            "little; above +1 the ideal factor is negative, no factor in [0.1, 1.5] contracts, and it diverges like plain "
            "Gauss-Seidel.",
            "- **Newton / Broyden** cost derivatives but their iteration count does not depend on L. That is why VITAL "
            "closes this loop with Newton (ADR-028): it must work for any controller gain a user tries.", ""]

    # ---- PLOTS ----------------------------------------------------------------------
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        fig, ax = plt.subplots(figsize=(7.5, 4.6))
        for s, st in (("nlbgs", "o-"), ("nlbgs_aitken", "s-"), ("newton", "o-"), ("broyden", "^-")):
            h = results[s]["residual_history_abs"]
            ax.semilogy(range(len(h)), np.maximum(h, 1e-18), st, label=LABEL[s])
        ax.axhline(1e-10, color="grey", ls="--", lw=0.8, label="stop line: residual 1e-10 (or 1e-12 x its start)")
        ax.set_xlabel("iteration"); ax.set_ylabel("absolute residual norm"); ax.grid(True, which="both", alpha=0.3)
        ax.set_title(f"nz controller loop at VITAL's gain (L = {L0:.3f}): residual history"); ax.legend(fontsize=8)
        fig.tight_layout(); fig.savefig(OUT / "nz_residual_history.png", dpi=130); plt.close(fig)

        fig, ax = plt.subplots(figsize=(7.5, 4.6))
        Ls = [row["L"] for row in sweep]
        for s, mk in (("nlbgs", "o"), ("nlbgs_aitken", "s"), ("newton", "D"), ("broyden", "^")):
            its = [row[s]["iterations"] if row[s]["converged"] else np.nan for row in sweep]
            ax.plot(range(len(Ls)), its, mk + "-", label=LABEL[s])
            for k, row in enumerate(sweep):
                if not row[s]["converged"]:
                    ax.plot(k + (0.12 if s == "nlbgs_aitken" else -0.12), 160, "x", color=ax.lines[-1].get_color(), ms=9)
        ax.axhline(120, color="grey", lw=0.6, ls=":")
        ax.text(-0.3, 190, "x = did not converge (100 sweeps) or diverged", fontsize=8)
        ax.set_xticks(range(len(Ls))); ax.set_xticklabels([f"{L:+.2f}" for L in Ls])
        ax.set_xlabel("loop gain L = Knz dnz/dde"); ax.set_ylabel("iterations to converge"); ax.set_yscale("log"); ax.set_ylim(0.7, 300)
        ax.set_title("nz controller loop: iterations vs loop gain"); ax.grid(True, which="both", alpha=0.3); ax.legend(fontsize=8, loc="center left")
        fig.tight_layout(); fig.savefig(OUT / "nz_gain_sweep.png", dpi=130); plt.close(fig)
        rep += ["![residual history](nz_residual_history.png)", "", "![gain sweep](nz_gain_sweep.png)", ""]
    except Exception as e:
        rep += [f"(plots skipped: {e})", ""]

    rep += [f"**Overall: {'ALL CHECKS PASS' if ok else 'SOME CHECKS FAIL'}**"]
    (OUT / "nz_convergence_report.md").write_text("\n".join(rep), encoding="utf-8")
    (OUT / "nz_results.json").write_text(json.dumps({"vital_gain": results, "sweep": sweep}, indent=1, default=float), encoding="utf-8")
    print("\n".join(rep))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
