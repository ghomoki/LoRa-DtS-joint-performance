%SWEEP_PDR_VS_FC  PDR vs carrier frequency across typical LoRa bands.
%   Higher F_C makes everything worse simultaneously: Doppler shift, Doppler
%   rate, and path loss all scale with F_C. Slope changes reveal where a
%   given configuration first crosses each loss threshold.

clear;
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

% Baseline
F_C_base  = 915;
H_base    = 1000;
B_base    = 62.5;
SF_base   = 8;
LDRO_base = false;
P_L_base  = 100;
E         = 1;

% Sweep (typical LoRa carrier frequencies)
F_C_values = [433, 868, 915, 1500, 2100, 2400];

cases = struct( ...
    'SF',    {8,     10,    12}, ...
    'B',     {62.5,  125,   250}, ...
    'LDRO',  {false, false, true}, ...
    'label', {'SF=8, B=62.5 kHz, LDRO off', ...
              'SF=10, B=125 kHz, LDRO off', ...
              'SF=12, B=250 kHz, LDRO on'});
palette = [0.00 0.45 0.74; 0.85 0.33 0.10; 0.47 0.67 0.19];

PDR = NaN(length(F_C_values), numel(cases));
fprintf('Sweeping F_C (%d configs × %d points)\n', numel(cases), length(F_C_values));
tic;
for c = 1:numel(cases)
    for k = 1:length(F_C_values)
        rng(0);
        PDR(k, c) = packetdeliveryratio( ...
            E, cases(c).B, F_C_values(k), cases(c).LDRO, cases(c).SF, P_L_base, H_base);
    end
    fprintf('  [%d/%d] %s done\n', c, numel(cases), cases(c).label);
end
fprintf('Elapsed: %.1f s\n', toc);

%% Plot
figure;
hold on;
for c = 1:numel(cases)
    plot(F_C_values, PDR(:, c) * 100, '-o', Color=palette(c, :), ...
        MarkerFaceColor=palette(c, :), LineWidth=1.6, MarkerSize=5, ...
        DisplayName=cases(c).label);
end

% Baseline marker
xline(F_C_base, ':', Color=[0.4 0.4 0.4], HandleVisibility='off');
i_base = find(F_C_values == F_C_base, 1);
plot(F_C_base, PDR(i_base, 1) * 100, 'o', MarkerSize=10, LineWidth=1.8, ...
    MarkerEdgeColor='k', MarkerFaceColor='none', DisplayName='Baseline');

hold off;
xlabel('Carrier frequency (MHz)');
ylabel('PDR (%)');
ylim([0 100]);
xlim([min(F_C_values) max(F_C_values)]);
legend(Location='northeast');
grid on;
