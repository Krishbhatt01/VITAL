function q = quatNormalize(q)
%QUATNORMALIZE  Return a unit quaternion (column), with the checks of FC-102/103.
%   A zero quaternion is an error (vital:badInput). A quaternion whose norm
%   differs from 1 by more than 1e-12 is normalized WITH the warning
%   vital:frames:quatNotUnit, so a drifting integrator state is never
%   renormalized silently.
vital.validate.finite(q, 'quaternion');
if numel(q) ~= 4
    error('vital:badInput', 'quaternion must have 4 elements.');
end
q = q(:);
n = norm(q);
if n == 0
    error('vital:badInput', 'zero quaternion has no rotation.');
end
if abs(n - 1) > 1e-12
    warning('vital:frames:quatNotUnit', 'quaternion norm %.15g normalized to 1.', n);
end
q = q / n;
end
