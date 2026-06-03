%PDR_DEMO  Smoke-test invocation of packetdeliveryratio for one scenario.
%   Useful for quickly exercising the main pipeline after code changes.

clear;
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

E    = 10;       % Minimum elevation angle  (deg)
B    = 31.25;    % Bandwidth                (kHz)
F_C  = 436.7;    % Carrier frequency        (MHz)
LDRO = true;     % Low data rate optimization
SF   = 10;       % Spreading factor
P_L  = 55;       % Application payload      (bytes)
H    = 560;      % Orbital altitude         (km)

[pdr, L_static, L_dynamic, L_joint, results] = ...
    packetdeliveryratio(E, B, F_C, LDRO, SF, P_L, H);

fprintf('PDR = %.4f over %d packets in the pass.\n', pdr, height(results));
fprintf('  Static  Doppler failures: %d (%.1f%%)\n', sum(L_static),  100*mean(L_static));
fprintf('  Dynamic Doppler failures: %d (%.1f%%)\n', sum(L_dynamic), 100*mean(L_dynamic));
fprintf('  Joint   Doppler failures: %d (%.1f%%)\n', sum(L_joint),   100*mean(L_joint));
fprintf('  Mean P_link             : %.4f\n', mean(results.P_link));
fprintf('  Min link margin (dB)    : %.2f\n', min(results.("Link margin (dB)")));
fprintf('  Max link margin (dB)    : %.2f\n', max(results.("Link margin (dB)")));
