"""N2 diagram of VITAL's trim analysis (the structure of vital.trim.solve).

STRUCTURE ONLY. The trim itself runs in MATLAB (vital.trim.solve with lsqnonlin).
This script rebuilds its data flow as an OpenMDAO model whose components have the
right inputs and outputs but compute nothing, so the N2 shows how the trim is wired
and where the loop is. The model is never run.

Source of every box (all under C:\\VITAL\\+vital):
    solver      +trim/solve.m                    lsqnonlin over alpha, elevator, throttle
    buildstate  +trim/solve.m  build()           unknowns + condition -> state x, controls u
    atmosphere  +env/atmosphereUS76.m            US 1976 atmosphere at h = -x(13)
    airdata     +airdata/airData.m               V, alpha, beta, Mach, q-bar from x and wind
    aero        +models/+f16/aero.m              NASA DAVE-ML aerodynamic coefficients
    prop        +models/+f16/prop.m              NASA DAVE-ML thrust
    loads       +aircraft/+f16/loads.m           forces and moments about the BFRP
    sumcg       +loads/sumLoadsAtCG.m            move loads to the CG, add gravity
    rigidbody   +eom/rigidBodyDerivs.m           xdot from forces and moments
    residual    +trim/solve.m  residual()        [udot/g, wdot/g, qdot]
    status      +trim/solve.m                    OK / INFEASIBLE / NOT_CONVERGED / ...

The loop: residual -> solver -> buildstate -> ... -> residual. In VITAL the solver is
MATLAB's lsqnonlin, not an OpenMDAO solver, so the group solver shown in the N2 is the
OpenMDAO default and only the connections and the cycle are meaningful.

Run:  python vital_trim_n2.py        (writes N2_vital_trim_structure.html next to it)
"""
from __future__ import annotations

import sys
from pathlib import Path

import networkx as nx
import numpy as np
import openmdao.api as om

HERE = Path(__file__).resolve().parent
OUT = HERE / "N2_vital_trim_structure.html"


class Block(om.ExplicitComponent):
    """A component with declared inputs/outputs only (shape-correct, computes nothing)."""

    def initialize(self):
        self.options.declare("ins", types=dict)
        self.options.declare("outs", types=dict)

    def setup(self):
        for k, shp in self.options["ins"].items():
            self.add_input(k, np.zeros(shp))
        for k, shp in self.options["outs"].items():
            self.add_output(k, np.zeros(shp))

    def compute(self, i, o):  # structure only
        pass


# name -> (inputs, outputs), shapes as in the MATLAB code
BLOCKS = {
    "solver": ({"r": (3,)}, {"z": (3,)}),                      # z = [alpha, de, throttle]
    "buildstate": ({"z": (3,), "V": (1,), "h": (1,), "gamma": (1,), "psi": (1,), "wind_n": (3,)},
                   {"x": (13,), "u": (4,)}),
    "atmosphere": ({"x": (13,), "deltaT": (1,)}, {"rho": (1,), "a": (1,), "T": (1,)}),
    "airdata": ({"x": (13,), "wind_n": (3,), "a": (1,), "rho": (1,), "b": (1,), "cbar": (1,)},
                {"V_air": (1,), "alpha": (1,), "beta": (1,), "mach": (1,), "qbar": (1,),
                 "w_air": (3,), "C_bn": (3, 3)}),
    "aero": ({"V_air": (1,), "alpha": (1,), "beta": (1,), "w_air": (3,), "u": (4,)},
             {"coeff": (6,), "aero_oob": (1,)}),
    "prop": ({"u": (4,), "x": (13,), "mach": (1,)}, {"F_prop": (3,), "M_prop": (3,), "prop_oob": (1,)}),
    "loads": ({"coeff": (6,), "qbar": (1,), "S": (1,), "b": (1,), "cbar": (1,), "r_mrc": (3,),
               "F_prop": (3,), "M_prop": (3,)},
              {"F_R": (3, 2), "M_R": (3, 2)}),
    "sumcg": ({"F_R": (3, 2), "M_R": (3, 2), "r_cg": (3,), "mass": (1,), "C_bn": (3, 3), "g": (1,)},
              {"F_b": (3,), "M_cg": (3,)}),
    "rigidbody": ({"x": (13,), "F_b": (3,), "M_cg": (3,), "mass": (1,), "J": (3, 3)}, {"xdot": (13,)}),
    "residual": ({"xdot": (13,), "g": (1,)}, {"r": (3,)}),
    "status": ({"r": (3,), "z": (3,), "aero_oob": (1,), "prop_oob": (1,)}, {"status_code": (1,)}),
}

