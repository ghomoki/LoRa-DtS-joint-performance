function [PDR, L_static_arr, L_dynamic_arr, L_joint_arr, results] = packetdeliveryratio(E_min, B_kHz, F_C_MHz, LDRO, SF, P_L, H_km, opts)
%PACKETDELIVERYRATIO  LoRa Direct-to-Satellite packet delivery ratio with Doppler + link-budget constraints.
%
%   [PDR, L_static_arr, L_dynamic_arr, L_joint_arr, results] = ...
%       packetdeliveryratio(E, B, F_C, LDRO, SF, P_L, H, ...)
%
%   For a direct overhead satellite pass at packet reporting interval R_p, and for
%   each candidate packet:
%     1. Evaluates static and dynamic Doppler failure conditions.
%     2. Computes the deterministic mean SNR from the link budget (Friis path loss, antenna gains, receiver noise figure).
%     3. Evaluates the link success probability under elevation-dependent Rician fading analytically.
%     4. Combines:  P_success = (1 - L_static)*(1 - L_dynamic)*P_link.
%
%   PDR is the mean of P_success over all packets in the pass.

arguments (Input)
    E_min                     % Minimum elevation angle       (deg)
    B_kHz                     % Bandwidth setting             (kHz)
    F_C_MHz                   % Carrier frequency             (MHz)
    LDRO                      % Low data rate optimization    (0/1)
    SF                        % Spreading factor              (7..12)
    P_L                       % Packet payload length         (bytes)
    H_km                      % Satellite altitude            (km)
    opts.R_p         = 5      % Packet reporting interval     (s)
    opts.n_preamble  = 8      % LoRa preamble length          (symbols)
    opts.IH          = 0      % Implicit header               (0/1)
    opts.CRC         = 1      % Cyclic redundancy check       (0/1)
    opts.CR          = 1      % Coding rate index             (1..4)
    opts.PL_overhead = 5      % MAC overhead added to payload (bytes)
    opts.G_t         = 2      % Tx antenna gain               (dBi)
    opts.G_r         = 2      % Rx antenna gain               (dBi)
    opts.P_tx_dbm    = 20     % Tx power                      (dBm)
    opts.NF_dB       = 6      % Receiver noise figure         (dB)
end

arguments (Output)
    PDR             % Packet delivery ratio over the pass
    L_static_arr    % Static  Doppler failure per packet  (0/1)
    L_dynamic_arr   % Dynamic Doppler failure per packet  (0/1)
    L_joint_arr     % Joint   Doppler failure per packet  (0/1)
    results         % Per-packet table (time, geometry, Doppler, link)
end


% Constants
R_E = 6371e3;            % Earth radius                (m)
g   = 9.80665;           % Gravitational acceleration  (m/s^2)
c   = 299792458;         % Speed of light              (m/s)

% Convert to SI base units
B   = B_kHz   * 1e3;     % kHz -> Hz
F_C = F_C_MHz * 1e6;     % MHz -> Hz
H   = H_km    * 1e3;     % km  -> m


% Time on Air
ToA = lora_toa(SF, B_kHz, P_L, LDRO, n_preamble=opts.n_preamble, IH=opts.IH, CRC=opts.CRC, CR=opts.CR, PL_overhead=opts.PL_overhead) * 1e-3;   % ms -> s

% Pass geometry
[tau, v]   = pass_duration(H_km, E_min);  % Pass duration and velocity
omega = sqrt(g/R_E) * (1 + H/R_E)^(-3/2); % Angular rate     (rad/s)
u_geo = 1 + H/R_E;                        % Cached ratio for cosBeta

% Doppler tolerance thresholds
F_static  = 0.25 * B;
L_LDRO    = 1 + 15 * LDRO;           % 16 if LDRO on, else 1
F_dynamic = L_LDRO * B / (3 * 2^SF);


%% Link budget, deterministic part

