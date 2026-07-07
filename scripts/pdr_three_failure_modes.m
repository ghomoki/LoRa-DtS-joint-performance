%PDR_THREE_FAILURE_MODES  Pass where all three loss mechanisms contribute.
%   Tuned so that static Doppler dominates near the horizon, dynamic Doppler
%   dominates near the zenith, and the link margin sits in a moderate band
%   so that fading causes occasional packet drops throughout. Useful as a
%   single-figure illustration of the joint channel model.

clear;
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

E    = 1;          % Minimum elevation angle  (deg) — full pass
B    = 62.5;       % Bandwidth                (kHz) — narrow → low static threshold
F_C  = 915;        % Carrier frequency        (MHz)
LDRO = false;      % Off → dynamic Doppler bites
SF   = 8;          % Spreading factor — low enough that dyn threshold isn't crushed
P_L  = 100;         % Application payload      (bytes)
H    = 1000;        % Orbital altitude         (km) — low LEO → high Doppler rate

% Modest link budget: positive margin near zenith, marginal near horizon.
opts = { ...
    'P_tx_dbm', 22, ...    % 158 mW
    'G_t',       3, ...    % dBi
    'G_r',       3};       % dBi

fprintf('Running 3-failure-mode scenario: SF=%d, B=%g kHz, F_C=%g MHz, H=%g km\n', ...
    SF, B, F_C, H);

tic;
[pdr, L_static, L_dynamic, L_joint, results] = ...
    packetdeliveryratio(E, B, F_C, LDRO, SF, P_L, H, opts{:});
elapsed = toc;

fprintf('PDR = %.4f over %d packets (%.1f s elapsed).\n', ...
    pdr, height(results), elapsed);
fprintf('  Static  Doppler failures : %d (%.1f%%)\n', sum(L_static),  100*mean(L_static));
fprintf('  Dynamic Doppler failures : %d (%.1f%%)\n', sum(L_dynamic), 100*mean(L_dynamic));
fprintf('  Joint   Doppler failures : %d (%.1f%%)\n', sum(L_joint),   100*mean(L_joint));
fprintf('  Link margin: min %.2f dB, mean %.2f dB, max %.2f dB\n', ...
    min(results.("Link margin (dB)")), mean(results.("Link margin (dB)")), ...
    max(results.("Link margin (dB)")));

%% Plot reception probability and link margin
P_success = (1 - L_static) .* (1 - L_dynamic) .* results.P_link;
time   = results.("Time (s)");
margin = results.("Link margin (dB)");

i_static_fail  = find(L_static);
i_dynamic_fail = find(L_dynamic);

figure;
%tl = tiledlayout(2, 1, TileSpacing='compact');

% Panel 1: Reception probability
figure;
hold on;
plot(time, results.P_link, '-', Color=[5/256 207/256 230/256], LineWidth=1.3, ...
    DisplayName='P_{link}');
plot(time, P_success, '-', Color=[48/256 150/256 26/256], LineWidth=2.3, ...
    DisplayName='P_{success}');
if ~isempty(i_static_fail)
    plot(time(i_static_fail), zeros(size(i_static_fail)), ...
        Marker='.', MarkerEdgeColor=[0.00 0.45 0.74], MarkerSize=10, LineWidth=1.2, LineStyle='none', DisplayName='L_{static} = true');
end
if ~isempty(i_dynamic_fail)
    plot(time(i_dynamic_fail), zeros(size(i_dynamic_fail)), ...
        Marker='.', MarkerEdgeColor=[0.85 0.33 0.10], MarkerSize=10, LineWidth=1.2, LineStyle='none', DisplayName='L_{dynamic} = true');
end
hold off;
xlabel({'Time (s)', 'Zenith = 0'});
ylabel('Packet reception probability');
ylim([-0.05 1.05]);
legend(Location='northeast');
grid on;

%title(sprintf('PDR = %.4f   (SF=%d, B=%g kHz, F_C=%g MHz, H=%g km)', ...
%    pdr, SF, B, F_C, H));


% Panel 2: Link margin
figure;
hold on;
plot(time, margin, '-', Color=[0.00 0.45 0.74], LineWidth=1.5);
yline(0, '--', 'Color', [0.5 0.5 0.5], 'Label', 'sensitivity');
hold off;
ylabel('Link margin (dB)');
xlabel({'Time (s)', 'Zenith = 0'});
grid on;
