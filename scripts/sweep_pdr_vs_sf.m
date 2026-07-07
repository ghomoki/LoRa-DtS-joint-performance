%SWEEP_PDR_VS_SF  PDR vs spreading factor, with LDRO comparison.
%   SF has competing effects in the link-budget-inclusive model:
%     - higher SF → better receiver sensitivity (helps margin)
%     - higher SF → longer ToA (more Doppler / fading exposure)
%     - higher SF → tighter dynamic-Doppler threshold
%   LDRO toggling changes the inflection.

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
SF_values = 7:12;

cases = struct( ...
    'B',     {62.5,  62.5,  125,   125}, ...
    'LDRO',  {false, true,  false, true}, ...
    'color', {[0.00 0.45 0.74], [0.00 0.45 0.74], ...
              [0.85 0.33 0.10], [0.85 0.33 0.10]}, ...
    'style', {'-', '--', '-', '--'}, ...
    'label', {'B=62.5 kHz, LDRO off', 'B=62.5 kHz, LDRO on', ...
              'B=125 kHz, LDRO off',  'B=125 kHz, LDRO on'});

PDR = NaN(length(SF_values), numel(cases));

fprintf('Sweeping SF (%d configs × %d points)\n', numel(cases), length(SF_values));
tic;
for c = 1:numel(cases)
    for k = 1:length(SF_values)
        SF = SF_values(k);
        rng(0);
        PDR(k, c) = packetdeliveryratio( ...
            E, cases(c).B, F_C_base, cases(c).LDRO, SF, P_L_base, H_base);
    end
    fprintf('  [%d/%d] %s done\n', c, numel(cases), cases(c).label);
end
fprintf('Elapsed: %.1f s\n', toc);

%% Plot
figure;
hold on;
for c = 1:numel(cases)
    plot(SF_values, PDR(:, c) * 100, cases(c).style, Color=cases(c).color, ...
        Marker='o', MarkerFaceColor=cases(c).color, ...
        LineWidth=1.6, MarkerSize=5, DisplayName=cases(c).label);
end

% Baseline marker (B=62.5, LDRO=off, SF=8)
xline(SF_base, ':', Color=[0.4 0.4 0.4], HandleVisibility='off');
i_base = find(SF_values == SF_base, 1);
plot(SF_base, PDR(i_base, 1) * 100, 'o', MarkerSize=10, LineWidth=1.8, ...
    MarkerEdgeColor='k', MarkerFaceColor='none', DisplayName='Baseline');
hold off;

xlabel('Spreading factor');
ylabel('PDR (%)');
xticks(SF_values);
xlim([min(SF_values) max(SF_values)]);
ylim([0 100]);
legend(Location='northwest');
grid on;