D_SNR_dB        = -2.5 * (SF - 4);                 % Receiver SNR threshold
P_tx_W          = dBm_to_lin(opts.P_tx_dbm);
G_t_lin         = dB_to_lin(opts.G_t);
G_r_lin         = dB_to_lin(opts.G_r);
D_SNR_lin       = dB_to_lin(D_SNR_dB);
sigma_w_dBm     = -174 + opts.NF_dB + 10*log10(B); % AWGN power
sigma_w_W       = dBm_to_lin(sigma_w_dBm);
sensitivity_dBm = sigma_w_dBm + D_SNR_dB;          % Receiver sensitivity


%% Loop over pass
n_max       = ceil(tau / opts.R_p) + 2; % Number of iterations
n_cols      = 10;
results_arr = NaN(n_max, n_cols);
P_success   = zeros(n_max, 1);

t = -tau/2;
i = 0;
while t <= tau/2
    % Doppler shift at packet beginning and end
    [d_t, E_t_deg, F_D]     = orbital_state(t);
    [~,   ~,       F_D_end] = orbital_state(t + ToA);
    % Doppler shift within packet
    delta_F_E = F_D - F_D_end;

    % Doppler rate via central difference over 1 ms (diagnostic only)
    dt = 1e-3;
    [~, ~, F_D_plus]  = orbital_state(t + dt/2);
    [~, ~, F_D_minus] = orbital_state(t - dt/2);
    dF_D_dt           = (F_D_plus - F_D_minus) / dt;

    % Per-packet Doppler failure decisions
    L_static  = abs(F_D) >= F_static;
    L_dynamic = abs(delta_F_E) >= F_dynamic;

    % Friis free-space path loss
    PL_lin       = (c / (4*pi*d_t*F_C))^2;
    % Received power
    P_rx_mean_W  = P_tx_W * G_t_lin * G_r_lin * PL_lin;
    % Received SNR
    SNR_mean_lin = P_rx_mean_W / sigma_w_W;
    % Rician factor
    K            = rician_K(E_t_deg);

    % Link budget closure probability
    P_link = link_success_prob(SNR_mean_lin, K, D_SNR_lin);
    % Combined link budget + Doppler packet success probability
    P_succ = (1 - L_static) * (1 - L_dynamic) * P_link;

    % Link margin (dB) above receiver sensitivity, for diagnostics
    P_rx_dBm       = opts.P_tx_dbm + opts.G_t + opts.G_r + 10*log10(PL_lin);
    link_margin_dB = P_rx_dBm - sensitivity_dBm;

    % Save results
    i = i + 1;
    P_success(i)     = P_succ;
    results_arr(i,:) = [t, E_t_deg, d_t, F_D, dF_D_dt, delta_F_E, link_margin_dB, P_link, L_static, L_dynamic];
    % Increment time
    t = t + opts.R_p;
end

% Trim preallocated excess
P_success   = P_success(1:i);
results_arr = results_arr(1:i, :);


%% Aggregate
results = array2table(results_arr, VariableNames=[ ...
    "Time (s)", ...
    "Elevation (deg)", ...
    "Slant range (m)", ...
    "Doppler shift (Hz)", ...
    "Doppler rate (Hz/s)", ...
    "Packet Doppler shift (Hz)", ...
    "Link margin (dB)", ...
    "P_link", ...
    "Static loss", ...
    "Dynamic loss"]);


% Packet delivery ratio
PDR           = mean(P_success);
L_static_arr  = results.("Static loss");
L_dynamic_arr = results.("Dynamic loss");
L_joint_arr   = L_static_arr .* L_dynamic_arr;

    function [d, E_deg, F_D] = orbital_state(t)
        % Orbital state at relative time t (s) from zenith.
        phi     = t * omega;
        cos_phi = cos(phi);
        sin_phi = sin(phi);

        d       = sqrt(R_E^2 + (R_E + H)^2 - 2*R_E*(R_E + H)*cos_phi);
        sin_E   = ((R_E + H)*cos_phi - R_E) / d;
        E_deg   = rad2deg(asin(sin_E));

        cosBeta = sin_phi / sqrt(u_geo^2 - 2*u_geo*cos_phi + 1);
        F_D     = F_C / (1 + v/c * cosBeta) - F_C;
    end
end