# (source, target): every connection of the trim, derived from the MATLAB code
CONNECTIONS = [
    ("cond.V", "buildstate.V"), ("cond.h", "buildstate.h"), ("cond.gamma", "buildstate.gamma"),
    ("cond.psi", "buildstate.psi"), ("cond.wind_n", "buildstate.wind_n"), ("cond.wind_n", "airdata.wind_n"),
    ("cond.deltaT", "atmosphere.deltaT"),
    ("ac.b", "airdata.b"), ("ac.cbar", "airdata.cbar"), ("ac.b", "loads.b"), ("ac.cbar", "loads.cbar"),
    ("ac.S", "loads.S"), ("ac.r_mrc", "loads.r_mrc"), ("ac.r_cg", "sumcg.r_cg"),
    ("ac.mass", "sumcg.mass"), ("ac.mass", "rigidbody.mass"), ("ac.J", "rigidbody.J"),
    ("cond.g", "sumcg.g"), ("cond.g", "residual.g"),
    ("solver.z", "buildstate.z"), ("solver.z", "status.z"),
    ("buildstate.x", "atmosphere.x"), ("buildstate.x", "airdata.x"), ("buildstate.x", "prop.x"),
    ("buildstate.x", "rigidbody.x"),
    ("buildstate.u", "aero.u"), ("buildstate.u", "prop.u"),
    ("atmosphere.a", "airdata.a"), ("atmosphere.rho", "airdata.rho"),
    ("airdata.V_air", "aero.V_air"), ("airdata.alpha", "aero.alpha"), ("airdata.beta", "aero.beta"),
    ("airdata.w_air", "aero.w_air"), ("airdata.mach", "prop.mach"), ("airdata.qbar", "loads.qbar"),
    ("airdata.C_bn", "sumcg.C_bn"),
    ("aero.coeff", "loads.coeff"), ("aero.aero_oob", "status.aero_oob"),
    ("prop.F_prop", "loads.F_prop"), ("prop.M_prop", "loads.M_prop"), ("prop.prop_oob", "status.prop_oob"),
    ("loads.F_R", "sumcg.F_R"), ("loads.M_R", "sumcg.M_R"),
    ("sumcg.F_b", "rigidbody.F_b"), ("sumcg.M_cg", "rigidbody.M_cg"),
    ("rigidbody.xdot", "residual.xdot"),
    ("residual.r", "solver.r"), ("residual.r", "status.r"),
]
ORDER = ["solver", "buildstate", "atmosphere", "airdata", "aero", "prop", "loads", "sumcg", "rigidbody",
         "residual", "status"]


def build() -> om.Problem:
    p = om.Problem(reports=False)
    cond = p.model.add_subsystem("cond", om.IndepVarComp())          # the trim condition + gravity
    for k, shp in (("V", 1), ("h", 1), ("gamma", 1), ("psi", 1), ("wind_n", 3), ("deltaT", 1), ("g", 1)):
        cond.add_output(k, np.zeros(shp))
    ac = p.model.add_subsystem("ac", om.IndepVarComp())              # the aircraft struct AC
    for k, shp in (("S", 1), ("b", 1), ("cbar", 1), ("mass", 1), ("J", (3, 3)), ("r_mrc", 3), ("r_cg", 3)):
        ac.add_output(k, np.zeros(shp))
    t = p.model.add_subsystem("trim", om.Group())
    for name in ORDER:
        ins, outs = BLOCKS[name]
        t.add_subsystem(name, Block(ins=ins, outs=outs))
    for src, tgt in CONNECTIONS:
        s0 = src if src.split(".")[0] in ("cond", "ac") else "trim." + src
        t0 = "trim." + tgt
        p.model.connect(s0, t0)
    p.setup()
    p.final_setup()
    return p


def verify(p: om.Problem) -> list[tuple[str, bool, str]]:
    from openmdao.visualization.n2_viewer.n2_viewer import _get_viewer_data
    data = _get_viewer_data(p)
    conns = {(c["src"], c["tgt"]) for c in data["connections_list"]}
    want = {((s if s.split(".")[0] in ("cond", "ac") else "trim." + s), "trim." + t) for s, t in CONNECTIONS}
    G = nx.DiGraph()
    for s, t in CONNECTIONS:
        a, b = s.split(".")[0], t.split(".")[0]
        if a not in ("cond", "ac"):
            G.add_edge(a, b)
    cycles = [sorted(c) for c in nx.strongly_connected_components(G) if len(c) > 1]
    expected = sorted(["solver", "buildstate", "atmosphere", "airdata", "aero", "prop", "loads", "sumcg",
                       "rigidbody", "residual"])
    return [
        ("all connections present, nothing else", conns == want, f"{len(conns)} connections"),
        ("exactly one coupling cycle: the trim loop", cycles == [expected], str(cycles)),
        ("status is outside the loop (it only reads results)", all("status" not in c for c in cycles), ""),
        ("cycle arrows marked in the N2", any(c.get("cycle_arrows") for c in data["connections_list"]), ""),
    ]


def main() -> int:
    p = build()
    om.n2(p, outfile=str(OUT), show_browser=False,
          title="VITAL trim analysis (structure of vital.trim.solve; not run)")
    ok = True
    for name, passed, info in verify(p):
        print(f"[{'PASS' if passed else 'FAIL'}] {name} {info}")
        ok &= passed
    print(f"wrote {OUT}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
