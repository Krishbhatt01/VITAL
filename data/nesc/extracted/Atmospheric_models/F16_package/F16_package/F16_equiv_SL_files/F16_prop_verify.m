function [success] = F16_prop_verify()
% Script file to verify implementation of F16_prop.xml in Simulink
%
% Created 02-MAR-04 by DAVE2SL utility
%

% set filename

% Load data file - no longer needed with model workspace storage
%F16_prop_setup

% Set options
options = simset('FixedStep',1,'MaxStep',1,'MinStep',1,'Solver','FixedStepDiscrete','SrcWorkspace','current');

%
% Checkcase data
%

% Checkcase 1 - lower left corner of envelope, idle

checkcase{1}.name = 'lower left corner of envelope, idle';

checkcase{1}.u = [
0.0	% powerLeverAngle
0.0	% altitudeMSL
0.0	% mach
     ]';

checkcase{1}.y = [
1060.0	% thrustBodyForce_X
0.0	% thrustBodyForce_Y
0.0	% thrustBodyForce_Z
0.0	% thrustBodyMoment_Roll
0.0	% thrustBodyMoment_Pitch
0.0	% thrustBodyMoment_Yaw
     ]';

checkcase{1}.tol = [
1.0E-5	% thrustBodyForce_X
1.0E-5	% thrustBodyForce_Y
1.0E-5	% thrustBodyForce_Z
1.0E-5	% thrustBodyMoment_Roll
1.0E-5	% thrustBodyMoment_Pitch
1.0E-5	% thrustBodyMoment_Yaw
     ]';


% Checkcase 2 - lower left corner of envelope, mil power

checkcase{2}.name = 'lower left corner of envelope, mil power';

checkcase{2}.u = [
50.0	% powerLeverAngle
0.0	% altitudeMSL
0.0	% mach
     ]';

checkcase{2}.y = [
12680.0	% thrustBodyForce_X
0.0	% thrustBodyForce_Y
0.0	% thrustBodyForce_Z
0.0	% thrustBodyMoment_Roll
0.0	% thrustBodyMoment_Pitch
0.0	% thrustBodyMoment_Yaw
     ]';

checkcase{2}.tol = [
1.0E-5	% thrustBodyForce_X
1.0E-5	% thrustBodyForce_Y
1.0E-5	% thrustBodyForce_Z
1.0E-5	% thrustBodyMoment_Roll
1.0E-5	% thrustBodyMoment_Pitch
1.0E-5	% thrustBodyMoment_Yaw
     ]';


% Checkcase 3 - lower left corner of envelope, max power

checkcase{3}.name = 'lower left corner of envelope, max power';

checkcase{3}.u = [
100.0	% powerLeverAngle
0.0	% altitudeMSL
0.0	% mach
     ]';

checkcase{3}.y = [
20000.0	% thrustBodyForce_X
0.0	% thrustBodyForce_Y
0.0	% thrustBodyForce_Z
0.0	% thrustBodyMoment_Roll
0.0	% thrustBodyMoment_Pitch
0.0	% thrustBodyMoment_Yaw
     ]';

checkcase{3}.tol = [
1.0E-5	% thrustBodyForce_X
1.0E-5	% thrustBodyForce_Y
1.0E-5	% thrustBodyForce_Z
1.0E-5	% thrustBodyMoment_Roll
1.0E-5	% thrustBodyMoment_Pitch
1.0E-5	% thrustBodyMoment_Yaw
     ]';


% Checkcase 4 - lower RIGHT corner of envelope, max power

checkcase{4}.name = 'lower RIGHT corner of envelope, max power';

checkcase{4}.u = [
100.0	% powerLeverAngle
0.0	% altitudeMSL
1.0	% mach
     ]';

checkcase{4}.y = [
28885.0	% thrustBodyForce_X
0.0	% thrustBodyForce_Y
0.0	% thrustBodyForce_Z
0.0	% thrustBodyMoment_Roll
0.0	% thrustBodyMoment_Pitch
0.0	% thrustBodyMoment_Yaw
     ]';

checkcase{4}.tol = [
1.0E-5	% thrustBodyForce_X
1.0E-5	% thrustBodyForce_Y
1.0E-5	% thrustBodyForce_Z
1.0E-5	% thrustBodyMoment_Roll
1.0E-5	% thrustBodyMoment_Pitch
1.0E-5	% thrustBodyMoment_Yaw
     ]';


% Checkcase 5 - upper corner of envelope, idle

checkcase{5}.name = 'upper corner of envelope, idle';

checkcase{5}.u = [
0.0	% powerLeverAngle
50000.0	% altitudeMSL
1.0	% mach
     ]';

checkcase{5}.y = [
700.0	% thrustBodyForce_X
0.0	% thrustBodyForce_Y
0.0	% thrustBodyForce_Z
0.0	% thrustBodyMoment_Roll
0.0	% thrustBodyMoment_Pitch
0.0	% thrustBodyMoment_Yaw
     ]';

