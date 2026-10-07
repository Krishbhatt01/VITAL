classdef (TestTags = {'M2'}) tDavemlOperators < vital.test.DavemlCase
%TDAVEMLOPERATORS  M2: every MathML construct VITAL supports, against a hand
%   result (tests/fixtures/daveml/ops.dml). Operand order is checked with
%   a ~= b so that a - b, a / b and a ^ b cannot pass with arguments swapped.

    properties
        F
    end

    methods (TestMethodSetup)
        function compileOps(tc)
            tc.F = tc.compileToTemp(vital.daveml.read(tc.fixture('ops.dml')), 'vitalfx_ops');
        end
    end

    methods (Test)
        function arithmeticAndOperandOrder(tc)
            o = tc.F(struct('a', 3, 'b', 2));
            c = 'hand evaluation, a = 3, b = 2';
            tc.verifyTol(o.sub, 1, 0, 'abs', 'ANALYTIC', c, 'Quantity', 'a - b');
            tc.verifyTol(o.neg, -3, 0, 'abs', 'ANALYTIC', c, 'Quantity', '-a (unary minus)');
            tc.verifyTol(o.div, 1.5, 0, 'abs', 'ANALYTIC', c, 'Quantity', 'a / b');
            tc.verifyTol(o.pw, 9, 0, 'abs', 'ANALYTIC', c, 'Quantity', 'a ^ b');
            tc.verifyTol(o.nary, 6.5, 0, 'abs', 'ANALYTIC', c, 'Quantity', 'a + b + 1.5 (n-ary plus)');
            tc.verifyTol(o.tms, 12, 0, 'abs', 'ANALYTIC', c, 'Quantity', 'a * b * 2 (n-ary times)');
            tc.verifyTol(o.ab, 1, 0, 'abs', 'ANALYTIC', c, 'Quantity', '|a - b|');
            tc.verifyTol(o.trig, cos(3) + sin(2), 1e-15, 'abs', 'ANALYTIC', c, 'Quantity', 'cos a + sin b');
            tc.verifyTol(o.at2, atan2(3, 2), 1e-15, 'abs', 'ANALYTIC', 'csymbol atan2(a, b): first argument is y', 'Quantity', 'atan2');
        end

        function piecewiseBranches(tc)
            tc.verifyTol(tc.F(struct('a', 1, 'b', 2)).pwv, 1, 0, 'abs', 'ANALYTIC', 'a < b branch', 'Quantity', 'pwv(1,2)');
            tc.verifyTol(tc.F(struct('a', 3, 'b', 2)).pwv, 2, 0, 'abs', 'ANALYTIC', 'a > b branch', 'Quantity', 'pwv(3,2)');
            tc.verifyTol(tc.F(struct('a', 2, 'b', 2)).pwv, 3, 0, 'abs', 'ANALYTIC', 'otherwise branch', 'Quantity', 'pwv(2,2)');
        end

        function piecewiseNestedInsideApply(tc)
            tc.verifyTol(tc.F(struct('a', -4, 'b', 0)).nest, 40, 0, 'abs', 'ANALYTIC', '10 * |a| via piecewise', 'Quantity', 'nest(-4)');
            tc.verifyTol(tc.F(struct('a', 4, 'b', 0)).nest, 40, 0, 'abs', 'ANALYTIC', '10 * |a| via piecewise', 'Quantity', 'nest(4)');
        end

        function piecewiseWrappedInApplyAsNasaWritesIt(tc)
            % F16_aero.dml:611-628 (clt, cnt) wrap <piecewise> in an operator-less <apply>.
            c = 'NASA F16_aero.dml:611-628 construct; hand evaluation';
            tc.verifyTol(tc.F(struct('a', 3, 'b', -1)).wrapped, -3, 0, 'abs', 'ANALYTIC', c, 'Quantity', 'wrapped(b<0)');
            tc.verifyTol(tc.F(struct('a', 3, 'b', 1)).wrapped, 3, 0, 'abs', 'ANALYTIC', c, 'Quantity', 'wrapped(otherwise)');
        end

        function minMaxValueSaturate(tc)
            c = 'variableDef minValue="0" maxValue="1" is a saturation (ADR-014)';
            tc.verifyTol(tc.F(struct('a', 5, 'b', 1)).sat, 1, 0, 'abs', 'ANALYTIC', c, 'Quantity', 'sat(5)');
            tc.verifyTol(tc.F(struct('a', -2, 'b', 1)).sat, 0, 0, 'abs', 'ANALYTIC', c, 'Quantity', 'sat(-2)');
            tc.verifyTol(tc.F(struct('a', 0.5, 'b', 1)).sat, 0.5, 0, 'abs', 'ANALYTIC', c, 'Quantity', 'sat(0.5)');
        end

        function initialValueConstant(tc)
            tc.verifyTol(tc.F(struct('a', 2, 'b', 1)).useK, 14.5, 0, 'abs', 'ANALYTIC', 'k = initialValue 7.25', 'Quantity', 'k * a');
        end

        function missingInputIsAnError(tc)
            tc.verifyError(@() tc.F(struct('a', 1)), 'vital:daveml:missingInput');
        end
    end
end
