function n = axisNotes(id)
%AXISNOTES  Plain-language explanation of one visual axis-check case.
%   n = vital.viz.axisNotes(id)
%   n.explain   what the figure shows and why it matters (shown on the figure
%               and in reports/axis_checks/README.md)
%   n.meaning   one short line per numeric check, IN THE ORDER of the checks
%               built in vital.viz.axisChecks (counts must match; checked there)
%   Ids: yaw pitch roll combined level climb sideslip gravity cg station
%   control path earth. Error: vital:badInput for an unknown id.
switch id
    case 'yaw'
        n.explain = ['Heading 30 deg: the nose swings from North towards East (to the right) and the ' ...
            'wings stay level. This is an orientation, not a control input: it checks that ' ...
            '"heading +30 deg" means nose 30 deg right of North. Every position, wind and display ' ...
            'calculation depends on this sign.'];
        n.meaning = {'the nose direction matches hand trigonometry'
                     'yawing does not tilt the aircraft: the belly still points down'
                     'VITAL''s rotation equals MATLAB''s Aerospace Toolbox'};
    case 'pitch'
        n.explain = ['Pitch 20 deg: the nose rises above the horizon and the belly axis tilts aft. ' ...
            'It checks that positive pitch means nose UP, which trim, climb and every time ' ...
            'history rely on.'];
        n.meaning = {'nose points up: its Down component is negative'
                     'the belly axis leans backwards'
                     'VITAL''s rotation equals MATLAB''s Aerospace Toolbox'};
    case 'roll'
        n.explain = ['Bank 40 deg: the right wing goes DOWN. It checks that positive roll is a right ' ...
            'bank, the convention used for turns, aileron inputs and the lateral modes.'];
        n.meaning = {'the right wing direction matches hand trigonometry'
                     'sign check: the right wing points below the horizon'
                     'VITAL''s rotation equals MATLAB''s Aerospace Toolbox'};
    case 'combined'
        n.explain = ['Yaw 30, then pitch 20, then roll 40 (the 3-2-1 order), with the intermediate ' ...
            'frames drawn. Each turn is about the axis of the previous frame, so the order ' ...
            'matters. The matrix, the quaternion (what VITAL integrates) and the angles must ' ...
            'all describe the same attitude.'];
        n.meaning = {'equals the three single rotations multiplied in yaw-pitch-roll order'
                     'MATLAB''s Aerospace Toolbox gives the identical matrix'
                     'the quaternion route gives the same orientation'
                     'a pure rotation: nothing is stretched or skewed'
                     'the axes stay right-handed (no mirror)'
                     'converting back recovers the same three angles'};
    case 'level'
        n.explain = ['The F-16 at NASA''s trim condition. The nose is about 2.65 deg up, yet the velocity ' ...
            'turned into ground axes lies flat on the horizon: the wing needs that angle of attack ' ...
            'for lift. It ties together trim, the stored quaternion, the body-to-ground rotation ' ...
            'and the angle-of-attack definition.'];
        n.meaning = {'the trim solver found a real steady flight point'
                     'the aircraft neither climbs nor sinks'
                     'rotating to ground axes does not change the speed'
                     'angle of attack recovered from the body velocity'
                     'in level flight the nose angle equals alpha (by construction)'
                     'MATLAB''s toolbox rotation gives the same ground velocity'};
    case 'climb'
        n.explain = ['The same aircraft trimmed in a 5 deg climb: the velocity arrow climbs at exactly ' ...
            '5 deg. Climb angle adds to the nose angle: pitch = alpha + gamma. It checks that a ' ...
            'climbing trim really moves the aircraft upwards in ground axes.'];
        n.meaning = {'the trim solver found a real steady climb'
                     'the climb angle measured from the ground velocity is 5 deg'
                     'nose angle minus alpha equals the climb angle (by construction)'
                     'sign check: the vertical velocity points up'};
    case 'sideslip'
        n.explain = ['A body velocity built by hand with alpha 5 deg and beta 10 deg, then a 10 m/s ' ...
            'headwind. It checks that the air-data step reads alpha, beta and airspeed back ' ...
            'correctly, and that wind (given in ground axes) is subtracted in the right ' ...
            'direction: flying into the wind raises the airspeed.'];
        n.meaning = {'angle of attack read back from the velocity'
                     'sideslip angle read back from the velocity'
                     'airspeed read back from the velocity'
                     'a headwind adds its speed to the airspeed'};
    case 'gravity'
        n.explain = ['Gravity always points straight down, but the aircraft sees it in its own axes. ' ...
            'Nose up, it pulls aft (slowing the aircraft); banked right, it pulls towards the right ' ...
            'wing. This is how attitude turns weight into the climb, descent and turning ' ...
            'tendencies in the equations of motion.'];
        n.meaning = {'nose up: gravity pulls backwards along the fuselage'
                     'banked right: gravity pulls towards the right wing'
                     'a combined attitude matches MATLAB''s toolbox'
                     'rotation never changes gravity''s size'};
    case 'cg'
        n.explain = ['Side view seen from the right wing (nose to the right). NASA''s moment reference ' ...
            'point (35 % MAC) is the BFRP origin; the CG sits at 25 % or 30 % MAC, ahead of it. Lift ' ...
            'acting behind the CG makes a nose-down moment. Loads are stored about the fixed BFRP and ' ...
            'moved to the CG, so the CG can move without touching the geometry.'];
        n.meaning = {'CG 25 % position from the MAC formula'
                     'CG 30 % position from the MAC formula'
                     'the moment transfer is the cross product of arm and force'
                     'stability sign: lift behind the CG pitches the nose down'
                     'moving the reference origin changes only coordinates, not the arm'
                     'moving the reference origin changes no physics'};
    case 'station'
        n.explain = ['Side view seen from the left wing (nose to the left). Aircraft drawings and NASA''s ' ...
            'data use station coordinates (x aft, z up). VITAL flips x and z once at import into ' ...
            'body axes (x forward, z down). A missing flip would put the nose behind the CG and the ' ...
            'fin below the fuselage while everything still looked plausible.'];
        n.meaning = {'VITAL''s conversion equals the flip written out by hand'
                     'a point ahead of the datum ends up forward (body x > 0)'
                     'a point above the datum ends up up (body z < 0)'
                     'a left-wing point stays on the left (body y < 0)'};
    case 'control'
        n.explain = ['The moment from +1 deg of elevator, aileron and rudder at trim, computed by the real ' ...
            'plant. VITAL''s convention: a positive deflection gives a NEGATIVE moment about its own ' ...
            'axis (elevator: nose down; aileron: roll left; rudder: nose left). Each arrow points ' ...
            'opposite its axis.'];
        n.meaning = {'+ elevator (trailing edge down) pitches the nose down'
                     '+ aileron (right trailing edge down) rolls left'
                     '+ rudder (trailing edge left) yaws the nose left'
                     'the symmetric aircraft: elevator makes no roll or yaw'};
    case 'path'
        n.explain = ['A real 5 s simulation with a 2 deg aileron step, drawn as a flight path with the body ' ...
            'axes along it. It checks the whole chain over time: plant, integration and position. The ' ...
            'aircraft rolls left and the path bends accordingly.'];
        n.meaning = {'the simulation ran to the end with no guard tripped'
                     'position changes exactly as the attitude and body velocity say'
                     'the aileron sign holds in a real simulation: roll to the left'
                     'altitude is minus the Down position'
                     'the attitude quaternion keeps unit length (no drift)'};
    case 'earth'
        n.explain = ['Local North-East-Down axes at 36 N, 75 W on the WGS-84 Earth (Earth-centred axes, ' ...
            'drawn as they are). Down is perpendicular to the ellipsoid, North points towards the ' ...
            'pole. These are the frames of NASA''s rotating-Earth check cases.'];
        n.meaning = {'the ground-axes rotation equals MATLAB''s toolbox'
                     'the position on the Earth equals MATLAB''s toolbox'
                     'Down is perpendicular to the ellipsoid surface'
                     'North points towards the North Pole'
                     'East is horizontal'
                     'North x East = Down: the frame is right-handed'};
    otherwise
        error('vital:badInput', 'unknown axis-check case "%s".', id);
end
end
