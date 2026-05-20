classdef toa_test < matlab.unittest.TestCase
%TOA_TEST  Verification of lora_toa against the paper's published ToA values.
%
%   These scenarios are the ToA values printed in the captions of Figs. 4,
%   5, and 7 of Asad Ullah et al. (2024). They are reproduced by the paper's
%   own LoRa_ToA.m (see LoRa_ToA_paper.m in this repo), which sets:
%
%       n_preamble  = 8
%       Coding Rate = 4/5 (CR=1)
%       Header      = explicit (IH=0)
%       CRC         = on (CRC=1)
%       Overhead    = 5 bytes added to the application payload
%       LDRO        = always applied when the flag is set (regardless of
%                     the LoRaWAN T_s > 16.38 ms recommendation)
%
%   Our lora_toa.m uses the same defaults BUT keeps the datasheet-correct
%   preamble constant 4.25 instead of the paper's 4.24 typo. The resulting
%   ToA is therefore ~0.05*T_s larger than the paper's published value.
%   The tolerance of 2 ms absorbs this — worst case (SF=12 at B=31.25)
%   drifts by ~1.3 ms.

    properties (TestParameter)
        scenario = struct( ...
            'A_SF7_B31_25',   struct(SF=7,  B=31.25, P_L=55, LDRO=true, expected=595), ...
            'B_SF10_B31_25',  struct(SF=10, B=31.25, P_L=55, LDRO=true, expected=3285), ...
            'C_SF12_B31_25',  struct(SF=12, B=31.25, P_L=55, LDRO=true, expected=10517), ...
            'D_SF7_B125',     struct(SF=7,  B=125,   P_L=55, LDRO=true, expected=149), ...
            'E_SF10_B125',    struct(SF=10, B=125,   P_L=55, LDRO=true, expected=821), ...
            'F_SF12_B125',    struct(SF=12, B=125,   P_L=55, LDRO=true, expected=2629), ...
            'G_SF12_B62_5',   struct(SF=12, B=62.5,  P_L=55, LDRO=true, expected=5259))
    end

    methods (Test)
        function matchesPaperToA(testCase, scenario)
            actual = lora_toa(scenario.SF, scenario.B, scenario.P_L, scenario.LDRO);
            testCase.verifyEqual(actual, scenario.expected, "AbsTol", 2);
        end
    end
end
