"""pyXDSM diagrams of the VITAL framework, milestones M0 to M5.

Renders six linked XDSM figures.  Read them in order:

    fig_0_overview       everything from NASA's files to the check against NASA
    fig_1_data_path      M2: NASA's DAVE-ML files become MATLAB functions
    fig_2_plant          M1 + M3: what happens inside ONE call of the plant
    fig_3_analyses       M4 + M5-A/B/X: trim, linearize, modes, simulate
    fig_4_nesc           M5-C: NASA's recorded flights over a rotating Earth
    fig_5_test_machinery M0: how the tests prove themselves
    fig_6_full_system    ALL of it on one page: M0 to M5, plus M6

How to read an XDSM (Lambe and Martins, 2012):
  * Each box is a computation (a function or a solver).  The number in the
    box label matches the numbered list in docs/FRAMEWORK_GUIDE.md.
  * Boxes sit on the diagonal.  A thick grey line carries DATA from one box
    to another; the label on it says WHAT is sent.
  * Data leaving a box goes along its ROW; data entering goes down its COLUMN.
    Lines above the diagonal flow "forward"; lines below it are FEEDBACK:
    a loop (for example the trim solver sending guesses back to the plant).
  * Arrows entering from the top are inputs from outside the framework;
    arrows leaving to the right are the results you get.
  * The thin black line (the "process line") shows the ORDER in which the
    boxes run, including the loops.

Box shape (computational character):
    rectangle         explicit function: inputs in, outputs out
    rounded + dashed  solver: iterates until something converges or ends
    stacked           (not used here)

Run from anywhere::

    python vital_xdsm.py

pyXDSM writes .tikz and .tex; the PDF needs ``pdflatex`` (MiKTeX or TeX Live)
and the PNG needs PyMuPDF or ``pdftoppm``.  Without them the TeX sources are
still written.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

OUTPUT_DIR = Path(__file__).resolve().parent


def _api():
    try:
        from pyxdsm.XDSM import FUNC, IFUNC, RIGHT, SOLVER, XDSM
    except ModuleNotFoundError:
        sys.exit("pyXDSM is not installed: run `pip install pyXDSM`")
    return XDSM, SOLVER, FUNC, IFUNC, RIGHT


def tt(text: str) -> str:
    """A code-style label (file or function name), safe for LaTeX."""
    return r"\texttt{" + text.replace("_", r"\_") + "}"


def tx(text: str) -> str:
    """A plain-words label, safe for LaTeX."""
    return r"\text{" + text.replace("_", r"\_").replace("%", r"\%") + "}"


# --------------------------------------------------------------------------
# Figure 0 - the whole framework, M0 (not drawn) to M5
# --------------------------------------------------------------------------
def fig_overview():
    XDSM, SOLVER, FUNC, IFUNC, RIGHT = _api()
    x = XDSM(use_sfmath=False)

    x.add_system("data", FUNC, (tx("1: NASA data files"), tt("data/nesc")))
    x.add_system("read", FUNC, (tx("2: DAVE-ML reader (M2)"), tt("+daveml")))
    x.add_system("mod", FUNC, (tx("3: Generated F-16 models"), tt("+models/+f16")))
    x.add_system("phys", FUNC, (tx("4: Physics blocks (M1, M3)"), tt("frames geo env airdata loads mass eom")))
    x.add_system("cfg", FUNC, (tx("5: Aircraft struct AC (M3)"), tt("+aircraft/+f16/config")))
    x.add_system("plant", FUNC, (tx("6: Plant (M3)"), tt("+plant/derivatives")))
    x.add_system("trim", SOLVER, (tx("7: Trim (M4)"), tt("+trim/solve")))
    x.add_system("lin", FUNC, (tx("8: Linearize + modes (M5-A)"), tt("+linear")))
    x.add_system("sim", SOLVER, (tx("9: Time simulation (M5-B)"), tt("+sim/run")))
    x.add_system("rot", FUNC, (tx("10: Rotating Earth (M5-C)"), tt("derivativesRotating")))
    x.add_system("ver", FUNC, (tx("11: Check against NASA (M5-C)"), tt("+nesc/compare")))

    x.add_input("cfg", (tx("CG position,"), tx("gravity")))
    x.add_input("trim", (tx("speed V, altitude h,"), tx("climb angle")))
    x.add_input("sim", (tx("input du(t),"), tx("controller")))
    x.add_input("rot", tx("case id (1 to 16)"))
    x.add_input("ver", tx("NASA reference CSVs"))

    x.connect("data", "read", tx(".dml files"))
    x.connect("read", "mod", tx("generated MATLAB code"))
    x.connect("mod", "cfg", (tx("mass, inertia,"), tx("CG offset")))
    x.connect("mod", "plant", (tx("aero + engine"), tx("tables")))
    x.connect("phys", "plant", (tx("air, gravity,"), tx("force sum, EOM")))
    x.connect("cfg", "plant", (tx("AC: mass, J,"), tx("CG, limits")))
    x.connect("plant", "trim", tx("accelerations"))
    x.connect("trim", "plant", (tx("guess of"), tx("alpha, elevator, throttle")))
    x.connect("trim", "lin", (tx("trim point"), tx("(only if OK)")))
    x.connect("plant", "lin", tx("xdot"))
    x.connect("lin", "plant", tx("perturbed x, u"))
    x.connect("trim", "sim", tx("start state x0, u0"))
    x.connect("plant", "sim", tx("xdot, y"))
    x.connect("sim", "plant", tx("x(t), u(t)"))
    x.connect("phys", "rot", (tx("gravitation,"), tx("atmosphere")))
    x.connect("cfg", "rot", tx("AC or vehicle"))
    x.connect("mod", "rot", tx("NASA control law"))
    x.connect("sim", "rot", tx("x(t), u"))
    x.connect("rot", "sim", tx("xdot, y"))
    x.connect("rot", "ver", tx("NESC-named histories"))

    x.add_output("trim", (tx("x*, u*"), tx("(steady flight)")), side=RIGHT)
    x.add_output("lin", (tx("A, B, modes:"), tx("wn, zeta, tau")), side=RIGHT)
    x.add_output("sim", (tx("x(t), logs,"), tx("stop reason")), side=RIGHT)
    x.add_output("ver", (tx("PASS / FAIL"), tx("per signal")), side=RIGHT)

    x.add_process(["data", "read", "mod", "cfg", "plant", "trim"], arrow=True)
    x.add_process(["trim", "plant", "trim"], arrow=True)
    x.add_process(["trim", "lin", "plant", "lin"], arrow=True)
    x.add_process(["lin", "sim", "plant", "sim"], arrow=True)
    x.add_process(["sim", "rot", "sim", "ver"], arrow=True)
    return x


# --------------------------------------------------------------------------
# Figure 1 - M2: NASA files become MATLAB functions
# --------------------------------------------------------------------------
def fig_data_path():
    XDSM, SOLVER, FUNC, IFUNC, RIGHT = _api()
    x = XDSM(use_sfmath=False)

    x.add_system("files", FUNC, (tx("1: NASA DAVE-ML files"), tt("F16_aero/prop/inertia/control/gnc.dml")))
    x.add_system("read", FUNC, (tx("2: read"), tt("+daveml/read")))
    x.add_system("comp", FUNC, (tx("3: compile"), tt("+daveml/compile")))
    x.add_system("look", FUNC, (tx("4: lookup, piecewise"), tt("+daveml/lookup, piecewise")))
    x.add_system("gen", FUNC, (tx("5: Generated models"), tt("+models/+f16/aero, prop, ...")))
    x.add_system("chk", FUNC, (tx("6: Replay NASA check data"), tt("+daveml/runCheckData")))

    x.add_input("gen", (tx("alpha, beta, speed,"), tx("p q r, el ail rdr")))
    x.add_output("gen", (tx("CX CY CZ"), tx("Cl Cm Cn")), side=RIGHT)
    x.add_output("chk", (tx("pass / fail"), tx("25 of 25 shots")), side=RIGHT)

    x.connect("files", "read", tx("XML text"))
    x.connect("read", "comp", (tx("model struct:"), tx("variables, tables, equations")))
    x.connect("read", "chk", tx("NASA check shots"))
    x.connect("comp", "gen", (tx("writes function"), tt("out = f(in)")))
    x.connect("look", "gen", (tx("interpolation"), tx("used at run time")))
    x.connect("gen", "chk", tx("model outputs"))

    x.add_process(["files", "read", "comp", "gen", "chk"], arrow=True)
    x.add_process(["look", "gen"], arrow=True)
    return x


# --------------------------------------------------------------------------
# Figure 2 - inside ONE call of the plant
# --------------------------------------------------------------------------
def fig_plant():
    XDSM, SOLVER, FUNC, IFUNC, RIGHT = _api()
    x = XDSM(use_sfmath=False)

    x.add_system("split", FUNC, (tx("1: Unpack the state"), tt("quat2dcm")))
    x.add_system("atm", FUNC, (tx("2: Atmosphere"), tt("atmosphereUS76")))
    x.add_system("air", FUNC, (tx("3: Air data"), tt("airData")))
    x.add_system("loads", FUNC, (tx("4: F-16 loads"), tt("+aircraft/+f16/loads")))
    x.add_system("sum", FUNC, (tx("5: Sum at the CG + gravity"), tt("sumLoadsAtCG")))
    x.add_system("eom", FUNC, (tx("6: Rigid-body motion"), tt("rigidBodyDerivs")))

    x.add_input("split", (tx("x: 13 states"), tx("v_b, w_b, q, p_n")))
    x.add_input("atm", tx("temperature offset"))
    x.add_input("air", tx("wind (NED)"))
    x.add_input("loads", (tx("u: elevator, aileron,"), tx("rudder, throttle")))
    x.add_input("sum", (tx("AC: CG, mass"), tx("gravity g")))
    x.add_input("eom", tx("AC: mass, inertia J"))

    x.connect("split", "atm", tx("height h = -p_N(3)"))
    x.connect("split", "air", (tx("v_b, w_b,"), tx("C_bn")))
    x.connect("atm", "air", tx("density, sound speed"))
    x.connect("air", "loads", (tx("V, alpha, beta,"), tx("q-bar, p q r")))
    x.connect("atm", "loads", tx("Mach, h"))
    x.connect("loads", "sum", (tx("F, M about the"), tx("reference point")))
    x.connect("split", "sum", tx("C_bn (gravity)"))
    x.connect("sum", "eom", tx("F_b, M_cg"))
    x.connect("split", "eom", tx("v, w, q"))

    x.add_output("eom", (tx("xdot (13)"), tx("the answer")), side=RIGHT)
    x.add_output("loads", (tx("y: forces,"), tx("coefficients")), side=RIGHT)

    x.add_process(["split", "atm", "air", "loads", "sum", "eom"], arrow=True)
    return x


# --------------------------------------------------------------------------
# Figure 3 - trim, linearize, modes, simulate: the analyses around the plant
# --------------------------------------------------------------------------
def fig_analyses():
    XDSM, SOLVER, FUNC, IFUNC, RIGHT = _api()
    x = XDSM(use_sfmath=False)

    x.add_system("plant", FUNC, (tx("1: Plant"), tt("derivatives")))
    x.add_system("trim", SOLVER, (tx("2: Trim solver (M4)"), tt("+trim/solve")))
    x.add_system("lin", FUNC, (tx("3: Linearize (M5-A)"), tt("+linear/linearize")))
    x.add_system("jac", IFUNC, (tx("4: Jacobian step study"), tt("+linear/jacobian")))
    x.add_system("modes", FUNC, (tx("5: Flight modes"), tt("+linear/modes")))
    x.add_system("sim", SOLVER, (tx("6: Time simulation (M5-B)"), tt("+sim/run")))
    x.add_system("ctl", FUNC, (tx("7: Controller slot"), tt("+sim/sampleController")))
    x.add_system("xchk", FUNC, (tx("8: Linear vs nonlinear (M5-X)"), tt("+linear/response")))

    x.add_input("trim", (tx("V, h, gamma,"), tx("CG, g")))
    x.add_input("sim", (tx("input du(t), dt,"), tx("T_final, guards")))
    x.add_input("ctl", tx("controller (M7)"))

    x.connect("trim", "plant", (tx("guess"), tx("alpha, de, thr")))
    x.connect("plant", "trim", tx("residuals"))
    x.connect("trim", "lin", (tx("x0, u0"), tx("(status OK)")))
    x.connect("lin", "jac", tx("f, z0, steps"))
    x.connect("jac", "plant", tx("z +/- h"))
    x.connect("plant", "jac", tx("f(z +/- h)"))
    x.connect("jac", "lin", (tx("derivatives,"), tx("column status")))
    x.connect("lin", "modes", tx("A (8 states)"))
    x.connect("trim", "sim", tx("x0, u0"))
    x.connect("sim", "plant", tx("x(t), u(t)"))
    x.connect("plant", "sim", tx("xdot, y"))
    x.connect("sim", "ctl", tx("t, x, y"))
    x.connect("ctl", "sim", tx("u (held)"))
    x.connect("lin", "xchk", tx("A, B"))
    x.connect("sim", "xchk", tx("nonlinear response"))

    x.add_output("trim", (tx("x*, u*,"), tx("status")), side=RIGHT)
    x.add_output("modes", (tx("wn, zeta, tau,"), tx("participation")), side=RIGHT)
    x.add_output("sim", (tx("x(t), log,"), tx("stop reason")), side=RIGHT)
    x.add_output("xchk", (tx("agreement"), tx("vs amplitude")), side=RIGHT)

    x.add_process(["trim", "plant", "trim"], arrow=True)
    x.add_process(["trim", "lin", "jac", "plant", "jac", "lin", "modes"], arrow=True)
    x.add_process(["trim", "sim", "plant", "sim", "ctl", "sim"], arrow=True)
    x.add_process(["lin", "xchk"], arrow=True)
    return x


# --------------------------------------------------------------------------
# Figure 4 - M5-C: NASA's recorded flights
# --------------------------------------------------------------------------
def fig_nesc():
    XDSM, SOLVER, FUNC, IFUNC, RIGHT = _api()
    x = XDSM(use_sfmath=False)

    x.add_system("case", FUNC, (tx("1: Case definition"), tt("+nesc/caseDef")))
    x.add_system("veh", FUNC, (tx("2: Vehicle"), tt("+nesc/vehicle, f16 config")))
    x.add_system("trim", FUNC, (tx("3: F-16 trim"), tt("+nesc/f16Trim")))
    x.add_system("ctl", FUNC, (tx("4: NASA control law"), tt("+nesc/f16Controller")))
    x.add_system("plant", FUNC, (tx("5: Rotating-Earth plant"), tt("derivativesRotating")))
    x.add_system("sim", SOLVER, (tx("6: Time simulation"), tt("+sim/run")))
    x.add_system("sig", FUNC, (tx("7: NESC signals"), tt("+nesc/runCase")))
    x.add_system("cmp", FUNC, (tx("8: Compare with NASA"), tt("+nesc/compare")))

    x.add_input("case", tx("case id: 1 to 16"))
    x.add_input("cmp", (tx("NASA reference CSVs"), tx("(simulators 1 to 6)")))

    x.connect("case", "veh", (tx("vehicle id,"), tx("overrides")))
    x.connect("case", "trim", (tx("start: lat, lon,"), tx("h, V (F-16)")))
    x.connect("veh", "plant", tx("AC"))
    x.connect("trim", "ctl", (tx("trim controls,"), tx("reference states")))
    x.connect("trim", "sim", tx("start state x0"))
    x.connect("case", "sim", tx("dt, duration"))
    x.connect("ctl", "plant", (tx("commands become u"), tx("at each stage")))
    x.connect("sim", "plant", tx("x(t), u"))
    x.connect("plant", "sim", tx("xdot, y"))
    x.connect("sim", "sig", tx("time histories (SI)"))
    x.connect("sig", "cmp", (tx("NASA names"), tx("and units")))
    x.connect("case", "cmp", (tx("bands: floor,"), tx("k, spread")))

    x.add_output("sig", tx("NESC-named time series"), side=RIGHT)
    x.add_output("cmp", (tx("PASS / FAIL and"), tx("excess per signal")), side=RIGHT)

    x.add_process(["case", "veh", "trim", "ctl", "sim", "plant", "sim", "sig", "cmp"], arrow=True)
    return x


# --------------------------------------------------------------------------
# Figure 5 - M0: how the tests prove themselves
# --------------------------------------------------------------------------
def fig_test_machinery():
    XDSM, SOLVER, FUNC, IFUNC, RIGHT = _api()
    x = XDSM(use_sfmath=False)

    x.add_system("tests", FUNC, (tx("1: Test files"), tt("tests/M0 ... M6")))
    x.add_system("run", FUNC, (tx("2: Run the gate"), tt("run_vital_tests")))
    x.add_system("cls", FUNC, (tx("3: Classify"), tt("+test/classifyResults")))
    x.add_system("sab", SOLVER, (tx("4: Plant bugs, one by one"), tt("run_sabotage")))
    x.add_system("child", FUNC, (tx("5: Fresh MATLAB on a copy"), tt("+test/runSabotageCase")))
    x.add_system("hash", FUNC, (tx("6: Tree unchanged?"), tt("+test/treeHash")))
    x.add_system("docs", FUNC, (tx("7: Document checks"), tt("tSpecDocs, checkCatalogue")))

    x.add_input("sab", (tx("sabotages.json:"), tx("file, pattern, targets")))
    x.add_input("docs", (tx("FAILURE_CATALOGUE.md,"), tx("MANIFEST.json")))

    x.connect("tests", "run", tx("test classes"))
    x.connect("run", "cls", (tx("results +"), tx("diagnostics")))
    x.connect("tests", "sab", tx("target test names"))
    x.connect("sab", "child", (tx("mutated copy,"), tx("target tests")))
    x.connect("child", "sab", tx("did a test fail?"))
    x.connect("sab", "hash", tx("real tree"))
    x.connect("hash", "sab", tx("hash before = after"))
    x.connect("docs", "tests", tx("checks the docs"))

    x.add_output("cls", (tx("PASS, RED, VACUOUS,"), tx("REGRESSION, gateOK")), side=RIGHT)
    x.add_output("sab", (tx("DETECTED /"), tx("NOT DETECTED")), side=RIGHT)

    x.add_process(["tests", "run", "cls"], arrow=True)
    x.add_process(["tests", "sab", "child", "sab", "hash", "sab"], arrow=True)
    return x


# --------------------------------------------------------------------------
# Figure 6 - the FULL system on one page: M0 to M5, plus M6 (built)
# --------------------------------------------------------------------------
def fig_full_system():
    XDSM, SOLVER, FUNC, IFUNC, RIGHT = _api()
    x = XDSM(use_sfmath=False)

    x.add_system("data", FUNC, (tx("1: NASA data (read-only)"), tt("data/, MANIFEST.json")))
    x.add_system("read", FUNC, (tx("2: DAVE-ML reader (M2)"), tt("+daveml")))
    x.add_system("mod", FUNC, (tx("3: Generated models (M2, M5-C)"), tt("+models: f16, nesc")))
    x.add_system("found", FUNC, (tx("4: Foundations (M1)"), tt("units frames geo env airdata loads mass")))
    x.add_system("cfg", FUNC, (tx("5: Aircraft AC + loads (M3)"), tt("+aircraft/+f16")))
    x.add_system("plant", FUNC, (tx("6: Plant (M3)"), tt("+plant/derivatives, +eom")))
    x.add_system("trim", SOLVER, (tx("7: Trim, loads report (M4)"), tt("+trim/solve")))
    x.add_system("lin", IFUNC, (tx("8: Linearize (M5-A)"), tt("+linear/linearize, jacobian")))
    x.add_system("modes", FUNC, (tx("9: Flight modes (M5-A)"), tt("+linear/modes")))
    x.add_system("sim", SOLVER, (tx("10: Time simulation (M5-B)"), tt("+sim/run")))
    x.add_system("ctl", FUNC, (tx("11: Controller slot (M5-B)"), tt("+sim/sampleController")))
    x.add_system("rot", FUNC, (tx("12: Rotating-Earth plant (M5-C)"), tt("derivativesRotating, +eom")))
    x.add_system("nesc", FUNC, (tx("13: NESC case runner (M5-C)"), tt("+nesc: caseDef f16Trim runCase")))
    x.add_system("cmp", FUNC, (tx("14: Compare with NASA (M5-C)"), tt("+nesc/compare, envelopeCheck")))
    x.add_system("fq", FUNC, (tx("15: MIL-F-8785C grading (M6)"), tt("+fq/assess")))
    x.add_system("test", SOLVER, (tx("16: Tests and sabotage (M0)"), tt("run_vital_tests, run_sabotage")))

    x.add_input("cfg", (tx("CG % MAC, gravity g,"), tx("aero multipliers")))
    x.add_input("trim", (tx("speed V, altitude h,"), tx("climb angle")))
    x.add_input("sim", (tx("input du(t), dt,"), tx("T_final, guards")))
    x.add_input("ctl", tx("controller (M7)"))
    x.add_input("nesc", (tx("case id 1 to 16,"), tt("NESC_CASE_MATRIX.json")))
    x.add_input("fq", (tx("condition grid,"), tx("95 rule records")))
    x.add_input("test", (tx("tests/M0 to M6,"), tt("sabotages.json")))

    x.connect("data", "read", tx(".dml files"))
    x.connect("read", "mod", tx("generated MATLAB code"))
    x.connect("mod", "cfg", (tx("mass, inertia,"), tx("CG offset")))
    x.connect("mod", "plant", (tx("aero, engine"), tx("tables")))
    x.connect("found", "plant", (tx("air, gravity,"), tx("force sum")))
    x.connect("cfg", "plant", (tx("AC: mass, J,"), tx("CG, limits")))
    x.connect("plant", "trim", tx("accelerations"))
    x.connect("trim", "plant", tx("alpha, de, thr guess"))
    x.connect("trim", "lin", (tx("trim point"), tx("(only if OK)")))
    x.connect("plant", "lin", tx("xdot"))
    x.connect("lin", "plant", tx("perturbed x, u"))
    x.connect("lin", "modes", tx("A (8 states)"))
    x.connect("trim", "sim", tx("start x0, u0"))
    x.connect("plant", "sim", tx("xdot, y"))
    x.connect("sim", "plant", tx("x(t), u(t)"))
    x.connect("sim", "ctl", tx("t, x, y"))
    x.connect("ctl", "sim", tx("u (held)"))
    x.connect("found", "rot", (tx("gravitation,"), tx("atmosphere")))
    x.connect("cfg", "rot", tx("AC"))
    x.connect("mod", "nesc", (tx("control law,"), tx("sphere, brick")))
    x.connect("nesc", "sim", (tx("start x0,"), tx("dt, duration")))
    x.connect("nesc", "rot", (tx("vehicle,"), tx("environment")))
    x.connect("sim", "rot", tx("x(t), u"))
    x.connect("rot", "sim", tx("xdot, y"))
    x.connect("sim", "nesc", tx("time histories"))
    x.connect("nesc", "cmp", tx("NESC-named signals"))
    x.connect("data", "cmp", tx("NASA reference CSVs"))
    x.connect("trim", "fq", tx("trim per point"))
    x.connect("modes", "fq", (tx("wn, zeta, tau,"), tx("n/alpha")))
    x.connect("cfg", "fq", tx("mutated aircraft"))
    x.connect("data", "test", tx("file hashes"))
    x.connect("read", "test", tx("NASA check shots"))
    x.connect("plant", "test", tx("closed forms"))
    x.connect("trim", "test", tx("NASA trim table"))
    x.connect("lin", "test", tx("vs nonlinear sim"))
    x.connect("sim", "test", tx("order, guards"))
    x.connect("cmp", "test", tx("NASA bands"))
    x.connect("fq", "test", tx("rule bounds"))

    x.add_output("trim", (tx("x*, u*, status"), tx("(steady flight)")), side=RIGHT)
    x.add_output("modes", (tx("short period, phugoid,"), tx("Dutch roll, roll, spiral")), side=RIGHT)
    x.add_output("sim", (tx("x(t), logs,"), tx("stop reason")), side=RIGHT)
    x.add_output("cmp", (tx("PASS / FAIL"), tx("per signal")), side=RIGHT)
    x.add_output("fq", (tx("Level and margin"), tx("per rule")), side=RIGHT)
    x.add_output("test", (tx("gateOK, DETECTED"), tx("or NOT DETECTED")), side=RIGHT)

    x.add_process(["data", "read", "mod", "cfg", "plant", "trim"], arrow=True)
    x.add_process(["trim", "plant", "trim"], arrow=True)
    x.add_process(["trim", "lin", "plant", "lin", "modes"], arrow=True)
    x.add_process(["trim", "sim", "plant", "sim", "ctl", "sim"], arrow=True)
    x.add_process(["sim", "nesc", "rot", "sim", "nesc", "cmp"], arrow=True)
    x.add_process(["modes", "fq", "test"], arrow=True)
    return x


DIAGRAMS = [
    ("fig_0_overview", fig_overview),
    ("fig_1_data_path", fig_data_path),
    ("fig_2_plant", fig_plant),
    ("fig_3_analyses", fig_analyses),
    ("fig_4_nesc", fig_nesc),
    ("fig_5_test_machinery", fig_test_machinery),
    ("fig_6_full_system", fig_full_system),
]


def _render_pdf(tex: Path):
    if shutil.which("pdflatex") is None:
        return None
    r = subprocess.run(["pdflatex", "-halt-on-error", "-interaction=nonstopmode", tex.name],
                       cwd=tex.parent, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  pdflatex FAILED for {tex.name}", file=sys.stderr)
        for line in r.stdout.splitlines():
            if line.startswith("!") or line.startswith("l."):
                print("   ", line, file=sys.stderr)
        return None
    for ext in (".aux", ".log"):
        tex.with_suffix(ext).unlink(missing_ok=True)
    return tex.with_suffix(".pdf")


def _render_png(pdf: Path, dpi: int = 200):
    try:
        import pymupdf
    except ModuleNotFoundError:
        try:
            import fitz as pymupdf
        except ModuleNotFoundError:
            return None
    png = pdf.with_suffix(".png")
    with pymupdf.open(pdf) as doc:
        doc.load_page(0).get_pixmap(dpi=dpi).save(png)
    return png


def main() -> int:
    import os
    os.chdir(OUTPUT_DIR)          # pyXDSM writes the \input path as given: keep it relative
    bad = 0
    for name, builder in DIAGRAMS:
        print(name)
        x = builder()
        x.write(name, build=False, cleanup=True, quiet=True)
        pdf = _render_pdf(OUTPUT_DIR / f"{name}.tex")
        if pdf is None:
            print("  TeX written; PDF not produced")
            bad += 1
            continue
        png = _render_png(pdf)
        print("  ", pdf.name, png.name if png else "(no PNG: install PyMuPDF)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
