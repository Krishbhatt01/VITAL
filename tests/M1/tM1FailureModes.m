classdef (TestTags = {'M1'}) tM1FailureModes < vital.test.VitalTestCase
%TM1FAILUREMODES  M1: every M1 failure mode in docs/FAILURE_CATALOGUE.md
%   (FC-101 ... FC-108) is detected with its EXACT identifier, so a test
%   cannot pass on the wrong error.

    properties (TestParameter)
        badCall = struct( ...
            'dcm321NaN',       {@() vital.frames.dcm321(NaN, 0, 0)}, ...
            'eul2quatInf',     {@() vital.frames.eul2quat(0, Inf, 0)}, ...
            'quat2dcmNaN',     {@() vital.frames.quat2dcm([NaN; 0; 0; 1])}, ...
            'dcm2eulNaN',      {@() vital.frames.dcm2eul(nan(3))}, ...
            'lla2ecefNaN',     {@() vital.geo.lla2ecef(NaN, 0, 0, vital.geo.constants('wgs84'))}, ...
            'gravitationInf',  {@() vital.geo.gravitation([Inf; 0; 0], vital.geo.constants('wgs84'))}, ...
            'transferLoadNaN', {@() vital.loads.transferLoad([NaN;0;0], [0;0;0], [0;0;0], eye(3))}, ...
            'massPropsNaN',    {@() vital.mass.massProps(struct('m', NaN, 'r', [0;0;0], 'J', zeros(3)))}, ...
            'atmosphereNaN',   {@() vital.env.atmosphereUS76(NaN)}, ...
            'airDataNaN',      {@() vital.airdata.airData([NaN;0;0], [0;0;0], eye(3), [0;0;0], vital.env.atmosphereUS76(0), struct('b',1,'cbar',1))})
    end

    methods (Test)
        function nanInfInputRejected(tc, badCall)
            tc.verifyError(badCall, 'vital:badInput');                                  % FC-101
        end

        function zeroQuaternionRejected(tc)
            tc.verifyError(@() vital.frames.quat2dcm([0;0;0;0]), 'vital:badInput');     % FC-102
        end

        function nonUnitQuaternionNormalizedWithWarning(tc)
            q = [2; 0; 0; 0];                                                          % FC-103
            tc.verifyWarning(@() vital.frames.quatNormalize(q), 'vital:frames:quatNotUnit');
            ws = warning('off', 'vital:frames:quatNotUnit'); c = onCleanup(@() warning(ws));
            qn = vital.frames.quatNormalize(q);
            tc.verifyTol(norm(qn), 1, 1e-15, 'abs', 'ANALYTIC', 'normalized to unit length', 'Quantity', '|q|');
            tc.verifyTol(vital.frames.quat2dcm(q), eye(3), 1e-15, 'abs', 'ANALYTIC', 'quat2dcm normalizes first', 'Quantity', 'C(2,0,0,0)');
        end

        function unitQuaternionRaisesNoWarning(tc)
            tc.verifyWarningFree(@() vital.frames.quatNormalize([1;0;0;0]));
        end

        function negativeMassRejected(tc)
            tc.verifyError(@() vital.mass.massProps(struct('m', -1, 'r', [0;0;0], 'J', zeros(3))), ...
                'vital:mass:negativeMass');                                             % FC-104
        end

        function zeroTotalMassRejected(tc)
            tc.verifyError(@() vital.mass.massProps(struct('m', 0, 'r', [0;0;0], 'J', zeros(3))), ...
                'vital:mass:negativeMass');
        end

        function nonPhysicalInertiaRejected(tc)
            % Ixx > Iyy + Izz violates the triangle inequality for any real body.     % FC-105
            tc.verifyError(@() vital.mass.inertiaTensor(10, 2, 3, 0, 0, 0), 'vital:mass:nonPhysicalInertia');
            tc.verifyError(@() vital.mass.inertiaTensor(-1, 2, 3, 0, 0, 0), 'vital:mass:nonPhysicalInertia');
        end

        function altitudeBelowModelRejected(tc)
            tc.verifyError(@() vital.env.atmosphereUS76(-6000), 'vital:env:altitudeOutOfRange');   % FC-106
        end

        function altitudeAboveModelRejected(tc)
            tc.verifyError(@() vital.env.atmosphereUS76(90000), 'vital:env:altitudeOutOfRange');
        end

        function zeroAirspeedRejected(tc)
            tc.verifyError(@() vital.airdata.airData([0;0;0], [0;0;0], eye(3), [0;0;0], ...
                vital.env.atmosphereUS76(0), struct('b',1,'cbar',1)), 'vital:airdata:zeroAirspeed'); % FC-107
        end

        function supersonicCasRejected(tc)
            atm = vital.env.atmosphereUS76(0);
            tc.verifyError(@() vital.airdata.tasToCasEas(1.2*atm.a, atm), 'vital:airdata:supersonic');  % FC-108
        end
    end
end
