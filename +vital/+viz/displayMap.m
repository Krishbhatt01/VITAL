function M = displayMap()
%DISPLAYMAP  The ONE mapping from (forward/North, right/East, down) components
%   to 3-D plot axes (x, y, z) used by every axis-check figure.
%   M = vital.viz.displayMap()      p_plot = M * v
%
%   plot x = right / East,  plot y = forward / North,  plot z = up (= -down)
%
%   M is a proper rotation (det +1), so the picture is never a mirror image:
%   with North (or the nose) pointing into the screen and up drawn up, East
%   (or the right wing) appears on the RIGHT. North x East = Down holds for the
%   drawn vectors as well.
%   History: until 2026-10-14 the figures used diag(1, 1, -1), i.e. (North,
%   East, Up). That frame is LEFT-handed (det -1), so 10 of the 13 figures
%   were drawn mirrored. Found by the user; tests/M5/tAxisChecksDisplay.m.
M = [0 1 0;
     1 0 0;
     0 0 -1];
end
