function [PDR, L_static_arr, L_dynamic_arr, L_joint_arr, results] = packetdeliveryratio(E, B, F_C, LDRO, SF, P_L, H)

%PDR Summary of this function goes here
%   Detailed explanation goes here

arguments (Input)
    E       % Elevation                     (deg)
    B       % Bandwidth setting             (kHz)
    F_C     % Carrier frequency             (MHz)
    LDRO    % Low data rate optimization    (true/false)
    SF      % Spreading factor              (-)
    P_L     % Packet payload length         (bytes)
    H       % Satellite altitude            (km)
end

arguments (Output)
    PDR
    L_static_arr
    L_dynamic_arr
    L_joint_arr
    results
end


% Initialization
S_loss = 0;
D_loss = 0;
J_loss = 0;
F_C = F_C * 1e6; % Convert MHz to Hz
B = B * 1e3; % Convert kHz to Hz

% Constants
R = 6371;           % Earth radius                  (km)
g = 9.80665/1e3;    % Gravitational acceleration    (km/s)
c = 299792458/1e3;      % Speed of light            (km/s)

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

% Payload length (from SX127X datasheet)
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
i = 0;
t_vec = ceil(tau);

results_array = NaN(numel(t_vec), 7);

while t <= tau/2
    %% Doppler shift
    F_D = Dopplershift(t);

    %% Doppler rate
    % Central diff over 1 ms
    dt = 1e-3;
    delta_F_D = (Dopplershift(t + dt/2) - Dopplershift(t - dt/2))/dt;

    %% Doppler shift over packet
    delta_F_E = F_D - Dopplershift(t + ToA);

    %% Static Doppler failure
    L_static = abs(F_D) >= abs(F_static);
    S_loss = S_loss + L_static;


    %% Dynamic Doppler failure
    L_dynamic = abs(delta_F_E) >= F_dynamic;
    D_loss = D_loss + L_dynamic;


    %% Joint Doppler failure
    L_joint = L_static * L_dynamic;
    J_loss = J_loss + L_joint;


    %% Advance
    i = i + 1;
    results_array(i,:) = [t, F_D, delta_F_D, delta_F_E, L_static, L_dynamic, L_joint];
    t = t + 1;
end

results = array2table(results_array, VariableNames=["Time", "Doppler shift", "Doppler rate", "Packet Doppler shift", "Static loss", "Dynamic loss", "Joint loss"]);

% Exported variables
PDR = 1 - (S_loss + D_loss - J_loss)/i;
L_static_arr  = results.("Static loss");
L_dynamic_arr = results.("Dynamic loss");
L_joint_arr   = results.("Joint loss");

function F_D = Dopplershift(t)
    phi = t * sqrt(g/R) * (1 + H/R)^(-3/2);
    cosBeta = sin(phi)/sqrt( (1 + H/R)^2 - 2 * (1 + H/R) * cos(phi) + 1 );

    % Received frequency
    F_R = F_C/(1 + v/c * cosBeta);
    % Doppler shift
    F_D = F_R - F_C;
end

end

