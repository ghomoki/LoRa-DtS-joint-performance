%DESIGN_SPACE_HEATMAP  SF vs BW PDR heatmap for the stressed link scenario.
%   Two side-by-side heatmaps:
%     1. LDRO off when not mandatory (the realistic default — LDRO only
%        turned on where the LoRaWAN T_s > 16.38 ms recommendation applies).
%     2. LDRO on everywhere (artificial: shows the Doppler-immunity ceiling
%        if LDRO were always enabled, at the cost of throughput).

clear;
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

% Scenario (matches pdr_stress_demo.m)
E    = 1;        % Minimum elevation angle  (deg)
F_C  = 915;      % Carrier frequency        (MHz)
H    = 1500;     % Orbital altitude         (km)
P_L  = 55;       % Application payload      (bytes)

SF_values = 7:12;
B_values  = [31.25, 62.5, 125, 250, 500];

% LDRO is mandatory when symbol time T_s >= 16.38 ms.
% T_s = 2^SF / B (with B in kHz gives T_s in ms).
[SF_grid, B_grid]  = ndgrid(SF_values, B_values);
T_s_ms             = 2.^SF_grid ./ B_grid;
LDRO_mandatory     = T_s_ms >= 16.38;

n_SF = length(SF_values);
n_B  = length(B_values);

PDR_realistic  = NaN(n_SF, n_B);
PDR_always_on  = NaN(n_SF, n_B);

fprintf('Computing PDR over %dx%d (SF, B) grid for two LDRO modes.\n', n_SF, n_B);
total_cells = n_SF * n_B;
cell_count  = 0;
tic;

for s = 1:n_SF
    for b = 1:n_B
        SF = SF_values(s);
        B  = B_values(b);

        % Mode 1: LDRO off when not mandatory
        rng(0);
        [pdr1, ~, ~, ~, ~] = packetdeliveryratio( ...
            E, B, F_C, LDRO_mandatory(s, b), SF, P_L, H);
        PDR_realistic(s, b) = pdr1;

        % Mode 2: LDRO on everywhere
        rng(0);
        [pdr2, ~, ~, ~, ~] = packetdeliveryratio( ...
            E, B, F_C, true, SF, P_L, H);
        PDR_always_on(s, b) = pdr2;

        cell_count = cell_count + 1;
        if LDRO_mandatory(s, b)
            note = ' (LDRO mandatory)';
        else
            note = '';
        end
        fprintf('  [%2d/%2d] SF=%2d B=%5.2f kHz: realistic=%.4f, always-on=%.4f%s\n', ...
            cell_count, total_cells, SF, B, pdr1, pdr2, note);
    end
end

fprintf('\nElapsed: %.1f s\n', toc);

%% Plot
figure;
tl = tiledlayout(1, 2, TileSpacing='compact', Padding='compact');
title(tl, sprintf( ...
    'Design space exploration: stressed link (F_C=%g MHz, H=%g km, E_{min}=%g°, PL=%d B)', ...
    F_C, H, E, P_L));

nexttile;
plot_pdr_heatmap(SF_values, B_values, PDR_realistic, LDRO_mandatory, ...
    'LDRO off when not mandatory');

nexttile;
plot_pdr_heatmap(SF_values, B_values, PDR_always_on, true(n_SF, n_B), ...
    'LDRO on everywhere');

%% Local functions

function plot_pdr_heatmap(SF, B, PDR, LDRO_on, name)
    imagesc(PDR);
    colormap(parula);
    clim([0 1]);
    cbar = colorbar;
    cbar.Label.String = 'PDR';

    xticks(1:length(B));
    xticklabels(arrayfun(@(b) sprintf('%g', b), B, UniformOutput=false));
    yticks(1:length(SF));
    yticklabels(arrayfun(@(s) sprintf('SF%d', s), SF, UniformOutput=false));
    xlabel('Bandwidth (kHz)');
    ylabel('Spreading factor');
    title(name);

    for s = 1:length(SF)
        for b = 1:length(B)
            if LDRO_on(s, b)
                txt = sprintf('%.3f\nLDRO', PDR(s, b));
            else
                txt = sprintf('%.3f', PDR(s, b));
            end
            if PDR(s, b) > 0.5
                col = 'k';
            else
                col = 'w';
            end
            text(b, s, txt, HorizontalAlignment='center', VerticalAlignment='middle', ...
                Color=col, FontSize=9);
        end
    end
end
