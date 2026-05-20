function ToA = lora_toa(SF, B, P_L, LDRO, opts)
%LORA_TOA Compute LoRa Time on Air per SX127x datasheet.
%
%   ToA = lora_toa(SF, B, P_L, LDRO) returns the Time on Air in
%   milliseconds for a LoRa frame, using the formula from the
%   SX1276/77/78/79 datasheet, section 4.1.1.6.
%
%   Inputs:
%     SF    Spreading factor (7..12)
%     B     Bandwidth (kHz)
%     P_L   Application payload length (bytes); MAC overhead is added
%           internally via the PL_overhead option.
%     LDRO  Low Data Rate Optimization flag (logical or 0/1)
%
%   Name-value options (defaults match the paper's LoRa_ToA.m, except the
%   preamble constant is the datasheet-correct 4.25 rather than the paper's
%   4.24 typo):
%     n_preamble  Preamble length in symbols (default 8, LoRaWAN default)
%     IH          1 = implicit header, 0 = explicit header (default 0)
%     CRC         1 = CRC enabled, 0 = disabled (default 1)
%     CR          Coding rate index 1..4 -> 4/5..4/8 (default 1)
%     PL_overhead Bytes added to P_L before the formula (default 5,
%                 matches the paper's LoRaWAN-style MAC overhead)

arguments
    SF
    B
    P_L
    LDRO
    opts.n_preamble = 8
    opts.IH = 0
    opts.CRC = 1
    opts.CR = 1
    opts.PL_overhead = 5
end

PL = P_L + opts.PL_overhead;

% B in kHz, so T_s comes out in ms directly
T_s = 2^SF / B;

T_preamble = (opts.n_preamble + 4.25) * T_s;

n_payload = 8 + max( ...
    ceil( (8*PL - 4*SF + 28 + 16*opts.CRC - 20*opts.IH) / (4*(SF - 2*LDRO)) ) ...
    * (opts.CR + 4), 0);

T_payload = n_payload * T_s;

ToA = T_preamble + T_payload;
end
