function J = inertiaTensor(Ixx, Iyy, Izz, Ixy, Ixz, Iyz)
%INERTIATENSOR  Inertia tensor from published moments and products of inertia.
%   Products are the positive integrals (Ixz = int x z dm), so the tensor is
%   J = [Ixx -Ixy -Ixz; -Ixy Iyy -Iyz; -Ixz -Iyz Izz] (CONVENTIONS.md 6).
%   The result must describe a real body: principal moments >= 0 and each
%   principal moment <= the sum of the other two (triangle inequality);
%   otherwise vital:mass:nonPhysicalInertia (FC-105).
vital.validate.finite([Ixx Iyy Izz Ixy Ixz Iyz], 'inertia components');
J = [Ixx -Ixy -Ixz; -Ixy Iyy -Iyz; -Ixz -Iyz Izz];
lam = sort(eig(J));
tol = 1e-12 * max(1, sum(abs(lam)));
if lam(1) < -tol || lam(3) > lam(1) + lam(2) + tol
    error('vital:mass:nonPhysicalInertia', ...
        'principal moments [%g %g %g] are not those of a real body.', lam(1), lam(2), lam(3));
end
end
