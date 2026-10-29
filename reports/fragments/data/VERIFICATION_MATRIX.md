# VERIFICATION_MATRIX fragment (agent data, 2026-10-27): D1 rows

| Claim | Evidence | Source | Test |
|---|---|---|---|
| Every variableDef, breakpointDef and table of the nine NASA DAVE-ML files (F16_aero/prop/inertia/control/gnc, brick and cannonball aero/inertia) is in the data objects with the file's values (exact), units and start-tag line | independent regex scan of the file text; 250 + 48 variables, 6 breakpoint sets, 21 tables | PUB | tests/M9/data/tDataInventory.m#everyEntryPresentWithFileValues |
| Every Parameter, Variable, Table, Breakpoint and axis origin of the F-16, brick and cannonball has units and a valid source (file, line, SHA-256) | validate() and a walk over all items | REG | #everyItemHasUnitsAndSource |
| 16 aero + 9 prop check cases carried with their staticShot lines; S, b, cbar = 300 ft2, 30 ft, 11.32 ft at the sref/bspan/cbar lines | F16_aero.dml, F16_prop.dml | PUB | #checkCasesCarriedWithLines, #geometryByName |
| Table.at = generated runtime code = stored datum at all 852 grid nodes | vital.models.f16.aero / prop | REG | tests/M9/data/tDataTables.m#everyBreakpointBitwise |
| Table.at = generated code bitwise at 10,000 aero + 10,000 prop random points (7,803 / 4,815 outside a range, clamped identically) | vital.models.f16.aero / prop | REG | #randomPointsBitwise |
| Lookup by name in any order = positional = generated code (CXT inputs el, alpha in deg; T_MIL inputs RMACH, ALT) | F16_aero.dml "Basic CX", F16_prop.dml T_MIL_fn | PUB / REG | #lookupByNameAnyOrder |
| Table.at = MATLAB griddedInterpolant inside the range: aero max 8.3e-17 abs (gate 1e-12); all 21 tables max 4.3e-16 of the table scale (gate 1e-12; the registered 1e-12 abs failed on the thrust tables at 2 ulp, documented) | MATLAB griddedInterpolant | INDEP | #griddedInterpolantIndep |
| NASA checkData through the data object: 16 aero shots (144 outputs), 9 prop shots (54 outputs), all within NASA's tolerance | F16_aero.dml, F16_prop.dml checkData | PUB | tests/M9/data/tDataCheckCases.m#aeroCheckData, #propCheckData |
| DaveModel.evaluate = the generated function of the same file, bitwise, for all nine files at 301 input sets each | vital.models.f16.*, vital.models.nesc.* | REG | #evaluateEqualsGeneratedCode |
| vital.AircraftModel.fromData(f16_data) = the frozen 0.9.1-CORE model = vital.aircraft.f16.model(), bitwise in xdot and y over the 1,100-state set (652 out of envelope) | 0.9.1-CORE builder from config() | REG | tests/M9/data/tDataModel.m#fromDataBitwiseOver1100States |
| Same axes, mass properties, Ref, Limits, Controls and components | 0.9.1-CORE builder | REG | #sameModelStructure |
| config() = data object field for field (two configurations) | the hand copy in config.m | PUB (F16 files) | #configEqualsData |
| Brick and cannonball S, b, cbar, mass, J, r_cg = vital.nesc.vehicle | generated code | REG | #nescBodiesEqualVehicle |
| README trim through fromData unchanged (1e-12) | config trim | REG | #readmeTrimUnchanged |
| .vital.json round trip bitwise (F-16 4,515 doubles, brick 172, cannonball 116); re-save byte-identical; -0, subnormals, realmax, NaN, Inf kept; loaded object works (checks, model) | bit comparison | REG | tests/M9/data/tDataJson.m |
| A hand-authored .vital.json loads; CL(5 deg) = 0.7 | linear table | ANALYTIC | tests/M9/data/tDataJson.m#handAuthoredFile |
| No units / no provenance / changed source file / file not in manifest are refused | error identifiers | REG | tests/M9/data/tDataValidate.m |
| data/ unchanged: the nine DAVE-ML files hash to data/MANIFEST.json | MANIFEST.json | PUB | tests/M9/data/tDataValidate.m#dataFolderUnchanged |
| Plant time per call of the model built from the data <= 1.05 x the 0.9.1-CORE model (measured 0.98; noise floor 0.96) | same-process timing | REG | tests/M9/data/tDataPerformance.m |
