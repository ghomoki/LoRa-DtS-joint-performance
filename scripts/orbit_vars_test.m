% Exploration script: ground-track length d_g vs elevation angle E.
% Plots d_g(E) at fixed H to visualize how visibility geometry scales.

d_g = zeros(90, 1);

for E = 1:90
    d_g(E) = groundtrackfromE(deg2rad(E));
end

plot(1:90, d_g)
xlabel('Elevation angle [deg]')
ylabel('Ground track length [km]')
grid on

function d_g = groundtrackfromE(E_rad)
    R = 6371;           % Earth radius              (km)
    H = 600;            % Orbital altitude          (km)

    % Slant range at elevation E_rad
    d = R * (sqrt( ((H + R)/R)^2 - cos(E_rad)^2 ) - sin(E_rad));

    % Ground track length on Earth's surface
    d_g = R * asin( d * cos(E_rad) / (R + H) );
end