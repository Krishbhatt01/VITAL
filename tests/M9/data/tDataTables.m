classdef (TestTags = {'M9', 'DATA'}) tDataTables < vital.test.VitalTestCase
%TDATATABLES  D1 (docs/PLAN_DATA_LAYER.md) criterion 2: vital.data.Table lookups.
%   PRE-REGISTERED (written before the classes existed):
%   1. AT EVERY BREAKPOINT (REG, bitwise). For each of the 18 F-16 aero tables and
%      the 3 thrust tables, at every grid node (852 nodes): table.at(x) is IDENTICAL (isequal,
%      i.e. every bit) to the generated code's value of that table's output
%      (vital.models.f16.aero / prop, the runtime) and to the stored datum
%      (table.data at that node).
%   2. 10,000 RANDOM POINTS (REG, bitwise), rng 91101, aero inputs alpha -30..70 deg,
%      beta -45..45 deg, el -40..40 deg, vt 0..1000 ft/s (so also below the vt
%      saturation), ail, rdr, p, q, r random; prop RMACH -0.2..1.3, ALT -5,000..60,000
%      ft, PWR -10..110 %. Each table is queried at its inputs AS THE GENERATED CODE
%      SEES THEM (out.<input>, after any minValue/maxValue saturation of the input
%      variable): table.at(...) == out.<table output> bitwise for every table and
%      point, and the clamped flags agree with out.outOfEnvelope (any table
%      clamped <=> outOfEnvelope). Non-vacuous: at least 2,000 aero points and 2,000
%      prop points lie outside a table range (clamped exactly as the generated
%      code clamps).
%   3. BY NAME, ANY ORDER: CXT = d.aero.table('CXT') has breakpoints named
%      {'el', 'alpha'} in deg (PUB: F16_aero.dml function "Basic CX"):
%      at('alpha', 5, 'el', 0) == at('el', 0, 'alpha', 5) == at([0 5]) ==
%      vital.models.f16.aero(...).cxt at alpha 5, el 0 (bitwise). T_MIL has {'RMACH',
%      'ALT'} in {nd, ft} (F16_prop.dml T_MIL_fn).
%   4. INDEP. Inside the range, table.at agrees with MATLAB's griddedInterpolant
%      (table.toGriddedInterpolant(), linear) to 1e-12 absolute on 2,000 random
%      points per table (all 21 tables).
%      FAILED HYPOTHESIS (first GREEN run, kept above as registered): the three thrust
%      tables (T_IDLE, T_MIL, T_MAX, up to 28,880 lb) differ by up to 7.3e-12 lb, which is
%      2 ulp of their magnitude (eps(28880) = 3.6e-12): an absolute 1e-12 is below
%      double resolution there, so no independent implementation can meet it unless it
%      repeats the operation order exactly. The registered check is KEPT for the 18
%      aero tables (all |values| < 40; measured <= 8.3e-17). CORRECTED (4b), with an
%      independent justification: |difference| <= 1e-12 times the table's largest
%      |value| on all 21 tables (rounding of a d-linear interpolation is a few ulp of
%      the table scale; measured 4.6e-16 relative). Not a loosening on the aero tables.
%   5. ERRORS: a missing input: vital:data:missingInput; an unknown input name:
%      vital:data:unknownInput; a positional vector of the wrong length:
%      vital:data:badQuery; an unknown table: vital:data:unknownName.
%   6. grid() returns the breakpoint vectors and the data; plot() draws without error
%      (invisible figure).

    properties
        D
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.D = vital.aircraft.f16.data();
        end
    end

    methods (Test)
        function everyBreakpointBitwise(tc)
            parts = {'aero', @vital.models.f16.aero, struct('vt', 300, 'alpha', 0, 'beta', 0, 'p', 0, 'q', 0, 'r', 0, 'el', 0, 'ail', 0, 'rdr', 0); ...
                'propulsion', @vital.models.f16.prop, struct('PWR', 60, 'ALT', 0, 'RMACH', 0)};
            nNodes = 0; bad = {};
            for p = 1:size(parts, 1)
                m = dmlPart(tc.D, parts{p, 1});
                for t = m.tables(:).'
                    bps = {t.breakpoints.values};
                    g = cell(1, numel(bps));
                    [g{:}] = ndgrid(bps{:});
                    for n = 1:numel(g{1})
                        in = parts{p, 3};
                        x = cellfun(@(c) c(n), g);
                        for j = 1:numel(x)
                            nm = t.breakpoints(j).name;
                            if strcmp(nm, 'absbeta'), nm = 'beta'; end     % absbeta = |beta| (F16_aero.dml), nodes are >= 0
                            in.(nm) = x(j);
                        end
                        out = parts{p, 2}(in);
                        y = t.at(x);
                        if ~(isequal(y, out.(t.varID)) && isequal(y, t.data(n))), bad{end+1} = sprintf('%s node %d', t.varID, n); end %#ok<AGROW>
                        nNodes = nNodes + 1;
                    end
                end
            end
            fprintf('[tDataTables] %d grid nodes compared\n', nNodes);
            tc.verifyExact(numel(bad), 0, 'REG', 'PLAN_DATA_LAYER 2: Table.at = generated code = stored datum at every node', ...
                'Quantity', 'nodes that differ');
            tc.verifyEmpty(bad, strjoin(bad, ', '));
            tc.verifyExact(nNodes, 852, 'ANALYTIC', 'non-vacuous: 5x12 + 12 + 5x12 + 2 x 7x12 + 9 x 12 + 4 x 7x12 aero, 3 x 6x6 prop', 'Quantity', 'grid nodes');
        end

        function randomPointsBitwise(tc)
            rng(91101);
            N = 10000;
            [nBad, nOut, nOeBad] = deal(0);
            m = tc.D.aero;
            for i = 1:N
                in = struct('vt', 1000 * rand, 'alpha', -30 + 100 * rand, 'beta', -45 + 90 * rand, 'p', 4 * (rand - 0.5), ...
                    'q', 4 * (rand - 0.5), 'r', 4 * (rand - 0.5), 'el', -40 + 80 * rand, 'ail', -30 + 60 * rand, 'rdr', -40 + 80 * rand);
                out = vital.models.f16.aero(in);
                [b, c] = tc.compareAll(m, out);
                nBad = nBad + b; nOut = nOut + c;
                nOeBad = nOeBad + (c ~= out.outOfEnvelope);
            end
            tc.verifyWithin(nOut, 2000, Inf, 'REG', 'non-vacuous: aero points outside a table range', 'Quantity', 'aero out-of-range points');
            m = tc.D.propulsion;
            nOutP = 0;
            for i = 1:N
                in = struct('PWR', -10 + 120 * rand, 'ALT', -5000 + 65000 * rand, 'RMACH', -0.2 + 1.5 * rand);
                out = vital.models.f16.prop(in);
                [b, c] = tc.compareAll(m, out);
                nBad = nBad + b; nOutP = nOutP + c;
                nOeBad = nOeBad + (c ~= out.outOfEnvelope);
            end
            fprintf('[tDataTables] random: %d aero + %d prop points, %d / %d outside a range, %d differ\n', N, N, nOut, nOutP, nBad);
            tc.verifyExact(nBad, 0, 'REG', 'PLAN_DATA_LAYER 2: 10,000 random points, bitwise', 'Quantity', 'table values that differ');
            tc.verifyExact(nOeBad, 0, 'REG', 'clamping identical to the generated code', 'Quantity', 'outOfEnvelope disagreements');
            tc.verifyWithin(nOutP, 2000, Inf, 'REG', 'non-vacuous: prop points outside a table range', 'Quantity', 'prop out-of-range points');
        end

        function lookupByNameAnyOrder(tc)
            cxt = tc.D.aero.table('CXT');
            tc.verifyExact({cxt.breakpoints.name}, {'el', 'alpha'}, 'PUB', 'F16_aero.dml "Basic CX": independentVarRef el, alpha', 'Quantity', 'CXT inputs');
            tc.verifyExact({cxt.breakpoints.units}, {'deg', 'deg'}, 'PUB', 'F16_aero.dml breakpointDef DE1, ALPHA1', 'Quantity', 'CXT input units');
            a = cxt.at('alpha', 5, 'el', 0);
            b = cxt.at('el', 0, 'alpha', 5);
            c = cxt.at([0 5]);
            out = vital.models.f16.aero(struct('vt', 300, 'alpha', 5, 'beta', 0, 'p', 0, 'q', 0, 'r', 0, 'el', 0, 'ail', 0, 'rdr', 0));
            tc.verifyExact([a b c], [out.cxt out.cxt out.cxt], 'REG', 'by name in any order = positional = generated code', 'Quantity', 'CXT(alpha 5, el 0)');
            a = cxt.at('alpha', 7.3, 'el', -3.1);
            out = vital.models.f16.aero(struct('vt', 300, 'alpha', 7.3, 'beta', 0, 'p', 0, 'q', 0, 'r', 0, 'el', -3.1, 'ail', 0, 'rdr', 0));
            tc.verifyExact(a, out.cxt, 'REG', 'between nodes', 'Quantity', 'CXT(alpha 7.3, el -3.1)');
            tm = tc.D.propulsion.table('T_MIL');
            tc.verifyExact({tm.breakpoints.name}, {'RMACH', 'ALT'}, 'PUB', 'F16_prop.dml T_MIL_fn', 'Quantity', 'T_MIL inputs');
            tc.verifyExact({tm.breakpoints.units}, {'nd', 'ft'}, 'PUB', 'F16_prop.dml MACH_PTS, ALT_PTS', 'Quantity', 'T_MIL input units');
            tc.verifyExact(tm.units, 'lb', 'PUB', 'F16_prop.dml variableDef T_MIL units="lb"', 'Quantity', 'T_MIL units');
            p = vital.models.f16.prop(struct('PWR', 50, 'ALT', 12345, 'RMACH', 0.43));
            tc.verifyExact(tm.at('ALT', 12345, 'RMACH', 0.43), p.T_MIL, 'REG', 'by name = generated code', 'Quantity', 'T_MIL(0.43, 12345 ft)');
        end

        function griddedInterpolantIndep(tc)
            rng(91102);
            worstAero = 0; worstRel = 0; worstAll = 0; n = 0;
            for m = {tc.D.aero, tc.D.propulsion}
                for t = m{1}.tables(:).'
                    G = t.toGriddedInterpolant();
                    tc.verifyClass(G, 'griddedInterpolant');
                    lo = cellfun(@(v) v(1), {t.breakpoints.values});
                    hi = cellfun(@(v) v(end), {t.breakpoints.values});
                    scale = max(abs(t.data(:)));
                    for i = 1:2000
                        x = lo + (hi - lo) .* rand(size(lo));
                        xc = num2cell(x);
                        e = abs(t.at(x) - G(xc{:}));
                        worstAll = max(worstAll, e);
                        if strcmp(m{1}.role, 'aero'), worstAero = max(worstAero, e); end
                        worstRel = max(worstRel, e / scale);
                        n = n + 1;
                    end
                end
            end
            fprintf('[tDataTables] griddedInterpolant: %d points, max |difference| %.3g (aero %.3g), max relative to the table scale %.3g\n', ...
                n, worstAll, worstAero, worstRel);
            % H4 as registered (1e-12 ABSOLUTE on all 21 tables) FAILED on the thrust tables: 7.3e-12 lb at
            % |T| ~ 28,880 lb, i.e. 2 ulp (eps(28880) = 3.6e-12). Kept on the 18 aero tables (|C| < 40):
            tc.verifyTol(worstAero, 0, 1e-12, 'abs', 'INDEP', 'MATLAB griddedInterpolant (linear) inside the range, aero tables', ...
                'Quantity', 'max |Table.at - griddedInterpolant| (aero)');
            % H4b (corrected, see header): 1e-12 RELATIVE to each table's largest |value|, all 21 tables
            tc.verifyTol(worstRel, 0, 1e-12, 'abs', 'INDEP', ['MATLAB griddedInterpolant; two multilinear formulas in a ' ...
                'different operation order differ by a few ulp of the table scale'], 'Quantity', 'max |difference| / max|table|');
            tc.verifyWithin(n, 40000, Inf, 'REG', 'non-vacuous', 'Quantity', 'points');
        end

        function lookupErrors(tc)
            cxt = tc.D.aero.table('CXT');
            tc.verifyError(@() cxt.at('alpha', 5), 'vital:data:missingInput');
            tc.verifyError(@() cxt.at('alpha', 5, 'el', 0, 'beta', 1), 'vital:data:unknownInput');
            tc.verifyError(@() cxt.at([1 2 3]), 'vital:data:badQuery');
            tc.verifyError(@() tc.D.aero.table('NO_SUCH_TABLE'), 'vital:data:unknownName');
        end

        function gridAndPlot(tc)
            cxt = tc.D.aero.table('CXT');
            [bps, data] = cxt.grid();
            tc.verifyExact(bps, {cxt.breakpoints.values}, 'REG', 'grid() gives the breakpoints', 'Quantity', 'grid breakpoints');
            tc.verifyExact(data, cxt.data, 'REG', 'grid() gives the data', 'Quantity', 'grid data');
            f = figure('Visible', 'off');
            c = onCleanup(@() close(f));
            h = cxt.plot(axes(f));
            tc.verifyNotEmpty(h);
            h = tc.D.aero.table('CZT').plot(axes(figure(f)));
            tc.verifyNotEmpty(h);
        end
    end

    methods (Access = private)
        function [nBad, anyClamped] = compareAll(~, m, out)
            nBad = 0; anyClamped = false;
            for t = m.tables(:).'
                x = cellfun(@(n) out.(n), {t.breakpoints.name});
                [y, c] = t.at(x);
                nBad = nBad + ~isequal(y, out.(t.varID));
                anyClamped = anyClamped || c;
            end
        end
    end
end
