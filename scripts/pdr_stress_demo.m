%PDR_STRESS_DEMO  Link-budget-limited pass scenario.
%   Pushes altitude up, SF down, and bandwidth up to force the link budget
%   (rather than Doppler) to be the dominant failure mode. Useful for
%   sanity-checking that the link-budget integration actually bites when
%   the channel is marginal.

clear;
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

E    = 1;        % Minimum elevation angle  (deg) — full pass
B    = 125;      % Bandwidth                (kHz)
F_C  = 915;      % Carrier frequency        (MHz) — US/Asia ISM band
LDRO = false;     % 
SF   = 10;       % Spreading factor
P_L  = 55;       % Application payload      (bytes)
H    = 1500;      % Orbital altitude         (km) — high LEO

fprintf('Running stress scenario: SF=%d, B=%g kHz, F_C=%g MHz, H=%g km, E_min=%g deg\n', ...
    SF, B, F_C, H, E);
fprintf('(This is slower than pdr_demo due to N_MC=1e5 samples per packet.)\n\n');

tic;
[pdr, L_static, L_dynamic, L_joint, results] = ...
    packetdeliveryratio(E, B, F_C, LDRO, SF, P_L, H);
elapsed = toc;

fprintf('PDR = %.4f over %d packets in the pass (%.1f s elapsed).\n', ...
    pdr, height(results), elapsed);
fprintf('\n--- Failure breakdown ---\n');
fprintf('  Static  Doppler failures : %d (%.1f%%)\n', sum(L_static),  100*mean(L_static));
fprintf('  Dynamic Doppler failures : %d (%.1f%%)\n', sum(L_dynamic), 100*mean(L_dynamic));
fprintf('  Joint   Doppler failures : %d (%.1f%%)\n', sum(L_joint),   100*mean(L_joint));

fprintf('\n--- Link budget ---\n');
margin = results.("Link margin (dB)");
fprintf('  Link margin (dB)  : min %.2f, mean %.2f, max %.2f\n', ...
    min(margin), mean(margin), max(margin));
fprintf('  Elevation range   : %.1f deg to %.1f deg\n', ...
    min(results.("Elevation (deg)")), max(results.("Elevation (deg)")));
fprintf('  Slant range       : %.0f km to %.0f km\n', ...
    min(results.("Slant range (m)"))/1e3, max(results.("Slant range (m)"))/1e3);
fprintf('  Mean P_link       : %.4f\n', mean(results.P_link));
fprintf('  P_link at zenith  : %.4f\n', max(results.P_link));
fprintf('  P_link at horizon : %.4f\n', min(results.P_link));

%% Plot the per-packet success probability across the pass
P_success = (1 - L_static) .* (1 - L_dynamic) .* results.P_link;
time   = results.("Time (s)");
elev   = results.("Elevation (deg)");
margin = results.("Link margin (dB)");
P_link = results.P_link;

i_static_fail  = find(L_static);
i_dynamic_fail = find(L_dynamic);

figure;
tl = tiledlayout(3, 1, TileSpacing='compact');
title(tl, sprintf('SF=%d, B=%g kHz, F_C=%g MHz, H=%g km, E_{min}=%g°, PDR=%.4f', ...
    SF, B, F_C, H, E, pdr));

% Panel 1: Success probabilities and Doppler failure markers
nexttile;
hold on;
plot(time, P_link,    '-', Color=[0.00 0.45 0.74], LineWidth=1.3, DisplayName='P_{link}');
plot(time, P_success, '-', Color=[0.85 0.33 0.10], LineWidth=2.0, DisplayName='P_{success}');
if ~isempty(i_dynamic_fail)
    plot(time(i_dynamic_fail), zeros(size(i_dynamic_fail)), ...
        'kx', MarkerSize=8, LineStyle='none', DisplayName='Dynamic Doppler fail');
end
if ~isempty(i_static_fail)
    plot(time(i_static_fail), zeros(size(i_static_fail)), ...
        'k+', MarkerSize=8, LineStyle='none', DisplayName='Static Doppler fail');
end
hold off;
ylabel('Probability');
ylim([-0.05 1.05]);
legend(Location='east');
grid on;

% Panel 2: Link margin in dB
nexttile;
hold on;
plot(time, margin, '-', Color=[0.00 0.45 0.74], LineWidth=1.5);
yline(0, '--', 'Color', [0.5 0.5 0.5], 'Label', 'sensitivity');
hold off;
ylabel('Link margin (dB)');
grid on;

% Panel 3: Elevation
nexttile;
plot(time, elev, '-', Color=[0.00 0.45 0.74], LineWidth=1.5);
ylabel('Elevation (deg)');
xlabel('Time (s, relative to zenith)');
ylim([0 90]);
grid on;
