function [PDR, L_static_arr, L_dynamic_arr, L_joint_arr, results] = packetdeliveryratio(E, B_kHz, F_C_MHz, LDRO, SF, P_L, H_km, opts)
%PACKETDELIVERYRATIO  LoRa DtS Doppler-limited packet delivery ratio simulation for a direct overhead pass.
%
%   [PDR, L_static_arr, L_dynamic_arr, L_joint_arr, results] = ...
%       packetdeliveryratio(E, B, F_C, LDRO, SF, P_L, H, ...)
%
%   At packet reporting period R_p, evaluates static and dynamic Doppler
%   failure conditions following [1] (Asad Ullah et al. 2024).
%   Returns the ratio of successfully delivered packets over the entire
%   pass and packet failure timelines separated by type.

arguments (Input)
    E                       % Minimum elevation angle       (deg)
    B_kHz                   % Bandwidth setting             (kHz)
    F_C_MHz                 % Carrier frequency             (MHz)
    LDRO                    % Low data rate optimization    (true/false)
    SF                      % Spreading factor              (-)
    P_L                     % Packet payload length         (bytes)
    H_km                    % Satellite altitude            (km)
    opts.R_p         = 5    % Packet reporting period       (s)
    opts.n_preamble  = 8    % LoRa preamble length          (symbols)
    opts.IH          = 0    % Implicit header               (true/false)
    opts.CRC         = 1    % Cyclic redundance check       (true/false)
    opts.CR          = 1    % Coding rate index             (1 = 4/5 -> 4 = 4/8)
    opts.PL_overhead = 5    % MAC overhead added to payload (bytes)
end

arguments (Output)
    PDR                     % Packet delivery ratio over the pass (-)
    L_static_arr            % Static  Doppler failure per packet  (0/1)
    L_dynamic_arr           % Dynamic Doppler failure per packet  (0/1)
    L_joint_arr             % Joint   Doppler failure per packet  (0/1)
    results                 % Per-packet table (time, F_D, dF_D/dt, dF_E, losses)
end

%% Time on Air
ToA = lora_toa(SF, B_kHz, P_L, LDRO, ...
    n_preamble=opts.n_preamble, IH=opts.IH, CRC=opts.CRC, ...
    CR=opts.CR, PL_overhead=opts.PL_overhead) * 1e-3;   % ms -> s

%% Convert to SI base units
B   = B_kHz   * 1e3; % kHz -> Hz
F_C = F_C_MHz * 1e6; % MHz -> Hz
H   = H_km    * 1e3; % km  -> m

%% Constants
R_E = 6371e3;    % Earth radius                (m)
g   = 9.80665;   % Gravitational acceleration  (m/s^2)
c   = 299792458; % Speed of light              (m/s)

%% Pass geometry
tau = pass_duration(H_km, E);

% Orbital velocity (m/s)
v = sqrt(g * R_E / (1 + H/R_E));

%% Doppler tolerance thresholds
F_static = 0.25 * B;                  % [1] eq. (10)
L_LDRO   = 1 + 15 * LDRO;             % 16 if LDRO on, else 1
F_dynamic = L_LDRO * B / (3 * 2^SF);  % [1] eq. (11)

%% Loop over pass
S_loss = 0;
D_loss = 0;
J_loss = 0;

% Preallocate with a small safety margin
n_packets_max = ceil(tau / opts.R_p) + 2;
results_array = NaN(n_packets_max, 7);

t = -tau/2;
i = 0;
while t <= tau/2
    F_D = Dopplershift(t);

    % Doppler rate via central difference over 1 ms (diagnostic only;
    % packet-level failure uses delta over ToA below)
    dt = 1e-3;
    dF_D_dt = (Dopplershift(t + dt/2) - Dopplershift(t - dt/2)) / dt;

    % Doppler shift accumulated over the packet duration
    delta_F_E = F_D - Dopplershift(t + ToA);

    % Per-packet failure decisions ([1] eq. 12, 13)
    L_static  = abs(F_D) >= F_static;
    L_dynamic = abs(delta_F_E) >= F_dynamic;
    L_joint   = L_static * L_dynamic;

    S_loss = S_loss + L_static;
    D_loss = D_loss + L_dynamic;
    J_loss = J_loss + L_joint;

    i = i + 1;
    results_array(i,:) = [t, F_D, dF_D_dt, delta_F_E, L_static, L_dynamic, L_joint];
    t = t + opts.R_p;
end

%% Aggregate
results = array2table(results_array, VariableNames=[ ...
    "Time (s)", ...
    "Doppler shift (Hz)", ...
    "Doppler rate (Hz/s)", ...
    "Packet Doppler shift (Hz)", ...
    "Static loss", ...
    "Dynamic loss", ...
    "Joint loss"]);

% (eq. 15)
PDR = 1 - (S_loss + D_loss - J_loss) / i;
L_static_arr  = results.("Static loss");
L_dynamic_arr = results.("Dynamic loss");
L_joint_arr   = results.("Joint loss");

    function F_D = Dopplershift(t)
        % Analytical Doppler shift at relative time t (s) from zenith.
        phi = t * sqrt(g/R_E) * (1 + H/R_E)^(-3/2);
        cosBeta = sin(phi) / sqrt((1 + H/R_E)^2 - 2*(1 + H/R_E)*cos(phi) + 1);
        F_R = F_C / (1 + v/c * cosBeta);
        F_D = F_R - F_C;
    end
end
