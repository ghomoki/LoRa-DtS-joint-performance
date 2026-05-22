function tau = pass_duration(H, E_min)
%PASS_DURATION  Visibility time for a direct-overhead LEO pass.
%
%   tau = pass_duration(H, E_min) returns the pass duration in seconds for
%   a satellite in a circular orbit at altitude H (km), passing directly
%   overhead a ground station with minimum elevation angle E_min (degrees).
%
%   Geometric model: the satellite traverses an arc of 2*alpha at orbital
%   radius (R+H), where alpha is the half-angle subtended at Earth's center
%   between the sub-satellite point at zenith and the sub-satellite point
%   at elevation E_min. Pass time = arc length / orbital velocity.
%
%   NOTE: this differs from the paper's eq. (4), which uses
%       tau = 2*d_g(E_min)/v
%   where d_g is the ground-track length (arc at Earth's surface). That
%   formula is short by a factor of (R+H)/R because the sub-satellite point
%   moves at R*v/(R+H), not v. For H=560 km, the paper's formula gives
%   651.6 s vs. the correct 708.9 s; the latter matches the TLE-based
%   access window in the paper's own Bandwidth_LoRa_Dopper_effect.m (708 s).

arguments
    H     % Orbital altitude          (km)
    E_min % Minimum elevation angle   (deg)
end

R = 6371;            % Earth radius                  (km)
g = 9.80665/1e3;     % Gravitational acceleration    (km/s^2)

E_rad = deg2rad(E_min);

% Slant range at the visibility horizon (E = E_min), paper eq. (1)
d = R * (sqrt(((H + R)/R)^2 - cos(E_rad)^2) - sin(E_rad));

% Central half-angle from sub-sat-at-zenith to sub-sat-at-(E=E_min)
alpha = asin(d * cos(E_rad) / (R + H));

% Orbital velocity (circular orbit)
v = sqrt(g * R / (1 + H/R));

% Pass time = 2 * arc-at-orbital-radius / velocity
tau = 2 * (R + H) * alpha / v;
end
