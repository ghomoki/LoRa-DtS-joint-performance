%RICIAN_K_PASS  Visualize Rician K factor across the full elevation range.
%   Plots the Rician fading K factor vs. elevation sweeping from horizon (0°) to zenith (90°).

clear;
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

E = (0 : 0.1 : 90).';
K = rician_K(E);

figure;
hold on;
plot(E, K, '-', LineWidth=2);

% Mark the interpolated Kim et al. (2006) measurements
E_data = [20, 30, 40, 60, 80];
K_data = [3.07, 3.24, 3.60, 5.63, 17.06];
scatter(E_data, K_data, 50, 'filled');

hold off;
xlabel('Elevation (degrees)');
ylabel('Rician K factor');
xlim([0 90]);
grid on;
