function K = rician_K(E_deg)
%RICIAN_K  Elevation-dependent Rician K-factor for LEO satellite links.
%
%   K = rician_K(E_deg) returns the Rician K-factor (linear, dimensionless)
%   given an elevation angle E_deg (degrees). Vectorized over E_deg.
%
%   Model: cubic spline through Kim et al. (2006) Table II measured K
%   values at E in {20, 30, 40, 60, 80} deg.
%     - Within [20, 80] deg: standard cubic spline interpolation.
%     - Above 80 deg: cubic spline extrapolation (smooth growth toward zenith).
%     - Below 20 deg: clamped to K(20 deg) = 3.07. This suppresses the
%       unphysical upturn that cubic spline extrapolation produces below the
%       lowest measured data point, while remaining conservative (K is
%       overestimated at low elevation, which only matters when static
%       Doppler isn't already failing the packet first).
%
%   See MODEL_NOTES.md for the rationale and a discussion of the published
%   Kim eq. (28) coefficient typo that motivated using direct spline
%   interpolation of the measured points rather than the published formula.

arguments
    E_deg
end

persistent interp_fcn
if isempty(interp_fcn)
    E_data = [20, 30, 40, 60, 80];
    K_data = [3.07, 3.24, 3.60, 5.63, 17.06];
    interp_fcn = griddedInterpolant(E_data, K_data, 'spline', 'spline');
end

% Floor below 20 deg: clamp input so the spline returns K(20 deg) for any
% E < 20 deg, suppressing the unphysical spline upturn that would otherwise
% occur as E decreases toward the horizon.
E_eval = max(E_deg, 20);
K = interp_fcn(E_eval);
end
