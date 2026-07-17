function K = rician_K(E_deg)
%RICIAN_K  Elevation-dependent Rician K-factor for LEO satellite links.
%
%   K = rician_K(E_deg) returns the Rician K-factor given an elevation angle.
%
%   The model is fitted cubic splines for Kim et al. (2006)'s measured K values at {20, 30, 40, 60, 80} degrees elevation.
%   The paper's polynomial fit formula contained a rounding error and does not extrapolate well.
%    - 20 < E < 80: cubic spline interpolation
%    - E > 80:      cubic spline extrapolation (further increasing)
%    - E < 20:      fixed to K(20) = 3.07 as extrapolation would result in increasing K
%   The interpolating function can be visualized with scripts/rician_K_plot.m

arguments
    E_deg   % Elevation angle (degrees)
end

persistent K_model
if isempty(K_model)
    E_data = [20, 30, 40, 60, 80];
    K_data = [3.07, 3.24, 3.60, 5.63, 17.06];
    K_model = griddedInterpolant(E_data, K_data, 'spline', 'spline');
end

% Floor below 20 deg: clamp input so the spline returns K(20) for any E < 20 deg
K = K_model(max(E_deg, 20));
end
