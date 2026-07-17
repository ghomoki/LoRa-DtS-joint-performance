"""LoRa Time on Air, port of lora_toa.m."""

import math


def lora_toa(sf, b_khz, p_l, ldro, *, n_preamble=12, ih=0, crc=1, cr=1,
             pl_overhead=0):
    """Compute a LoRa packet's Time on Air in milliseconds.

    Based on the SX127x datasheet, section 4.1.1.6.

    Parameters
    ----------
    sf : int
        Spreading factor (7..12). SF 6 not modelled because of special
        behavior.
    b_khz : float
        Bandwidth (kHz).
    p_l : int
        Application payload length (1..255 bytes).
    ldro : int or bool
        Low data rate optimization off/on (0/1).
    n_preamble : int
        Preamble length (6..65535 symbols).
    ih : int
        Explicit/implicit header (0/1).
    crc : int
        CRC disabled/enabled (0/1).
    cr : int
        Coding rate index (1..4) -> rate 4/5..4/8.
    pl_overhead : int
        Non-application payload length (bytes), e.g. LoRaWAN overhead.
    """
    pl = p_l + pl_overhead

    # B in kHz -> symbol duration T_s in ms
    t_s = 2 ** sf / b_khz

    t_preamble = (n_preamble + 4.25) * t_s

    n_payload = 8 + max(
        math.ceil((8 * pl - 4 * sf + 28 + 16 * crc - 20 * ih)
                  / (4 * (sf - 2 * ldro))) * (cr + 4),
        0)

    t_payload = n_payload * t_s

    return t_preamble + t_payload
