function [tau, v] = pass_duration(H_km, E_min_deg)
%PASS_DURATION  Pass duration for a direct overhead satellite pass.
%
%   tau = pass_duration(H, E_min) returns the pass duration/visibility time in seconds for a satellite in a circular orbit at altitude H
%   passing directly overhead a ground station, subject to a minimum elevation angle E_min.

arguments
    H_km        % Orbital altitude        (km)
    E_min_deg   % Minimum elevation angle (deg)
end

% Convert inputs to SI
H     =   H_km * 1e3;         % km  -> m
E_min =   deg2rad(E_min_deg); % deg -> rad

% Constants
R_E = 6371e3;  % Earth radius               (m)
g   = 9.80665; % Gravitational acceleration (m/s^2)

% Slant range at minimum elevation
d_m = R_E * (sqrt(((H + R_E)/R_E)^2 - cos(E_min)^2) - sin(E_min));

% Angle at Earth center from zenith to minimum elevation
alpha = asin(d_m * cos(E_min) / (R_E + H));

% Orbital velocity of circular orbit
v = sqrt(g * R_E / (1 + H/R_E));

% Pass time = 2 * (orbit radius * angle, orbit arc length) / orbital velocity
tau = 2 * (R_E + H) * alpha / v;
end
