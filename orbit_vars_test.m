% Constants
g = 9.80665/1e3;    % Gravitational acceleration    (km/s)

d_g = zeros(90, 1);

for E = 1:90
    d_g(E) = groundtrackfromE(deg2rad(E));
end

plot(1:90, d_g)

function d_g = groundtrackfromE(E)
    R = 6371;           % Earth radius                  (km)
    H = 600;

    % Slant range
    d = R * (sqrt( ((H + R)/R)^2 - cos(E)^2 ) - sin(E)); 

    % Ground track
    d_g = R * asin( (d * cos(E)/(R + H)) ); 
end