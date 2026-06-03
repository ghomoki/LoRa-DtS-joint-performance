function y = dBm_to_lin(x_dBm)
%DBM_TO_LIN  Convert a dBm value to linear scale (watts). Vectorized.

y = 10.^((x_dBm - 30) / 10);
end
