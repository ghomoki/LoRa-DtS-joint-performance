%SWEEP_PDR_VS_PAYLOAD  PDR vs application payload size with link budget.
%   Analogous to Ullah Fig. 8 but link-budget-aware: a longer payload
%   extends the ToA, which both increases dynamic-Doppler exposure and
%   gives more time for the link to dip into a fade.

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

% Sweep
P_L_values = [1 5 10 20 35 55 80 100 130 160 200];

cases = struct( ...
    'SF',    {8,     10,    12}, ...
    'B',     {62.5,  125,   250}, ...
    'LDRO',  {false, false, true}, ...
    'label', {'SF=8, B=62.5 kHz, LDRO off', ...
              'SF=10, B=125 kHz, LDRO off', ...
              'SF=12, B=250 kHz, LDRO on'});
palette = [0.00 0.45 0.74; 0.85 0.33 0.10; 0.47 0.67 0.19];

PDR = NaN(length(P_L_values), numel(cases));
fprintf('Sweeping payload (%d configs × %d points)\n', numel(cases), length(P_L_values));
tic;
for c = 1:numel(cases)
    for k = 1:length(P_L_values)
        rng(0);
        PDR(k, c) = packetdeliveryratio( ...
            E, cases(c).B, F_C_base, cases(c).LDRO, cases(c).SF, P_L_values(k), H_base);
    end
    fprintf('  [%d/%d] %s done\n', c, numel(cases), cases(c).label);
end
fprintf('Elapsed: %.1f s\n', toc);

%% Plot
figure;
hold on;
for c = 1:numel(cases)
    plot(P_L_values, PDR(:, c) * 100, '-o', Color=palette(c, :), ...
        MarkerFaceColor=palette(c, :), LineWidth=1.6, MarkerSize=5, ...
        DisplayName=cases(c).label);
end

% Baseline marker
xline(P_L_base, ':', Color=[0.4 0.4 0.4], HandleVisibility='off');
i_base = find(P_L_values == P_L_base, 1);
plot(P_L_base, PDR(i_base, 1) * 100, 'o', MarkerSize=10, LineWidth=1.8, ...
    MarkerEdgeColor='k', MarkerFaceColor='none', DisplayName='Baseline');

hold off;
xlabel('Application payload (bytes)');
ylabel('PDR (%)');
ylim([0 100]);
xlim([min(P_L_values) max(P_L_values)]);
legend(Location='northeast');
grid on;
