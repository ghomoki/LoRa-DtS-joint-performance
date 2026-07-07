%PARETO_FRONT  PDR vs bit rate Pareto front for the stressed link scenario.
%   Discrete (SF, B, LDRO) configurations in the design space, plotted in
%   (PDR, bit rate) space. Pareto-optimal points are highlighted; dominated
%   points are faded for context.
%
%   Coding rate is fixed at 4/5 throughout (see MODEL_NOTES on why).
%   LDRO is the only third-axis knob: mandatory in cells where the
%   LoRaWAN symbol-time recommendation applies, optional elsewhere.

clear;
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

% Labels: useful for paper supplementary; turn off for the small abstract
% figure where the Pareto markers are close enough that text overlaps.
show_labels = false;

% Scenario (matches pdr_stress_demo.m and design_space_heatmap.m)
E    = 1;
F_C  = 915;
H    = 1000;
P_L  = 100;
CR   = 1;   % Coding rate index (4/5); fixed throughout, see MODEL_NOTES

SF_values = 7:12;
B_values  = [31.25, 62.5, 125, 250, 500];

% LDRO is mandatory when symbol time T_s >= 16.38 ms.
[SF_grid, B_grid] = ndgrid(SF_values, B_values);
T_s_ms            = 2.^SF_grid ./ B_grid;
LDRO_mandatory    = T_s_ms >= 16.38;

n_SF = length(SF_values);
n_B  = length(B_values);

%% Collect all candidate (SF, B, LDRO) points and run the simulator
% For LDRO-mandatory cells: one point with LDRO=true
% For LDRO-optional cells:  two points (LDRO=true and LDRO=false)

points = struct('SF', {}, 'B', {}, 'LDRO', {}, 'PDR', {}, 'bit_rate', {});
fprintf('Computing PDR for %d (SF, B, LDRO) configurations.\n', ...
    nnz(LDRO_mandatory) + 2*nnz(~LDRO_mandatory));
tic;

idx = 0;
for s = 1:n_SF
    for b = 1:n_B
        SF = SF_values(s);
        B  = B_values(b);

        if LDRO_mandatory(s, b)
            LDRO_choices = true;
        else
            LDRO_choices = [false, true];
        end

        for LDRO = LDRO_choices
            rng(0);
            [pdr, ~, ~, ~, ~] = packetdeliveryratio(E, B, F_C, LDRO, SF, P_L, H);

            % LoRa bit rate: (SF - 2*LDRO) effective bits per symbol,
            % B chips/s per symbol, 2^SF chips per symbol, factor 4/(4+CR)
            % for forward error correction.
            bit_rate = (SF - 2*LDRO) * (B * 1e3) * (4/(4+CR)) / 2^SF;

            idx = idx + 1;
            points(idx).SF       = SF;
            points(idx).B        = B;
            points(idx).LDRO     = LDRO;
            points(idx).PDR      = pdr;
            points(idx).bit_rate = bit_rate;

            fprintf('  [%2d] SF=%2d B=%6.2f LDRO=%-5s : PDR=%.4f, rate=%6.0f bps\n', ...
                idx, SF, B, mat2str(LDRO), pdr, bit_rate);
        end
    end
end

fprintf('\nElapsed: %.1f s\n', toc);

%% Pareto dominance: a point is Pareto-optimal if no other point has
% both higher PDR and higher bit rate (with at least one strictly higher).
n_pts    = numel(points);
PDR_arr  = [points.PDR];
rate_arr = [points.bit_rate];
is_pareto = true(1, n_pts);
for i = 1:n_pts
    for j = 1:n_pts
        if i == j
            continue;
        end
        if PDR_arr(j) >= PDR_arr(i) && rate_arr(j) >= rate_arr(i) ...
                && (PDR_arr(j) > PDR_arr(i) || rate_arr(j) > rate_arr(i))
            is_pareto(i) = false;
            break;
        end
    end
end

% Drop unusable points: configurations with PDR below 1% aren't real
% design choices, even if they're technically Pareto-optimal at their rate.
PDR_floor = 0.01;
viable    = PDR_arr > PDR_floor & rate_arr > 0;
is_pareto = is_pareto & viable;

fprintf('\n%d Pareto-optimal configurations:\n', nnz(is_pareto));
for i = find(is_pareto)
    fprintf('  SF=%2d B=%6.2f LDRO=%-5s : PDR=%.4f, rate=%6.0f bps, goodput=%6.0f bps\n', ...
        points(i).SF, points(i).B, mat2str(points(i).LDRO), ...
        points(i).PDR, points(i).bit_rate, points(i).PDR * points(i).bit_rate);
end

%% Plot
figure;
hold on;

% Colors by SF (turbo — perceptually uniform AND vivid at every index,
% unlike parula whose pale yellow top end vanishes at low alpha).
% Markers by BW; fill style by LDRO.
sf_colors  = turbo(n_SF);
bw_markers = {'o', 's', '^', 'd', 'v'};

