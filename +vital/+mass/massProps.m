function [m, r_cg, J] = massProps(items)
%MASSPROPS  Total mass, CG and inertia tensor about the CG from mass items.
%   items(k).m  mass (kg, >= 0)
%   items(k).r  position of the item's own CG, BFRP coordinates (m)
%   items(k).J  inertia tensor about the item's own CG, body-parallel axes
%               (tensor form, CONVENTIONS.md section 6)
%   J = sum_k [ J_k + m_k (d'd I - d d') ],  d = r_k - r_cg  (parallel axis)
%   Errors: vital:badInput (non-finite), vital:mass:negativeMass (any m_k < 0
%   or total mass <= 0).
if isempty(items)
    error('vital:mass:negativeMass', 'no mass items: total mass must be positive.');
end
for k = 1:numel(items)
    vital.validate.finite(items(k).m, sprintf('items(%d).m', k));
    vital.validate.finite(items(k).r, sprintf('items(%d).r', k));
    vital.validate.finite(items(k).J, sprintf('items(%d).J', k));
    if items(k).m < 0
        error('vital:mass:negativeMass', 'items(%d).m = %g is negative.', k, items(k).m);
    end
end
masses = [items.m];
m = sum(masses);
if m <= 0
    error('vital:mass:negativeMass', 'total mass %g must be positive.', m);
end
R = [items.r];
r_cg = R * masses(:) / m;
J = zeros(3);
for k = 1:numel(items)
    d = items(k).r(:) - r_cg;
    J = J + items(k).J + items(k).m * ((d.'*d)*eye(3) - d*d.');
end
J = (J + J.') / 2;
end
