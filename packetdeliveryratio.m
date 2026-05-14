function [PDR, L_static, L_dynamic, L_joint] = packetdeliveryratio(E, B, F_C, LDRO, SF, P_L, H)

%PDR Summary of this function goes here
%   Detailed explanation goes here

arguments (Input)
    E       % Elevation                     (deg)
    B       % Bandwidth setting             (kHz)
    F_C     % Carrier frequency             (kHz)
    LDRO    % Low data rate optimization    (true/false)
    SF      % Spreading factor              (-)
    P_L     % Packet payload length         (bytes)
    H       % Satellite altitude            (km)
end

arguments (Output)
    PDR
    L_static
    L_dynamic
    L_joint
end


% Initialization
S_loss = 0;
D_loss = 0;
J_loss = 0;
B = B * 1e3; % convert B, kHz to Hz

% Constants
R = 6371;           % Earth radius                  (km)
g = 9.80665/1e3;    % Gravitational acceleration    (km/s)
c = physconst('Lightspeed');

%% Satellite total visibility time:
E_min = deg2rad(1);    % Minimum elevation    (deg)

% Slant range
d = R * (sqrt( ((H + R)/R)^2 - cos(E_min)^2 ) - sin(E_min)); 

% Ground track
d_g = R * asin( (d * cos(E_min)/(R + H)) ); 

% Orbital velocity
v = sqrt( g * R/(1 + H/R) );
tau = 2*d_g/v;


%% Time on Air:
% Symbol duration
T_s = 2^SF/B; 

% Preamble length
n_preamble = 12;
%   TODO: different preamble lengths
T_preamble = (n_preamble + 4.25) * T_s;

% Payload length
IH = 1;  % Header implicit
%   TODO: explicit header option
CRC = 0; % No CRC
%   TODO: CRC option
CR = 1;  % Coding rate = 4/5
%   TODO: other coding rates options

n_payload = 8 + max( ceil( (8 * P_L - 4 * SF + 28 + 16 * CRC - 20 * IH)/(4*(SF - 2 * LDRO)) * (CR + 4) ), 0 );
T_payload = n_payload * T_s;

ToA = T_preamble + T_payload;


%% Static Doppler threshold
F_static = 0.25 * B;


%% Dynamic Doppler threshold
% L = 16 if LDRO on, L = 1 if LDRO off
L = 1 + LDRO*15; 
F_dynamic = (L*B)/(3*2^SF);


%% Initialize interval
t = -tau/2;

while t <= tau/2
    %% Doppler shift
    phi = t * sqrt(g/R) * (1 + H/R)^(-3/2);
    cosBeta = sin(phi)/sqrt( (1 + H/R)^2 - 2 * (1 + H/R) * cos(phi) + 1 );

    % Received frequency
    F_R = F_C/(1 + v/c * cosBeta);
    % Doppler shift
    F_D = F_R - F_C;


    %% Doppler rate


end

end

