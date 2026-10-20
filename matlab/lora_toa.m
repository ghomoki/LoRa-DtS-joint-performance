function ToA = lora_toa(SF, B, P_L, LDRO, opts)
%LORA_TOA  Compute a LoRa packet's Time on Air.
%   Based on SX127X datasheet, section 4.1.1.6.
%
%   ToA = lora_toa(SF, B, P_L, LDRO) returns the Time on Air (transmission length) for a LoRa
%   packet in milliseconds.

arguments
    SF                      % Spreading factor                  (7..12)            SF 6 not modelled because of special behavior
    B                       % Bandwidth                         (kHz)
    P_L                     % Application payload length        (1..255 bytes)
    LDRO                    % Low data rate optimization off/on (0/1)
    opts.n_preamble = 12    % Preamble length                   (6..65535 symbols)
    opts.IH = 0             % Explicit/implicit header          (0/1)
    opts.CRC = 1            % CRC disabled/enabled              (0/1)
    opts.CR = 1             % Coding rate index                 (1..4)             -> rate 4/5..4/8
    opts.PL_overhead = 0    % Non-application payload length    (bytes)            e.g. LoRaWAN overhead 
end

PL = P_L + opts.PL_overhead;

% B in kHz -> symbol duration T_s in ms
T_s = 2^SF / B;

T_preamble = (opts.n_preamble + 4.25) * T_s;

n_payload = 8 + max( ...
    ceil( (8*PL - 4*SF + 28 + 16*opts.CRC - 20*opts.IH) / (4*(SF - 2*LDRO)) ) ...
    * (opts.CR + 4), 0);

T_payload = n_payload * T_s;

ToA = T_preamble + T_payload;
end
