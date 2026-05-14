clear;

E = 10;
B = 31.25;
F_C = 436.7;
LDRO = true;
SF = 7;
P_L = 55;
H = 560;

[pdr, L_s, L_d, L_j, results] = packetdeliveryratio(E, B, F_C, LDRO, SF, P_L, H);
pdr