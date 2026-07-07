%SWEEP_PDR_VS_ALTITUDE  PDR vs orbital altitude with link budget integrated.
%   Contrasts with Ullah Fig. 10 (Doppler only, monotonic decay): including
%   path loss should expose a sweet spot where high-altitude path loss starts
%   to outweigh the low-altitude Doppler penalty.

clear;
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

% Baseline (matches pdr_three_failure_modes.m)
F_C_base = 915;
H_base   = 1000;
B_base   = 62.5;
SF_base  = 8;
LDRO_base = false;
P_L_base = 100;
E        = 1;

% Sweep
H_values = [300, 400, 500, 600, 800, 1000, 1200, 1500, 1800, 2000];

% Configurations
cases = struct( ...
    'SF',    {8,     10,    12}, ...
    'B',     {62.5,  125,   250}, ...
    'LDRO',  {false, false, true}, ...
    'label', {'SF=8, B=62.5 kHz, LDRO off', ...
              'SF=10, B=125 kHz, LDRO off', ...
              'SF=12, B=250 kHz, LDRO on'});
palette = [0.00 0.45 0.74; 0.85 0.33 0.10; 0.47 0.67 0.19];

PDR = NaN(length(H_values), numel(cases));
fprintf('Sweeping altitude (%d configs × %d points)\n', numel(cases), length(H_values));
tic;
for c = 1:numel(cases)
    for k = 1:length(H_values)
        rng(0);
        PDR(k, c) = packetdeliveryratio( ...
            E, cases(c).B, F_C_base, cases(c).LDRO, cases(c).SF, P_L_base, H_values(k));
    end
    fprintf('  [%d/%d] %s done\n', c, numel(cases), cases(c).label);
end
fprintf('Elapsed: %.1f s\n', toc);

%% Plot
figure;
hold on;
for c = 1:numel(cases)
    plot(H_values, PDR(:, c) * 100, '-o', Color=palette(c, :), ...
        MarkerFaceColor=palette(c, :), LineWidth=1.6, MarkerSize=5, ...
        DisplayName=cases(c).label);
end

% Baseline marker (SF=8, B=62.5, LDRO=off, H=1000)
xline(H_base, ':', Color=[0.4 0.4 0.4], HandleVisibility='off');
i_base = find(H_values == H_base, 1);
plot(H_base, PDR(i_base, 1) * 100, 'o', MarkerSize=10, LineWidth=1.8, ...
    MarkerEdgeColor='k', MarkerFaceColor='none', DisplayName='Baseline');

hold off;
xlabel('Orbital altitude (km)');
ylabel('PDR (%)');
ylim([0 100]);
xlim([min(H_values) max(H_values)]);
legend(Location='northeast');
grid on;
