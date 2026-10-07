function IR = inertiaStationToBody(IS)
%INERTIASTATIONTOBODY  Inertia tensor from station axes to body axes.
%   IR = T IS T' with T = diag(-1, 1, -1). The tensor entries for Ixy and
%   Iyz change sign; Ixz does not (CONVENTIONS.md section 2).
vital.validate.finite(IS, 'inertia tensor');
T = diag([-1 1 -1]);
IR = T * IS * T.';
end
