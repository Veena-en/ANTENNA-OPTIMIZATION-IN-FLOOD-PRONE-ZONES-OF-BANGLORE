
clc;
clear;
close all;

% RADIO MODEL PARAMETERS
Pt = 30;
Gt = 2;
Gr = 0;
L = 2;
PL0 = 40;
d0 = 0.001;       % 1 metre in km
n = 3;
Pr_threshold = -100;

% DISTANCES IN KM
D = [1 5 10];

% CALCULATIONS
PL = PL0 + 10*n*log10(D/d0);
Pr = Pt + Gt + Gr - L - PL;
covered = Pr >= Pr_threshold;

% DISPLAY RESULTS
fprintf('\nRADIO MODEL VALIDATION\n');
fprintf('-----------------------------------------------------\n');
fprintf('Distance(km)  Path Loss(dB)  Received(dBm)  Coverage\n');
fprintf('-----------------------------------------------------\n');

for k = 1:length(D)
    if covered(k)
        status = 'YES';
    else
        status = 'NO';
    end

    fprintf('%8.1f %15.2f %15.2f %10s\n', ...
        D(k), PL(k), Pr(k), status);
end

% THEORETICAL COVERAGE RADIUS
PL_max = Pt + Gt + Gr - L - Pr_threshold;
radius = d0 * 10^((PL_max - PL0)/(10*n));

fprintf('-----------------------------------------------------\n');
fprintf('Theoretical coverage radius = %.2f km\n', radius);

% GRAPH
distances = linspace(0.01, 10, 500);
PL_curve = PL0 + 10*n*log10(distances/d0);
Pr_curve = Pt + Gt + Gr - L - PL_curve;

figure;
plot(distances, Pr_curve, 'b', 'LineWidth', 2);
hold on;
plot(distances, Pr_threshold*ones(size(distances)), ...
     'r--', 'LineWidth', 1.5);
plot(D, Pr, 'ko', 'MarkerFaceColor', 'k');

xlabel('Distance (km)');
ylabel('Received Power (dBm)');
title('Radio Model Validation');
legend('Received Power', 'Receiver Threshold', ...
       'Test Distances', 'Location', 'southwest');
grid on;

