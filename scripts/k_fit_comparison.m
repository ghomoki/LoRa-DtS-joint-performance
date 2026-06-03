%K_FIT_COMPARISON  Compare curve-fitting methods for Kim et al. (2006) K(E) data.
%   Plots cubic spline, exponential regression, and polynomial regressions of
%   degrees 3, 4, and 5 against Kim's Table II measured points, plus their
%   own published cubic fit (eq. 28) for reference. Helps pick a defensible
%   K(E) model for the link budget.
%
%   Note on polynomial degrees vs. data points: Kim Table II has 5 points.
%     - Degree 3 (4 coeffs): least-squares fit
%     - Degree 4 (5 coeffs): exact interpolation (passes through all points)
%     - Degree 5 (6 coeffs): underdetermined; MATLAB warns and picks one solution

clear;
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

% Kim et al. (2006) Table II measured K values
E_data = [20, 30, 40, 60, 80];
K_data = [3.07, 3.24, 3.60, 5.63, 17.06];

% Evaluation grid, extending beyond the data range to expose extrapolation behaviour
E_fine = 0:0.5:90;

%% Method 1: Cubic spline (interpolating, not regression)
K_spline = interp1(E_data, K_data, E_fine, 'spline', 'extrap');

%% Method 2: Exponential regression  K = a * exp(b * E)
% Linearize via log(K) = log(a) + b*E, then linear fit
p_exp = polyfit(E_data, log(K_data), 1);   % [b, log(a)]
exp_a = exp(p_exp(2));
exp_b = p_exp(1);
K_exp = exp_a * exp(exp_b * E_fine);

%% Method 3-5: Polynomial regression, degrees 3, 4, 5
warn_state = warning('off', 'MATLAB:polyfit:PolyNotUnique');
p3 = polyfit(E_data, K_data, 3);
p4 = polyfit(E_data, K_data, 4);
p5 = polyfit(E_data, K_data, 5);
warning(warn_state);

K_p3 = polyval(p3, E_fine);
K_p4 = polyval(p4, E_fine);
K_p5 = polyval(p5, E_fine);

% Kim's own published cubic fit (eq. 28), for reference
K_kim_eq28 = 0.0002*E_fine.^3 - 0.0157*E_fine.^2 + 0.5430*E_fine - 2.7618;

%% Plot
figure;
hold on;
plot(E_data, K_data, 'ko',  MarkerSize=10, LineWidth=2,   DisplayName='Kim Table II data');
plot(E_fine, K_spline,    '-',  Color=[0 0.45 0.74], LineWidth=1.5, DisplayName='Cubic spline');
plot(E_fine, K_exp,       '-',  Color=[0.47 0.67 0.19], LineWidth=1.5, DisplayName='Exponential a\cdotexp(b\cdotE)');
plot(E_fine, K_p3,        '--', Color=[0.93 0.69 0.13], LineWidth=1.5, DisplayName='Polynomial deg 3 (least squares)');
plot(E_fine, K_p4,        '--', Color=[0.85 0.33 0.10], LineWidth=1.5, DisplayName='Polynomial deg 4 (exact interp.)');
plot(E_fine, K_p5,        '--', Color=[0.49 0.18 0.56], LineWidth=1.5, DisplayName='Polynomial deg 5 (underdetermined)');
plot(E_fine, K_kim_eq28,  ':',  Color=[0.3 0.3 0.3],    LineWidth=1.5, DisplayName='Kim eq. (28) cubic fit');
yline(0, Color=[0.7 0.7 0.7], HandleVisibility='off');
hold off;

xlabel('Elevation angle E [deg]');
ylabel('Rician K-factor');
title('K(E) fitting methods on Kim et al. (2006) Table II data');
legend(Location='northwest');
grid on;
xlim([0 90]);
ylim([-5 50]);

%% Print fit parameters and evaluations at key elevations
fprintf('\n=== Fit parameters ===\n');
fprintf('Exponential:  K = %.4f * exp(%.4f * E)\n', exp_a, exp_b);
fprintf('Poly deg 3 :  '); fprintf('%+ .4g  ', p3); fprintf('\n');
fprintf('Poly deg 4 :  '); fprintf('%+ .4g  ', p4); fprintf('\n');
fprintf('Poly deg 5 :  '); fprintf('%+ .4g  ', p5); fprintf('\n');

fprintf('\n=== K evaluated at key elevations ===\n');
E_eval = [1 5 10 20 30 40 50 60 70 80 85 90];
fprintf('%6s | %8s | %8s | %8s | %8s | %8s\n', ...
    'E(deg)', 'Spline', 'Exp', 'Poly 3', 'Poly 4', 'Poly 5');
fprintf('%s\n', repmat('-', 1, 62));
for E = E_eval
    fprintf('%6d | %8.3f | %8.3f | %8.3f | %8.3f | %8.3f\n', ...
        E, ...
        interp1(E_data, K_data, E, 'spline', 'extrap'), ...
        exp_a * exp(exp_b * E), ...
        polyval(p3, E), ...
        polyval(p4, E), ...
        polyval(p5, E));
end

%% Residuals at the data points (where they should be zero or near-zero)
fprintf('\n=== Residuals at data points (fit - measured) ===\n');
fprintf('%6s | %8s | %8s | %8s | %8s | %8s\n', ...
    'E(deg)', 'Spline', 'Exp', 'Poly 3', 'Poly 4', 'Poly 5');
fprintf('%s\n', repmat('-', 1, 62));
for k = 1:length(E_data)
    E = E_data(k);
    K_true = K_data(k);
    fprintf('%6d | %+8.3f | %+8.3f | %+8.3f | %+8.3f | %+8.3f\n', ...
        E, ...
        interp1(E_data, K_data, E, 'spline', 'extrap') - K_true, ...
        exp_a * exp(exp_b * E) - K_true, ...
        polyval(p3, E) - K_true, ...
        polyval(p4, E) - K_true, ...
        polyval(p5, E) - K_true);
end
