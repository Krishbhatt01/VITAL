classdef (TestTags = {'M2'}) tDavemlParser < vital.test.DavemlCase
%TDAVEMLPARSER  M2: the DAVE-ML reader recovers the NASA F-16 files exactly.
%   Counts and values are PUB: read from the files themselves (line numbers
%   in docs/nesc/NESC_EXTRACT_F16.md section B).

    methods (Test)
        function f16AeroStructure(tc)
            m = vital.daveml.read(tc.f16File('F16_aero.dml'));
            c = 'F16_aero.dml (NESC package); NESC_EXTRACT_F16.md B.1';
            tc.verifyExact(numel(m.vars), 50, 'PUB', c, 'Quantity', 'variableDefs');
            tc.verifyExact(nnz([m.vars.isInput]), 9, 'PUB', c, 'Quantity', 'inputs');
            tc.verifyExact(nnz([m.vars.isOutput]), 9, 'PUB', c, 'Quantity', 'outputs');
            tc.verifyExact(numel(m.breakpoints), 4, 'PUB', c, 'Quantity', 'breakpointDefs');
            tc.verifyExact(numel(m.functions), 18, 'PUB', c, 'Quantity', 'functions');
            tc.verifyExact(numel(m.checks), 16, 'PUB', c, 'Quantity', 'staticShots');
            bp = m.breakpoints(strcmp({m.breakpoints.bpID}, 'ALPHA1'));
            tc.verifyTol(bp.vals, -10:5:45, 0, 'abs', 'PUB', 'F16_aero.dml:952-955 ALPHA1', 'Quantity', 'ALPHA1', 'Unit', 'deg');
        end

        function f16PropStructure(tc)
            m = vital.daveml.read(tc.f16File('F16_prop.dml'));
            c = 'F16_prop.dml; NESC_EXTRACT_F16.md B.2';
            tc.verifyExact(numel(m.vars), 13, 'PUB', c, 'Quantity', 'variableDefs');
            tc.verifyExact(nnz([m.vars.isInput]), 3, 'PUB', c, 'Quantity', 'inputs');
            tc.verifyExact(numel(m.functions), 3, 'PUB', c, 'Quantity', 'functions');
            tc.verifyExact(numel(m.checks), 9, 'PUB', c, 'Quantity', 'staticShots');
        end

        function f16InertiaStructure(tc)
            m = vital.daveml.read(tc.f16File('F16_inertia.dml'));
            tc.verifyExact(numel(m.vars), 12, 'PUB', 'F16_inertia.dml; NESC_EXTRACT_F16.md B.3', 'Quantity', 'variableDefs');
            v = m.vars(strcmp({m.vars.varID}, 'CG_PCT_MAC'));
            tc.verifyExact(v.initialValue, 35, 'PUB', 'F16_inertia.dml:44', 'Quantity', 'CG_PCT_MAC default');
            v = m.vars(strcmp({m.vars.varID}, 'XMASS'));
            tc.verifyExact(v.initialValue, 637.1595, 'PUB', 'F16_inertia.dml:111', 'Quantity', 'XMASS', 'Unit', 'slug');
        end

        function saturationAttributesAreRead(tc)
            m = vital.daveml.read(tc.f16File('F16_aero.dml'));
            v = m.vars(strcmp({m.vars.varID}, 'vt'));
            tc.verifyExact(v.minValue, 0.1, 'PUB', 'F16_aero.dml:292 minValue', 'Quantity', 'vt minValue');
            tc.verifyExact(v.maxValue, Inf, 'ANALYTIC', 'absent maxValue means unbounded', 'Quantity', 'vt maxValue');
        end

        function tableStorageOrderLastBreakpointFastest(tc)
            % CX over (el = DE1, alpha = ALPHA1); file lines 998-1002 list alpha fastest.
            m = vital.daveml.read(tc.f16File('F16_aero.dml'));
            f = m.functions(strcmp({m.functions.output}, 'cxt'));
            c = 'F16_aero.dml:998-1002 CX_table (last breakpoint changes most rapidly)';
            tc.verifyExact(size(f.data), [5 12], 'PUB', c, 'Quantity', 'size(CX)');
            tc.verifyTol(f.data(1,1), -0.099, 0, 'abs', 'PUB', c, 'Quantity', 'CX(el=-24, alpha=-10)');
            tc.verifyTol(f.data(1,2), -0.081, 0, 'abs', 'PUB', c, 'Quantity', 'CX(el=-24, alpha=-5)');
            tc.verifyTol(f.data(2,1), -0.048, 0, 'abs', 'PUB', c, 'Quantity', 'CX(el=-12, alpha=-10)');
            tc.verifyTol(f.data(5,12), 0.040, 0, 'abs', 'PUB', c, 'Quantity', 'CX(el=24, alpha=45)');
        end

        function sourceHashRecorded(tc)
            f = tc.f16File('F16_aero.dml');
            m = vital.daveml.read(f);
            tc.verifyExact(m.sha256, vital.io.sha256File(f), 'ANALYTIC', 'model records the SHA-256 of its source', 'Quantity', 'sha256');
        end
    end
end
