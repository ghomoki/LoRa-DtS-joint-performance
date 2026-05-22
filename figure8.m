%FIGURE8  Reproduce Figure 8 of Asad Ullah et al. (2024).
%   SF12 PDR vs MAC payload, for various (B, F_C) combinations.
%   Fixed: SF=12, H=560 km, LDRO=on, E_min=1 deg.

clear;

SF   = 12;
H    = 560;
LDRO = true;
E    = 1;

PL_values = 1:5:60;

% (B in kHz, F_C in MHz, label, line style)
cases = {
    125, 433,  'B=125 kHz, F_C=433 MHz',  '-o';
    125, 868,  'B=125 kHz, F_C=868 MHz',  '-s';
    125, 2100, 'B=125 kHz, F_C=2.1 GHz',  '-^';
    250, 2100, 'B=250 kHz, F_C=2.1 GHz',  '--d';
    500, 2100, 'B=500 kHz, F_C=2.1 GHz',  '--v';
};

PDR_matrix = zeros(length(PL_values), size(cases, 1));

for c = 1:size(cases, 1)
    B   = cases{c, 1};
    F_C = cases{c, 2};
    fprintf('Case %d/%d: B=%g kHz, F_C=%g MHz\n', c, size(cases, 1), B, F_C);
    for k = 1:length(PL_values)
        PL = PL_values(k);
        PDR_matrix(k, c) = packetdeliveryratio(E, B, F_C, LDRO, SF, PL, H);
    end
end

figure;
hold on;
for c = 1:size(cases, 1)
    plot(PL_values, PDR_matrix(:, c) * 100, cases{c, 4}, ...
        DisplayName=cases{c, 3}, LineWidth=1.5, MarkerSize=6);
end
hold off;
xlabel('MAC payload [bytes]');
ylabel('Packet Delivery Ratio [%]');
title('Figure 8 reproduction: SF12 PDR vs payload (H=560 km)');
legend(Location='southwest');
grid on;
ylim([0 100]);
xlim([0 60]);
