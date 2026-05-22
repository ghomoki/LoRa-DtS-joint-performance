%FIGURE10  Reproduce Figure 10 of Asad Ullah et al. (2024).
%   SF12 PDR vs orbital height, for various (B, F_C) combinations.
%   Fixed: SF=12, PL=59 bytes, LDRO=on, E_min=1 deg.
%   The B=125 kHz curves are swept at finer H resolution than B=250 kHz.

clear;

SF   = 12;
PL   = 59;
LDRO = true;
E    = 1;

H_fine   = 570:20:1500;
H_coarse = 570:50:1500;

% (B in kHz, F_C in MHz, label, line style, H sweep)
cases = {
    125, 433,  'B=125 kHz, F_C=433 MHz',  '-o',  H_fine;
    125, 868,  'B=125 kHz, F_C=868 MHz',  '-s',  H_fine;
    125, 2100, 'B=125 kHz, F_C=2.1 GHz',  '-^',  H_fine;
    250, 433,  'B=250 kHz, F_C=433 MHz',  '--o', H_coarse;
    250, 868,  'B=250 kHz, F_C=868 MHz',  '--s', H_coarse;
    250, 2100, 'B=250 kHz, F_C=2.1 GHz',  '--^', H_coarse;
};

PDR_curves = cell(size(cases, 1), 1);

for c = 1:size(cases, 1)
    B   = cases{c, 1};
    F_C = cases{c, 2};
    H_values = cases{c, 5};
    fprintf('Case %d/%d: B=%g kHz, F_C=%g MHz (%d points)\n', ...
        c, size(cases, 1), B, F_C, numel(H_values));
    PDR = zeros(size(H_values));
    for k = 1:length(H_values)
        H = H_values(k);
        PDR(k) = packetdeliveryratio(E, B, F_C, LDRO, SF, PL, H);
    end
    PDR_curves{c} = PDR;
end

figure;
hold on;
for c = 1:size(cases, 1)
    plot(cases{c, 5}, PDR_curves{c} * 100, cases{c, 4}, ...
        DisplayName=cases{c, 3}, LineWidth=1.5, MarkerSize=6);
end
hold off;
xlabel('Satellite orbital height [km]');
ylabel('Packet Delivery Ratio [%]');
title('Figure 10 reproduction: SF12 PDR vs orbital height (PL=59 bytes)');
legend(Location='southeast');
grid on;
ylim([0 100]);
xlim([570 1500]);