% Plot dominated points first (faded, no label)
for i = 1:n_pts
    if ~viable(i) || is_pareto(i)
        continue;
    end
    s_idx = find(SF_values == points(i).SF, 1);
    b_idx = find(B_values  == points(i).B,  1);
    plot_marker(points(i), sf_colors(s_idx,:), bw_markers{b_idx}, ...
        false, 'MarkerSize', 4, 'Alpha', 0.55);
end

% Plot Pareto-optimal points on top (bold, optionally labelled)
for i = find(is_pareto)
    s_idx = find(SF_values == points(i).SF, 1);
    b_idx = find(B_values  == points(i).B,  1);
    plot_marker(points(i), sf_colors(s_idx,:), bw_markers{b_idx}, ...
        true, 'MarkerSize', 8, 'Alpha', 1.0);
    if show_labels                                          %#ok<UNRCH>
        if points(i).LDRO
            ldro_tag = '+L';
        else
            ldro_tag = '';
        end
        label = sprintf(' %d/%g%s', points(i).SF, points(i).B, ldro_tag);
        text(points(i).bit_rate, points(i).PDR * 100, label, ...
            VerticalAlignment='middle', FontSize=7);
    end
end

% Baseline highlight: surround the (SF=8, B=62.5 kHz, LDRO off) point with
% a black circle, drawn on top of everything else.
SF_base   = 8;
B_base    = 62.5;
LDRO_base = false;
i_base = find([points.SF] == SF_base & [points.B] == B_base & ...
              [points.LDRO] == LDRO_base, 1);
if ~isempty(i_base)
    plot(points(i_base).bit_rate, points(i_base).PDR * 100, 'o', ...
        MarkerSize=16, MarkerEdgeColor='k', MarkerFaceColor='none', ...
        LineWidth=1.5);
end

set(gca, XScale='log');
xlabel('Bit rate (bps)');
ylabel('PDR (%)');
grid on;
xlim([90 2e4]);
ylim([0 100]);

% Synthetic legend entries: SF colors + BW markers + LDRO fill + baseline
n_legend = n_SF + n_B + 3;
legend_handles = gobjects(1, n_legend);
legend_labels  = cell(1, n_legend);
k = 0;
for s_idx = 1:n_SF
    k = k + 1;
    legend_handles(k) = plot(NaN, NaN, 's', MarkerFaceColor=sf_colors(s_idx,:), ...
        MarkerEdgeColor=sf_colors(s_idx,:), MarkerSize=8);
    legend_labels{k}  = sprintf('SF%d', SF_values(s_idx));
end
for b_idx = 1:n_B
    k = k + 1;
    legend_handles(k) = plot(NaN, NaN, bw_markers{b_idx}, MarkerFaceColor='k', ...
        MarkerEdgeColor='k', MarkerSize=8);
    legend_labels{k}  = sprintf('B=%g kHz', B_values(b_idx));
end
k = k + 1;
legend_handles(k) = plot(NaN, NaN, 'o', MarkerFaceColor='k', MarkerEdgeColor='k', MarkerSize=8);
legend_labels{k}  = 'LDRO on';
k = k + 1;
legend_handles(k) = plot(NaN, NaN, 'o', MarkerFaceColor='w', MarkerEdgeColor='k', MarkerSize=8);
legend_labels{k}  = 'LDRO off';
k = k + 1;
legend_handles(k) = plot(NaN, NaN, 'o', MarkerFaceColor='none', MarkerEdgeColor='k', ...
    MarkerSize=14, LineWidth=1.5);
legend_labels{k}  = 'Baseline';

legend(legend_handles, legend_labels, Location='eastoutside', NumColumns=1);
hold off;

%% Local function: plot a single point with chosen styling
function plot_marker(pt, color, marker, is_pareto_pt, varargin)
    p = inputParser;
    addParameter(p, 'MarkerSize', 8);
    addParameter(p, 'Alpha', 1.0);
    parse(p, varargin{:});

    if pt.LDRO
        face = color;
    else
        face = 'w';
    end

    % Edge color always carries SF so hollow markers stay identifiable.
    % Pareto vs dominated is encoded by line width + size + alpha.
    edge_color = color;
    if is_pareto_pt
        line_width = 1.8;
    else
        line_width = 0.6;
    end

    h = scatter(pt.bit_rate, pt.PDR * 100, ...
        p.Results.MarkerSize^2, ...
        marker, ...
        MarkerEdgeColor=edge_color, ...
        MarkerFaceColor=face, ...
        LineWidth=line_width);

    if p.Results.Alpha < 1
        h.MarkerFaceAlpha = p.Results.Alpha;
        h.MarkerEdgeAlpha = p.Results.Alpha;
    end
end
