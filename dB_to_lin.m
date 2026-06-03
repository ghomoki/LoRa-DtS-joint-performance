function y = dB_to_lin(x_dB)
%DB_TO_LIN  Convert a dB value to linear scale. Vectorized.

y = 10.^(x_dB / 10);
end
