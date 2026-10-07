classdef (TestTags = {'M3'}) tRigidBody < vital.test.VitalTestCase
%TRIGIDBODY  M3: flat-earth rigid-body equations about the CG, scalar-first
%   quaternion (docs/CONVENTIONS.md sections 3, 6):
%     m (vdot + w x v) = F_b
%     J wdot + w x (J w + h_rot) + hdot_rot = M_cg
%     qdot = 1/2 Omega(w) q + k (1 - q'q) q,  k = 1 s^-1
%     pdot_n = C_bn' v

    properties
        J = [1285 0 -50; 0 1825 0; -50 0 2667]
    end

    methods (Test)
        function translationalEquation(tc)
            v = [50; 2; 5]; w = [0.1; -0.2; 0.05]; F = [100; -40; 250]; m = 10;
            d = vital.eom.rigidBodyDerivs(v, w, [1;0;0;0], F, [0;0;0], m, tc.J);
            tc.verifyTol(d(1:3), F/m - cross(w, v), 1e-13, 'abs', 'ANALYTIC', 'vdot = F/m - w x v', 'Quantity', 'vdot', 'Unit', 'm/s2');
        end

        function rotationalEquationWithGyro(tc)
            w = [0.3; -0.1; 0.2]; M = [10; -5; 3]; h = [5; 0; 0]; hd = [0.5; 0; 0];
            d = vital.eom.rigidBodyDerivs([10;0;0], w, [1;0;0;0], [0;0;0], M, 1, tc.J, h, hd);
            exp = tc.J \ (M - cross(w, tc.J*w + h) - hd);
            tc.verifyTol(d(4:6), exp, 1e-13, 'abs', 'ANALYTIC', 'J wdot = M - w x (J w + h) - hdot', 'Quantity', 'wdot', 'Unit', 'rad/s2');
        end

        function torqueFreeConservesMomentumAndEnergy(tc)
            % Integrate a torque-free tumble with RK4; body-frame |H| and T are invariants.
            w = [0.4; 1.2; -0.3]; q = [1;0;0;0]; dt = 1e-3;
            f = @(x) vital.eom.rigidBodyDerivs([0;0;0], x(1:3), x(4:7), [0;0;0], [0;0;0], 1, tc.J);
            x = [w; q];
            H0 = norm(tc.J*w); T0 = 0.5*w.'*tc.J*w;
            for k = 1:5000
                k1 = pick(f(x)); k2 = pick(f(x + dt/2*k1)); k3 = pick(f(x + dt/2*k2)); k4 = pick(f(x + dt*k3));
                x = x + dt/6*(k1 + 2*k2 + 2*k3 + k4);
            end
            wE = x(1:3);
            tc.verifyTol(norm(tc.J*wE), H0, 1e-8, 'rel', 'ANALYTIC', 'torque-free: |H| constant', 'Quantity', '|H| after 5 s');
            tc.verifyTol(0.5*wE.'*tc.J*wE, T0, 1e-8, 'rel', 'ANALYTIC', 'torque-free: rotational energy constant', 'Quantity', 'T after 5 s');
            tc.verifyTol(norm(x(4:7)), 1, 1e-10, 'abs', 'ANALYTIC', 'constraint stabilization keeps |q| = 1', 'Quantity', '|q| after 5 s');
        end

        function quaternionKinematicsMatchDcmRate(tc)
            % qdot must reproduce Cdot = -[w x] C (body rates of C_bn).
            q = vital.frames.eul2quat(0.3, -0.2, 1.0); w = [0.2; -0.1; 0.4]; h = 1e-7;
            d = vital.eom.rigidBodyDerivs([0;0;0], w, q, [0;0;0], [0;0;0], 1, tc.J);
            Cnum = (vital.frames.quat2dcm(q + h*d(7:10)) - vital.frames.quat2dcm(q - h*d(7:10))) / (2*h);
            W = [0 -w(3) w(2); w(3) 0 -w(1); -w(2) w(1) 0];
            tc.verifyTol(Cnum, -W*vital.frames.quat2dcm(q), 1e-7, 'abs', 'ANALYTIC', 'dC_bn/dt = -[w x] C_bn', 'Quantity', 'Cdot');
        end

        function positionRateIsNedVelocity(tc)
            q = vital.frames.eul2quat(0, 0.1, pi/4); v = [100; 0; 5];
            d = vital.eom.rigidBodyDerivs(v, [0;0;0], q, [0;0;0], [0;0;0], 1, tc.J);
            tc.verifyTol(d(11:13), vital.frames.quat2dcm(q).' * v, 1e-12, 'abs', 'ANALYTIC', 'pdot_n = C_bn'' v_b', 'Quantity', 'pdot', 'Unit', 'm/s');
        end

        function droppedMassFallsAtG(tc)
            % F_b = m g (level attitude), no aero: vdot = [0 0 g].
            g = 9.80665; m = 3;
            d = vital.eom.rigidBodyDerivs([0;0;0], [0;0;0], [1;0;0;0], [0;0;m*g], [0;0;0], m, tc.J);
            tc.verifyTol(d(3), g, 1e-14, 'abs', 'ANALYTIC', 'free fall', 'Quantity', 'wdot_z', 'Unit', 'm/s2');
        end

        function nonFiniteInputRejected(tc)
            tc.verifyError(@() vital.eom.rigidBodyDerivs([NaN;0;0], [0;0;0], [1;0;0;0], [0;0;0], [0;0;0], 1, tc.J), 'vital:badInput');
        end
    end
end

function k = pick(d)
k = [d(4:6); d(7:10)];
end
