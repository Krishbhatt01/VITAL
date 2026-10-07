classdef (TestTags = {'M2'}) tDavemlTables < vital.test.DavemlCase
%TDAVEMLTABLES  M2: gridded tables, storage order, clamping and extrapolation.

    properties
        F
    end

    methods (TestMethodSetup)
        function compileTable(tc)
            tc.F = tc.compileToTemp(vital.daveml.read(tc.fixture('table.dml')), 'vitalfx_table');
        end
    end

    methods (Test)
        function gridPointsAndInterpolation(tc)
            c = 'table.dml: f(x,y) listed with y fastest';
            tc.verifyTol(tc.F(struct('x', 2, 'y', 20)).fClamp, 4, 0, 'abs', 'ANALYTIC', c, 'Quantity', 'f(2,20)');
            tc.verifyTol(tc.F(struct('x', 3, 'y', 10)).fClamp, 5, 0, 'abs', 'ANALYTIC', c, 'Quantity', 'f(3,10)');
            tc.verifyTol(tc.F(struct('x', 1.5, 'y', 15)).fClamp, 2.5, 1e-15, 'abs', 'ANALYTIC', 'bilinear mean of 1,2,3,4', 'Quantity', 'f(1.5,15)');
        end

        function neitherClampsAndFlags(tc)
            o = tc.F(struct('x', 0, 'y', 10));
            tc.verifyTol(o.fClamp, 1, 0, 'abs', 'ANALYTIC', 'extrapolate="neither": clamp to x = 1', 'Quantity', 'f(0,10) clamped');
            tc.verifyExact(o.outOfEnvelope, true, 'ANALYTIC', 'clamping sets OUT_OF_DATA_ENVELOPE (FC-401)', 'Quantity', 'flag');
            tc.verifyExact(tc.F(struct('x', 2, 'y', 15)).outOfEnvelope, false, 'ANALYTIC', 'inside the table: no flag', 'Quantity', 'flag inside');
        end

        function bothExtrapolatesLinearly(tc)
            tc.verifyTol(tc.F(struct('x', 4, 'y', 10)).fExtrap, 7, 1e-14, 'abs', 'ANALYTIC', 'extrapolate="both": 5 + 2*(4-3)', 'Quantity', 'f(4,10)');
            tc.verifyTol(tc.F(struct('x', 0, 'y', 10)).fExtrap, -1, 1e-14, 'abs', 'ANALYTIC', 'extrapolate="both": 1 - 2*(1-0)', 'Quantity', 'f(0,10)');
        end

        function f16TablesRoundTripAtEveryBreakpoint(tc)
            % Every F-16 aero and propulsion table, evaluated by the lookup at every grid
            % point, returns the stored datum exactly.
            for file = {'F16_aero.dml', 'F16_prop.dml'}
                m = vital.daveml.read(tc.f16File(file{1}));
                worst = 0; n = 0;
                for f = m.functions(:)'
                    grids = cell(1, numel(f.bps)); [grids{:}] = ndgrid(f.bps{:});
                    for i = 1:numel(grids{1})
                        x = cellfun(@(g) g(i), grids);
                        y = vital.daveml.lookup(f.bps, f.data, x, f.extrapolate, f.lo, f.hi);
                        worst = max(worst, abs(y - f.data(i))); n = n + 1;
                    end
                end
                tc.verifyTol(worst, 0, 0, 'abs', 'ANALYTIC', sprintf('%s: %d grid points', file{1}, n), ...
                    'Quantity', ['max table round-trip error ' file{1}]);
            end
        end
    end
end
