%SWEEP_PDR_VS_BW  PDR vs LoRa bandwidth, for three spreading factors and
%   both LDRO states. Wider B loosens Doppler thresholds and shortens ToA,
%   but raises the noise floor — these effects fight, so PDR(B) can be
%   non-monotonic. Solid lines: LDRO off. Dashed lines: LDRO on.

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

% Sweep (standard LoRa bandwidths)
B_values = [7.81, 15.63, 31.25, 62.5, 125, 250, 500];

sf_palette = [0.00 0.45 0.74; 0.85 0.33 0.10; 0.47 0.67 0.19];
cases = struct( ...
    'SF',    {8,                8,                10,               10,               12,               12}, ...
    'LDRO',  {false,            true,             false,            true,             false,            true}, ...
    'color', {sf_palette(1,:),  sf_palette(1,:),  sf_palette(2,:),  sf_palette(2,:),  sf_palette(3,:),  sf_palette(3,:)}, ...
    'style', {'-',              '--',             '-',              '--',             '-',              '--'}, ...
    'label', {'SF=8, LDRO off',  'SF=8, LDRO on', ...
              'SF=10, LDRO off', 'SF=10, LDRO on', ...
              'SF=12, LDRO off', 'SF=12, LDRO on'});

PDR = NaN(length(B_values), numel(cases));

fprintf('Sweeping B (%d configs × %d points)\n', numel(cases), length(B_values));
tic;
for c = 1:numel(cases)
    for k = 1:length(B_values)
        rng(0);
        PDR(k, c) = packetdeliveryratio( ...
            E, B_values(k), F_C_base, cases(c).LDRO, cases(c).SF, P_L_base, H_base);
    end
    fprintf('  [%d/%d] %s done\n', c, numel(cases), cases(c).label);
end
fprintf('Elapsed: %.1f s\n', toc);

%% Plot
figure;
hold on;
for c = 1:numel(cases)
    plot(B_values, PDR(:, c) * 100, cases(c).style, Color=cases(c).color, ...
        Marker='o', MarkerFaceColor=cases(c).color, ...
        LineWidth=1.6, MarkerSize=5, DisplayName=cases(c).label);
end

% Baseline marker (SF=8, LDRO=off curve, B=62.5)
xline(B_base, ':', Color=[0.4 0.4 0.4], HandleVisibility='off');
i_base = find(B_values == B_base, 1);
plot(B_base, PDR(i_base, 1) * 100, 'o', MarkerSize=10, LineWidth=1.8, ...
    MarkerEdgeColor='k', MarkerFaceColor='none', DisplayName='Baseline');
hold off;

xlabel('Bandwidth (kHz)');
ylabel('PDR (%)');
set(gca, XScale='log');
xticks(B_values);
xticklabels(arrayfun(@(b) sprintf('%g', b), B_values, UniformOutput=false));
xlim([min(B_values) max(B_values)]);
ylim([0 100]);
legend(Location='northwest');
grid on;