checkcase{5}.tol = [
1.0E-5	% thrustBodyForce_X
1.0E-5	% thrustBodyForce_Y
1.0E-5	% thrustBodyForce_Z
1.0E-5	% thrustBodyMoment_Roll
1.0E-5	% thrustBodyMoment_Pitch
1.0E-5	% thrustBodyMoment_Yaw
     ]';


% Checkcase 6 - upper corner of envelope, mil power

checkcase{6}.name = 'upper corner of envelope, mil power';

checkcase{6}.u = [
50.0	% powerLeverAngle
50000.0	% altitudeMSL
1.0	% mach
     ]';

checkcase{6}.y = [
2310.0	% thrustBodyForce_X
0.0	% thrustBodyForce_Y
0.0	% thrustBodyForce_Z
0.0	% thrustBodyMoment_Roll
0.0	% thrustBodyMoment_Pitch
0.0	% thrustBodyMoment_Yaw
     ]';

checkcase{6}.tol = [
1.0E-5	% thrustBodyForce_X
1.0E-5	% thrustBodyForce_Y
1.0E-5	% thrustBodyForce_Z
1.0E-5	% thrustBodyMoment_Roll
1.0E-5	% thrustBodyMoment_Pitch
1.0E-5	% thrustBodyMoment_Yaw
     ]';


% Checkcase 7 - upper corner of envelope, max power

checkcase{7}.name = 'upper corner of envelope, max power';

checkcase{7}.u = [
100.0	% powerLeverAngle
50000.0	% altitudeMSL
1.0	% mach
     ]';

checkcase{7}.y = [
5057.0	% thrustBodyForce_X
0.0	% thrustBodyForce_Y
0.0	% thrustBodyForce_Z
0.0	% thrustBodyMoment_Roll
0.0	% thrustBodyMoment_Pitch
0.0	% thrustBodyMoment_Yaw
     ]';

checkcase{7}.tol = [
1.0E-5	% thrustBodyForce_X
1.0E-5	% thrustBodyForce_Y
1.0E-5	% thrustBodyForce_Z
1.0E-5	% thrustBodyMoment_Roll
1.0E-5	% thrustBodyMoment_Pitch
1.0E-5	% thrustBodyMoment_Yaw
     ]';


% Checkcase 8 - middle of envelope, less than mil power

checkcase{8}.name = 'middle of envelope, less than mil power';

checkcase{8}.u = [
42.3	% powerLeverAngle
23507.0	% altitudeMSL
0.625	% mach
     ]';

checkcase{8}.y = [
5319.3491	% thrustBodyForce_X
0.0	% thrustBodyForce_Y
0.0	% thrustBodyForce_Z
0.0	% thrustBodyMoment_Roll
0.0	% thrustBodyMoment_Pitch
0.0	% thrustBodyMoment_Yaw
     ]';

checkcase{8}.tol = [
0.0010	% thrustBodyForce_X
1.0E-5	% thrustBodyForce_Y
1.0E-5	% thrustBodyForce_Z
1.0E-5	% thrustBodyMoment_Roll
1.0E-5	% thrustBodyMoment_Pitch
1.0E-5	% thrustBodyMoment_Yaw
     ]';


% Checkcase 9 - middle of envelope, greater than mil power

checkcase{9}.name = 'middle of envelope, greater than mil power';

checkcase{9}.u = [
88.3	% powerLeverAngle
33537.0	% altitudeMSL
0.895	% mach
     ]';

checkcase{9}.y = [
9298.8926	% thrustBodyForce_X
0.0	% thrustBodyForce_Y
0.0	% thrustBodyForce_Z
0.0	% thrustBodyMoment_Roll
0.0	% thrustBodyMoment_Pitch
0.0	% thrustBodyMoment_Yaw
     ]';

checkcase{9}.tol = [
6.0E-4	% thrustBodyForce_X
1.0E-5	% thrustBodyForce_Y
1.0E-5	% thrustBodyForce_Z
1.0E-5	% thrustBodyMoment_Roll
1.0E-5	% thrustBodyMoment_Pitch
1.0E-5	% thrustBodyMoment_Yaw
     ]';


num_cases = 9;

fprintf('Running %d verification cases for %s:\n', num_cases, 'F16_prop');

outcome = 0;

for i=1:num_cases
   UT = [0 checkcase{i}.u];
   y_good = checkcase{i}.y;
   y_tol = checkcase{i}.tol;
   [t,x,y] = sim('F16_prop',[0 0],options,UT);
   outcome(i) = (length(y_good) == sum(abs(y-y_good)<y_tol));

   if outcome(i) == 0
      fprintf(' Case %s FAILED.\n', checkcase{i}.name);
   else
      fprintf(' Case %d passed...\n', i);
   end
end

if sum(outcome) == num_cases
   success = 1;
   fprintf('\nAll cases passed: model "F16_prop" verified.\n');
else
   success = 0;
   fprintf('%f%% (%d of %d) FAILED. "F16_prop" not verified!\n', ...
             100*(num_cases-sum(outcome))/num_cases, ...
             num_cases-sum(outcome), num_cases);
end

