classdef (TestTags = {'M3'}) tF16Plant < vital.test.VitalTestCase
%TF16PLANT  M3: the F-16 plant assembled from the NASA models.
%   Pipeline: state -> US 1976 atmosphere -> air data -> F16 aero + prop
%   (model units ft, deg, lbf at the boundary) -> loads about the MRC
%   (35 % MAC) -> transfer to the CG -> gravity -> rigid-body equations.

    properties
        AC
        Env
        X       % a representative flight state
        U       % representative controls [de da dr throttle]
    end

    methods (TestMethodSetup)
        function setup(tc)
            tc.AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            ft = 0.3048;
            tc.Env = struct('g', 32.174*ft, 'wind_n', [0;0;0], 'deltaT', 0);
            a = deg2rad(4); V = 500*ft;
            tc.X = [V*cos(a); 0; V*sin(a); 0.01; 0.02; -0.01; vital.frames.eul2quat(0, a, 0); 0; 0; -10000*ft];
            tc.U = [deg2rad(-2); deg2rad(1); deg2rad(-1); 0.2];
        end
    end

    methods (Test)
        function configMatchesNescData(tc)
            ft = 0.3048; u = vital.units.constants();
            c = 'F16_aero.dml:368-380 and F16_inertia.dml:63-160 (NESC)';
            tc.verifyTol(tc.AC.S, 300*ft^2, 1e-12, 'rel', 'PUB', c, 'Quantity', 'S', 'Unit', 'm2');
            tc.verifyTol(tc.AC.b, 30*ft, 1e-12, 'rel', 'PUB', c, 'Quantity', 'b', 'Unit', 'm');
            tc.verifyTol(tc.AC.cbar, 11.32*ft, 1e-12, 'rel', 'PUB', c, 'Quantity', 'cbar', 'Unit', 'm');
            tc.verifyTol(tc.AC.mass, 637.1595*u.slug, 1e-12, 'rel', 'PUB', c, 'Quantity', 'mass', 'Unit', 'kg');
            tc.verifyTol(tc.AC.r_cg, [1.132*ft; 0; 0], 1e-12, 'abs', 'PUB', ...
                'DXCG = 0.01 cbar (35 - 25) = 1.132 ft forward of the MRC (F16_inertia.dml:141)', 'Quantity', 'r_cg', 'Unit', 'm');
            tc.verifyTol(tc.AC.J(1,3), -982*u.slugft2, 1e-9, 'rel', 'PUB', ...
                'XIZX = 982 slug ft2 is the product integral; tensor entry is -Ixz (CONVENTIONS 6)', 'Quantity', 'J13', 'Unit', 'kg m2');
        end

        function controlSignsMatchVitalConventions(tc)
            % CONVENTIONS 7: positive deflection gives a negative moment about its axis.
            base = struct('vt', 500, 'alpha', 4, 'beta', 0, 'p', 0, 'q', 0, 'r', 0, 'el', 0, 'ail', 0, 'rdr', 0);
            c0 = vital.models.f16.aero(base);
            e = base; e.el = 5;   ce = vital.models.f16.aero(e);
            a = base; a.ail = 5;  ca = vital.models.f16.aero(a);
            r = base; r.rdr = 5;  cr = vital.models.f16.aero(r);
            c = 'F16_aero.dml sign attributes vs CONVENTIONS 7';
            tc.verifyWithin(ce.cm - c0.cm, -Inf, -1e-6, 'ANALYTIC', [c ': +elevator (TED) -> nose down'], 'Quantity', 'dCm/+de');
            tc.verifyWithin(ca.cl - c0.cl, -Inf, -1e-6, 'ANALYTIC', [c ': +aileron -> roll left'], 'Quantity', 'dCl/+da');
            tc.verifyWithin(cr.cn - c0.cn, -Inf, -1e-6, 'ANALYTIC', [c ': +rudder (TEL) -> nose left'], 'Quantity', 'dCn/+dr');
        end

        function aeroInputsAreConvertedToModelUnits(tc)
            % The plant's aero force equals a direct call of the NASA model with inputs
            % converted by hand to ft/s and deg.
            [~, y] = vital.plant.derivatives(tc.X, tc.U, tc.AC, tc.Env);
            ft = 0.3048;
            in = struct('vt', y.V/ft, 'alpha', rad2deg(y.alpha), 'beta', rad2deg(y.beta), ...
                'p', tc.X(4), 'q', tc.X(5), 'r', tc.X(6), 'el', rad2deg(tc.U(1)), 'ail', rad2deg(tc.U(2)), 'rdr', rad2deg(tc.U(3)));
            o = vital.models.f16.aero(in);
            F = y.qbar * tc.AC.S * [o.cx; o.cy; o.cz];
            tc.verifyTol(y.F_aero, F, 1e-9, 'rel', 'INDEP', 'direct NASA model call with hand-converted inputs', 'Quantity', 'F_aero', 'Unit', 'N');
            p = vital.models.f16.prop(struct('PWR', 100*tc.U(4), 'ALT', -tc.X(13)/ft, 'RMACH', y.mach));
            tc.verifyTol(y.F_prop(1), p.FEX * vital.units.constants().lbf, 1e-12, 'rel', 'INDEP', 'thrust lbf -> N', 'Quantity', 'thrust', 'Unit', 'N');
        end

        function momentTransferredFromMrcToCg(tc)
            % M_cg = M_mrc - r_cg x F  with r_cg = +1.132 ft forward (README "must be transferred").
            [~, y] = vital.plant.derivatives(tc.X, tc.U, tc.AC, tc.Env);
            F = y.F_aero + y.F_prop; M = y.M_aero + y.M_prop;
            tc.verifyTol(y.M_cg, M - cross(tc.AC.r_cg, F), 1e-9, 'rel', 'ANALYTIC', ...
                'NESC README: loads must be transferred from the MRC (35 % MAC) to the CM', 'Quantity', 'M_cg', 'Unit', 'N m');
        end

        function aftCgIsLessStableInPitch(tc)
            % With the CG at 35 % (on the MRC) the lift no longer gives the nose-down moment
            % it gives with the CG 1.132 ft forward (25 %): pitch moment about the CG rises.
            AC35 = vital.aircraft.f16.config('CG_PCT_MAC', 35);
            [~, y25] = vital.plant.derivatives(tc.X, tc.U, tc.AC, tc.Env);
            [~, y35] = vital.plant.derivatives(tc.X, tc.U, AC35, tc.Env);
            tc.verifyGreaterThan(y35.M_cg(2), y25.M_cg(2));
        end

        function datumInvariance(tc)
            % Re-express every position about a BFRP 3 m forward, 0.7 m right and 1.2 m up:
            % the state derivative must not change.
            AC2 = vital.aircraft.f16.config('CG_PCT_MAC', 25, 'BfrpOffset', [3; 0.7; -1.2]);
            d1 = vital.plant.derivatives(tc.X, tc.U, tc.AC, tc.Env);
            d2 = vital.plant.derivatives(tc.X, tc.U, AC2, tc.Env);
            tc.verifyTol(d2, d1, 1e-10, 'abs', 'ANALYTIC', 'results independent of the geometry datum', 'Quantity', 'xdot datum shift');
        end

        function gravityEntersOnlyThroughTheCg(tc)
            % Doubling g at a level attitude adds exactly g to w-dot and nothing to q-dot.
            X = tc.X; X(7:10) = [1;0;0;0];
            e2 = tc.Env; e2.g = 2*tc.Env.g;
            d1 = vital.plant.derivatives(X, tc.U, tc.AC, tc.Env);
            d2 = vital.plant.derivatives(X, tc.U, tc.AC, e2);
            tc.verifyTol(d2(3) - d1(3), tc.Env.g, 1e-10, 'abs', 'ANALYTIC', 'gravity at the CG', 'Quantity', 'delta wdot', 'Unit', 'm/s2');
            tc.verifyTol(d2(5) - d1(5), 0, 1e-12, 'abs', 'ANALYTIC', 'no gravity moment about the CG', 'Quantity', 'delta qdot', 'Unit', 'rad/s2');
        end

        function outOfEnvelopeFlagPropagates(tc)
            X = tc.X; a = deg2rad(60); V = norm(X(1:3));
            X(1:3) = V*[cos(a); 0; sin(a)];
            [~, y] = vital.plant.derivatives(X, tc.U, tc.AC, tc.Env);
            tc.verifyExact(y.outOfEnvelope, true, 'ANALYTIC', 'alpha 60 deg is beyond the 45 deg table (FC-401)', 'Quantity', 'flag');
            [~, y0] = vital.plant.derivatives(tc.X, tc.U, tc.AC, tc.Env);
            tc.verifyExact(y0.outOfEnvelope, false, 'ANALYTIC', 'alpha 4 deg is inside the tables', 'Quantity', 'flag inside');
        end

        function nonFiniteStateRejected(tc)
            X = tc.X; X(2) = NaN;
            tc.verifyError(@() vital.plant.derivatives(X, tc.U, tc.AC, tc.Env), 'vital:badInput');
        end

        function badControlVectorRejected(tc)
            tc.verifyError(@() vital.plant.derivatives(tc.X, tc.U(1:3), tc.AC, tc.Env), 'vital:badInput');
        end

        function nonFiniteDerivativeRejected(tc)
            % FC-402: a component that returns Inf must stop the plant, not propagate.
            AC = tc.AC; AC.loadsFcn = @(varargin) deal([Inf; 0; 0], [0; 0; 0], struct('outOfEnvelope', false));
            tc.verifyError(@() vital.plant.derivatives(tc.X, tc.U, AC, tc.Env), 'vital:plant:nonFinite');
        end

        function badCgInputRejected(tc)
            tc.verifyError(@() vital.aircraft.f16.config('CG_PCT_MAC', -5), 'vital:badInput');
        end
    end
end
