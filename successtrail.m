

clear;
clc;
close all;

%% 1. STUDY AREA — KEEP THESE BOUNDARIES FIXED
WEST  = 77.490;
EAST  = 77.710;
SOUTH = 12.850;
NORTH = 13.130;

lon0 = 77.600;
lat0 = 12.990;

scaleX = 111.320*cosd(lat0);
scaleY = 111.320;

width_km  = (EAST-WEST)*scaleX;
height_km = (NORTH-SOUTH)*scaleY;

fprintf('STUDY AREA: BELANDUR / BENGALURU REGION\n');
fprintf('Width: %.2f km | Height: %.2f km\n', ...
        width_km, height_km);

%% 2. RADIO MODEL
Pt = 30;           % Transmit power (dBm)
Gt = 2;            % Transmit antenna gain (dBi)
Gr = 0;            % Receive antenna gain (dBi)
L  = 2;            % System losses (dB)

PL0 = 40;          % Path loss at reference distance
d0 = 0.001;        % Reference distance (km)
n = 3;             % Path-loss exponent
threshold = -100;  % Minimum received signal (dBm)

maxPL = Pt + Gt + Gr - L - threshold;
coverage_km = d0 * 10^((maxPL-PL0)/(10*n));

fprintf('Calculated coverage radius: %.3f km\n', coverage_km);

%% 3. LOAD FLOOD-RELATED KML FILES
lowFile = '8e87a2fc-e014-4c6e-81f1-d5cb4db57a46.kml';
proneFile = '00fb1229-dcfd-4f59-813f-885e0c629add (1).kml';
vulnerableFile = '6b3c63b0-f461-4e9c-a2c2-006f734c5b41 (1).kml';
geoFile = 'bengaluru_flood_zones.geojson';

if exist(geoFile, 'file') == 0
    error('GeoJSON file not found: %s', geoFile);
end

if exist(lowFile, 'file') == 0
    error('Low-lying KML not found: %s', lowFile);
end

if exist(proneFile, 'file') == 0
    error('Flood-prone KML not found: %s', proneFile);
end

if exist(vulnerableFile, 'file') == 0
    error('Flood-vulnerable KML not found: %s', vulnerableFile);
end

%% 4. READ LOW-LYING LOCATIONS
raw = fileread(lowFile);
blocks = regexp(raw, ...
    '<coordinates[^>]*>(.*?)</coordinates>', 'tokens');

lowLon = [];
lowLat = [];

for b = 1:length(blocks)
    entries = regexp(strtrim(blocks{b}{1}), '\s+', 'split');

    for j = 1:length(entries)
        vals = strsplit(entries{j}, ',');

        if length(vals) >= 2
            x = str2double(vals{1});
            y = str2double(vals{2});

            if isfinite(x) && isfinite(y) && ...
               x >= WEST && x <= EAST && ...
               y >= SOUTH && y <= NORTH
                lowLon(end+1,1) = x;
                lowLat(end+1,1) = y;
            end
        end
    end
end

%% 5. READ FLOOD-PRONE LOCATIONS
raw = fileread(proneFile);
blocks = regexp(raw, ...
    '<coordinates[^>]*>(.*?)</coordinates>', 'tokens');

proneLon = [];
proneLat = [];

for b = 1:length(blocks)
    entries = regexp(strtrim(blocks{b}{1}), '\s+', 'split');

    for j = 1:length(entries)
        vals = strsplit(entries{j}, ',');

        if length(vals) >= 2
            x = str2double(vals{1});
            y = str2double(vals{2});

            if isfinite(x) && isfinite(y) && ...
               x >= WEST && x <= EAST && ...
               y >= SOUTH && y <= NORTH
                proneLon(end+1,1) = x;
                proneLat(end+1,1) = y;
            end
        end
    end
end

%% 6. READ FLOOD-VULNERABLE LOCATIONS
raw = fileread(vulnerableFile);
blocks = regexp(raw, ...
    '<coordinates[^>]*>(.*?)</coordinates>', 'tokens');

vulnLon = [];
vulnLat = [];

for b = 1:length(blocks)
    entries = regexp(strtrim(blocks{b}{1}), '\s+', 'split');

    for j = 1:length(entries)
        vals = strsplit(entries{j}, ',');

        if length(vals) >= 2
            x = str2double(vals{1});
            y = str2double(vals{2});

            if isfinite(x) && isfinite(y) && ...
               x >= WEST && x <= EAST && ...
               y >= SOUTH && y <= NORTH
                vulnLon(end+1,1) = x;
                vulnLat(end+1,1) = y;
            end
        end
    end
end

fprintf('\nDATA LOADED\n');
fprintf('Low-lying locations: %d\n', length(lowLon));
fprintf('Flood-prone locations: %d\n', length(proneLon));
fprintf('Flood-vulnerable locations: %d\n', length(vulnLon));

if isempty(proneLon)
    error('No flood-prone points found inside the study area.');
end


%% 7. CONVERT ALL DATASETS TO LOCAL KM COORDINATES

px = (proneLon-lon0)*scaleX;
py = (proneLat-lat0)*scaleY;

lx = (lowLon-lon0)*scaleX;
ly = (lowLat-lat0)*scaleY;

vx = (vulnLon-lon0)*scaleX;
vy = (vulnLat-lat0)*scaleY;

% Combine the point datasets for candidate-site generation.
allX = [px; lx; vx];
allY = [py; ly; vy];

fprintf('\nMapped point entries: %d\n',length(allX));

%% 8. GENERATE CANDIDATE TRANSMITTER SITES

% Keep the exact same study-area boundaries.
gx = 0:0.5:width_km;
gy = 0:0.5:height_km;

[GX,GY] = meshgrid(gx,gy);

cx = GX(:);
cy = GY(:);

% Keep sites within 3 km of at least one mapped point
% from ANY of the three datasets.
nearPoint = false(size(cx));

for i = 1:length(allX)
    nearPoint = nearPoint | ...
        ((cx-allX(i)).^2 + (cy-allY(i)).^2 <= 9);
end

cx = cx(nearPoint);
cy = cy(nearPoint);

if isempty(cx)
    error('No candidate transmitter sites found.');
end

fprintf('Candidate sites generated: %d\n',length(cx));

%% 9. BUILD COVERAGE MATRICES

% Each row is a candidate site.
% Each column is one mapped point entry.

Cprone = false(length(cx),length(px));
Clow = false(length(cx),length(lx));
Cvuln = false(length(cx),length(vx));

for k = 1:length(cx)

    d = sqrt((px-cx(k)).^2 + (py-cy(k)).^2);
    Cprone(k,:) = (d <= coverage_km)';

    d = sqrt((lx-cx(k)).^2 + (ly-cy(k)).^2);
    Clow(k,:) = (d <= coverage_km)';

    d = sqrt((vx-cx(k)).^2 + (vy-cy(k)).^2);
    Cvuln(k,:) = (d <= coverage_km)';

end

% Priority weighting:
% Flood-prone entries receive greater weight.
% Other datasets contribute to the overall score too.
C = [Cprone, Clow, Cvuln];

weights = [ ...
    10*ones(1,length(px)), ...
     ones(1,length(lx)), ...
     ones(1,length(vx)) ];

weightedC = double(C).*repmat(weights,length(cx),1);

%% 10. MULTIPLE-START ROBUST TRANSMITTER SEARCH

% Search for 3 distinct sites.
% Objective: maximise the WORST-CASE weighted coverage
% when any one transmitter fails.
%
% Multiple starting arrangements reduce dependence on
% the original greedy solution. This is a heuristic, not
% a guarantee of the global optimum.

numTX = 3;
numStarts = 20;
maxIterations = 10;

bestSet = [];
bestWorst = -inf;
bestNormal = -inf;

rand('seed',42);

for start = 1:numStarts

    % Build a different greedy starting arrangement.
    selected = zeros(1,numTX);
    covered = false(1,size(C,2));

    for t = 1:numTX

        scores = sum( ...
            weightedC(:,~covered),2);

        if any(selected > 0)
            scores(selected(selected>0)) = -inf;
        end

        % Add a small random perturbation to explore
        % alternative choices among similar candidates.
        scores = scores + 0.05*rand(size(scores));

        [~,best] = max(scores);

        selected(t) = best;
        covered = covered | C(best,:);
    end

    % Local search: replace one site at a time.
    for iteration = 1:maxIterations

        changed = false;

        for slot = 1:numTX

            currentWorst = -inf;
            currentNormal = -inf;

            for failed = 1:numTX
                survivors = selected;
                survivors(failed) = [];

                scenario = any(C(survivors,:),1);

                score = sum(weights(scenario));

                currentWorst = min(currentWorst,score);
            end

            currentNormal = sum(weights(any(C(selected,:),1)));

            bestCandidate = selected(slot);
            bestTrialWorst = currentWorst;
            bestTrialNormal = currentNormal;

            % Evaluate alternative positions for this slot.
            for k = 1:length(cx)

                trial = selected;
                trial(slot) = k;

                if length(unique(trial)) < numTX
                    continue;
                end

                trialWorst = inf;

                for failed = 1:numTX

                    survivors = trial;
                    survivors(failed) = [];

                    scenario = any(C(survivors,:),1);

                    trialScore = sum(weights(scenario));
                    trialWorst = min(trialWorst,trialScore);
                end

                trialNormal = sum(weights(any(C(trial,:),1)));

                if trialWorst > bestTrialWorst || ...
                   (trialWorst == bestTrialWorst && ...
                    trialNormal > bestTrialNormal)

                    bestTrialWorst = trialWorst;
                    bestTrialNormal = trialNormal;
                    bestCandidate = k;
                end
            end

            if bestCandidate ~= selected(slot)
                selected(slot) = bestCandidate;
                changed = true;
            end
        end

        if ~changed
            break;
        end
    end

    % Evaluate the finished arrangement.
    trialWorst = inf;

    for failed = 1:numTX
        survivors = selected;
        survivors(failed) = [];

        scenario = any(C(survivors,:),1);
        trialWorst = min(trialWorst,sum(weights(scenario)));
    end

    trialNormal = sum(weights(any(C(selected,:),1)));

    fprintf('Start %d: worst-case weighted score %.0f\n', ...
        start,trialWorst);

    if trialWorst > bestWorst || ...
       (trialWorst == bestWorst && trialNormal > bestNormal)

        bestWorst = trialWorst;
        bestNormal = trialNormal;
        bestSet = selected;
    end
end

selected = bestSet;

txX = cx(selected);
txY = cy(selected);

fprintf('\nBest arrangement selected.\n');

%% 11. NORMAL COVERAGE FOR ALL THREE DATASETS

normalProne = any(Cprone(selected,:),1);
normalLow = any(Clow(selected,:),1);
normalVuln = any(Cvuln(selected,:),1);

fprintf('\n========== ALL TRANSMITTERS WORKING ==========\n');

fprintf('Flood-prone: %d / %d (%.2f%%)\n', ...
    sum(normalProne),length(px), ...
    100*sum(normalProne)/length(px));

fprintf('Low-lying: %d / %d (%.2f%%)\n', ...
    sum(normalLow),length(lx), ...
    100*sum(normalLow)/length(lx));

fprintf('Flood-vulnerable: %d / %d (%.2f%%)\n', ...
    sum(normalVuln),length(vx), ...
    100*sum(normalVuln)/length(vx));

%% 12. TEST EACH TRANSMITTER FAILURE

failureProne = zeros(1,numTX);
failureLow = zeros(1,numTX);
failureVuln = zeros(1,numTX);

fprintf('\n========== SINGLE TRANSMITTER FAILURE ==========\n');

for failed = 1:numTX

    survivors = selected;
    survivors(failed) = [];

    cp = any(Cprone(survivors,:),1);
    cl = any(Clow(survivors,:),1);
    cv = any(Cvuln(survivors,:),1);

    failureProne(failed) = sum(cp);
    failureLow(failed) = sum(cl);
    failureVuln(failed) = sum(cv);

    fprintf('\nTX%d failed:\n',failed);

    fprintf('Flood-prone: %d / %d (%.2f%%)\n', ...
        sum(cp),length(px),100*sum(cp)/length(px));

    fprintf('Low-lying: %d / %d (%.2f%%)\n', ...
        sum(cl),length(lx),100*sum(cl)/length(lx));

    fprintf('Flood-vulnerable: %d / %d (%.2f%%)\n', ...
        sum(cv),length(vx),100*sum(cv)/length(vx));
end

%% 13. FIND AN EMERGENCY TRANSMITTER

% Choose the fourth site that maximises the minimum
% weighted coverage across all three failure scenarios.

bestEmergency = 0;
bestEmergencyWorst = -inf;
bestEmergencyNormal = -inf;

for k = 1:length(cx)

    if any(selected == k)
        continue;
    end

    scenarioScores = zeros(1,numTX);

    for failed = 1:numTX

        survivors = selected;
        survivors(failed) = [];

        scenario = any(C([survivors,k],:),1);

        scenarioScores(failed) = sum(weights(scenario));
    end

    trialWorst = min(scenarioScores);
    trialNormal = sum(weights(any(C([selected,k],:),1)));

    if trialWorst > bestEmergencyWorst || ...
       (trialWorst == bestEmergencyWorst && ...
        trialNormal > bestEmergencyNormal)

        bestEmergencyWorst = trialWorst;
        bestEmergencyNormal = trialNormal;
        bestEmergency = k;
    end
end

emergencyX = cx(bestEmergency);
emergencyY = cy(bestEmergency);

emergencyLon = lon0 + emergencyX/scaleX;
emergencyLat = lat0 + emergencyY/scaleY;

fprintf('\n========== EMERGENCY TRANSMITTER ==========\n');
fprintf('Worst-case weighted score with emergency TX: %.0f\n', ...
    bestEmergencyWorst);

for failed = 1:numTX

    survivors = selected;
    survivors(failed) = [];

    cp = any(Cprone([survivors,bestEmergency],:),1);
    cl = any(Clow([survivors,bestEmergency],:),1);
    cv = any(Cvuln([survivors,bestEmergency],:),1);

    fprintf('\nTX%d failed, emergency TX active:\n',failed);

    fprintf('Flood-prone: %d / %d (%.2f%%)\n', ...
        sum(cp),length(px),100*sum(cp)/length(px));

    fprintf('Low-lying: %d / %d (%.2f%%)\n', ...
        sum(cl),length(lx),100*sum(cl)/length(lx));

    fprintf('Flood-vulnerable: %d / %d (%.2f%%)\n', ...
        sum(cv),length(vx),100*sum(cv)/length(vx));
end

%% 14. REPORT TRANSMITTER COORDINATES

txLon = lon0 + txX/scaleX;
txLat = lat0 + txY/scaleY;

fprintf('\n========== PROPOSED TRANSMITTER LOCATIONS ==========\n');

for t = 1:numTX
    fprintf('TX%d: Latitude %.6f, Longitude %.6f\n', ...
        t,txLat(t),txLon(t));
end

fprintf('Emergency TX: Latitude %.6f, Longitude %.6f\n', ...
    emergencyLat,emergencyLon);

%% 15. PLOT TRANSMITTERS AND FLOOD-RELATED POINTS

figure('Name','Flood Communication Coverage');
hold on;
grid on;
axis equal;

h1 = plot(proneLon,proneLat,'r.','MarkerSize',13);
h2 = plot(lowLon,lowLat,'b.','MarkerSize',8);
h3 = plot(vulnLon,vulnLat,'m.','MarkerSize',8);

theta = linspace(0,2*pi,200);

for t = 1:numTX
    circleLon = txLon(t) + ...
        (coverage_km/scaleX)*cos(theta);
    circleLat = txLat(t) + ...
        (coverage_km/scaleY)*sin(theta);

    plot(circleLon,circleLat,'g-','LineWidth',1.5);
end

circleLon = emergencyLon + ...
    (coverage_km/scaleX)*cos(theta);
circleLat = emergencyLat + ...
    (coverage_km/scaleY)*sin(theta);

plot(circleLon,circleLat,'c--','LineWidth',2);

h4 = plot(txLon,txLat,'kp','MarkerSize',14, ...
    'MarkerFaceColor','y');

h5 = plot(emergencyLon,emergencyLat,'ks', ...
    'MarkerSize',12,'MarkerFaceColor','c');

xlim([WEST EAST]);
ylim([SOUTH NORTH]);

xlabel('Longitude (degrees)');
ylabel('Latitude (degrees)');
title('Flood Communication: Optimised Transmitter Sites');

legend([h1,h2,h3,h4,h5], ...
    'Flood-prone','Low-lying','Flood-vulnerable', ...
    'Three transmitters','Emergency transmitter', ...
    'Location','northeast');

hold off;

%% 16. SAVE RESULTS

locations = [txLon(:),txLat(:);emergencyLon,emergencyLat];

csvwrite('optimised_transmitter_locations.csv',locations);

fprintf('\nOptimisation complete.\n');
fprintf('Coordinates saved to optimised_transmitter_locations.csv\n');




%% 17. COVERAGE DIAGNOSTIC MAP
% Uses the existing variables from the optimisation script.
% Study-area boundaries and 1 km radius remain unchanged.

% Four transmitter coordinates from the latest optimisation
diagTxLon = [txLon(:); emergencyLon];
diagTxLat = [txLat(:); emergencyLat];

% Convert mapped locations into latitude/longitude arrays
diagProneLon = proneLon(:);
diagProneLat = proneLat(:);

diagLowLon = lowLon(:);
diagLowLat = lowLat(:);

diagVulnLon = vulnLon(:);
diagVulnLat = vulnLat(:);

%% 17A. NEAREST TRANSMITTER DISTANCES

% Flood-prone locations
distProne = zeros(length(diagProneLon),4);

for t = 1:4
    dx = (diagProneLon-diagTxLon(t))*scaleX;
    dy = (diagProneLat-diagTxLat(t))*scaleY;
    distProne(:,t) = sqrt(dx.^2 + dy.^2);
end

nearestProne = min(distProne,[],2);
coveredProne = nearestProne <= coverage_km;

% Low-lying locations
distLow = zeros(length(diagLowLon),4);

for t = 1:4
    dx = (diagLowLon-diagTxLon(t))*scaleX;
    dy = (diagLowLat-diagTxLat(t))*scaleY;
    distLow(:,t) = sqrt(dx.^2 + dy.^2);
end

nearestLow = min(distLow,[],2);
coveredLow = nearestLow <= coverage_km;

% Flood-vulnerable locations
distVuln = zeros(length(diagVulnLon),4);

for t = 1:4
    dx = (diagVulnLon-diagTxLon(t))*scaleX;
    dy = (diagVulnLat-diagTxLat(t))*scaleY;
    distVuln(:,t) = sqrt(dx.^2 + dy.^2);
end

nearestVuln = min(distVuln,[],2);
coveredVuln = nearestVuln <= coverage_km;

%% 17B. PRINT DIAGNOSTIC SUMMARY

fprintf('\n========== COVERAGE DIAGNOSTICS ==========\n');

fprintf('Flood-prone covered: %d / %d (%.2f%%)\n', ...
    sum(coveredProne),length(coveredProne), ...
    100*sum(coveredProne)/length(coveredProne));

fprintf('Flood-prone uncovered: %d\n',sum(~coveredProne));

fprintf('Low-lying covered: %d / %d (%.2f%%)\n', ...
    sum(coveredLow),length(coveredLow), ...
    100*sum(coveredLow)/length(coveredLow));

fprintf('Low-lying uncovered: %d\n',sum(~coveredLow));

fprintf('Flood-vulnerable covered: %d / %d (%.2f%%)\n', ...
    sum(coveredVuln),length(coveredVuln), ...
    100*sum(coveredVuln)/length(coveredVuln));

fprintf('Flood-vulnerable uncovered: %d\n',sum(~coveredVuln));

fprintf('Farthest flood-prone point from nearest TX: %.2f km\n', ...
    max(nearestProne));

%% 17C. PLOT DIAGNOSTIC MAP

figure('Name','Flood Coverage Diagnostic');
hold on;
grid on;
axis equal;

% Plot other datasets first
plot(diagLowLon,diagLowLat,'b.','MarkerSize',7);
plot(diagVulnLon,diagVulnLat,'m.','MarkerSize',7);

% Flood-prone points: green = covered, red = uncovered
plot(diagProneLon(coveredProne), ...
     diagProneLat(coveredProne), ...
     'go','MarkerFaceColor','g','MarkerSize',6);

plot(diagProneLon(~coveredProne), ...
     diagProneLat(~coveredProne), ...
     'ro','MarkerFaceColor','r','MarkerSize',6);

% Plot coverage circles for all four transmitters
theta = linspace(0,2*pi,200);

for t = 1:4
    circleLon = diagTxLon(t) + ...
        (coverage_km/scaleX)*cos(theta);

    circleLat = diagTxLat(t) + ...
        (coverage_km/scaleY)*sin(theta);

    if t <= 3
        plot(circleLon,circleLat,'k-','LineWidth',1.4);
    else
        plot(circleLon,circleLat,'c--','LineWidth',2);
    end
end

% Mark three regular transmitters and emergency TX
plot(diagTxLon(1:3),diagTxLat(1:3), ...
    'kp','MarkerSize',13,'MarkerFaceColor','y');

plot(diagTxLon(4),diagTxLat(4), ...
    'ks','MarkerSize',11,'MarkerFaceColor','c');

xlim([WEST EAST]);
ylim([SOUTH NORTH]);

xlabel('Longitude (degrees)');
ylabel('Latitude (degrees)');
title('Flood-Prone Coverage Diagnostic — All TX Active');

legend('Low-lying locations', ...
       'Flood-vulnerable locations', ...
       'Covered flood-prone points', ...
       'Uncovered flood-prone points', ...
       'Location','northeast');

hold off;

%% 17D. SAVE FLOOD-PRONE DISTANCE REPORT

% Columns: longitude, latitude, nearest TX distance (km),
% covered (1 = yes, 0 = no)

distanceReport = [diagProneLon, diagProneLat, ...
                  nearestProne, double(coveredProne)];

csvwrite('flood_prone_coverage_diagnostic.csv',distanceReport);

fprintf('\nDiagnostic map generated.\n');
fprintf('Distance report saved to flood_prone_coverage_diagnostic.csv\n');




%% 18. COVERAGE RADIUS SENSITIVITY ANALYSIS

testRadii = [1 2 3 5 7 10 15];

fprintf('\n========== COVERAGE RADIUS SENSITIVITY ==========\n');
fprintf('All four transmitters active\n');
fprintf('Radius(km) | Flood-prone | Low-lying | Vulnerable\n');

for r = testRadii

    % Flood-prone points
    coveredP = false(length(proneLon),1);

    for t = 1:4
        dx = (proneLon-diagTxLon(t))*scaleX;
        dy = (proneLat-diagTxLat(t))*scaleY;
        coveredP = coveredP | (sqrt(dx.^2+dy.^2) <= r);
    end

    % Low-lying points
    coveredL = false(length(lowLon),1);

    for t = 1:4
        dx = (lowLon-diagTxLon(t))*scaleX;
        dy = (lowLat-diagTxLat(t))*scaleY;
        coveredL = coveredL | (sqrt(dx.^2+dy.^2) <= r);
    end

    % Flood-vulnerable points
    coveredV = false(length(vulnLon),1);

    for t = 1:4
        dx = (vulnLon-diagTxLon(t))*scaleX;
        dy = (vulnLat-diagTxLat(t))*scaleY;
        coveredV = coveredV | (sqrt(dx.^2+dy.^2) <= r);
    end

    fprintf('%5.1f      | %2d/%2d (%5.1f%%) | %3d/%3d (%5.1f%%) | %3d/%3d (%5.1f%%)\n', ...
        r, sum(coveredP), length(coveredP), ...
        100*mean(coveredP), ...
        sum(coveredL), length(coveredL), ...
        100*mean(coveredL), ...
        sum(coveredV), length(coveredV), ...
        100*mean(coveredV));
end



%% 19. COMPARE OPTIMISED PLACEMENT AT 1, 5 AND 10 KM

testRadii = [1 5 10];

% Reuse the existing candidate locations and mapped point coordinates.
% Local coordinates are measured in km from the fixed reference point.

fprintf('\n============================================\n');
fprintf('RADIUS COMPARISON: OPTIMISED TX LOCATIONS\n');
fprintf('Study area boundaries remain unchanged.\n');
fprintf('============================================\n');

for ir = 1:length(testRadii)

    R = testRadii(ir);

    fprintf('\n\n========== RADIUS = %.1f KM ==========\n',R);

    %% A. BUILD COVERAGE MATRICES FOR THIS RADIUS

    CP = false(length(cx),length(px));
    CL = false(length(cx),length(lx));
    CV = false(length(cx),length(vx));

    for k = 1:length(cx)

        d = sqrt((px-cx(k)).^2 + (py-cy(k)).^2);
        CP(k,:) = (d <= R)';

        d = sqrt((lx-cx(k)).^2 + (ly-cy(k)).^2);
        CL(k,:) = (d <= R)';

        d = sqrt((vx-cx(k)).^2 + (vy-cy(k)).^2);
        CV(k,:) = (d <= R)';

    end

    % Combined coverage and priority weights.
    % Flood-prone entries have priority weight 10.
    % Low-lying and vulnerable entries have weight 1.
    CC = [CP CL CV];

    ww = [10*ones(1,length(px)), ...
           ones(1,length(lx)), ...
           ones(1,length(vx))];

    %% B. INITIAL GREEDY SELECTION

    chosen = zeros(1,3);
    alreadyCovered = false(1,size(CC,2));

    for t = 1:3

        score = sum(double(CC(:,~alreadyCovered)) .* ...
            repmat(ww(~alreadyCovered),length(cx),1),2);

        score(chosen(chosen>0)) = -inf;

        [~,idx] = max(score);

        chosen(t) = idx;
        alreadyCovered = alreadyCovered | CC(idx,:);
    end

    %% C. IMPROVE POSITIONS FOR SINGLE-TX FAILURE TOLERANCE

    % Objective order:
    % 1. Maximise worst-case flood-prone point coverage.
    % 2. Maximise worst-case weighted coverage.
    % 3. Maximise normal-operation weighted coverage.

    for iteration = 1:8

        changed = false;

        for slot = 1:3

            % Score current arrangement.
            baseProne = inf;
            baseWeighted = inf;

            for failed = 1:3

                survivors = chosen;
                survivors(failed) = [];

                scenP = any(CP(survivors,:),1);
                scenAll = any(CC(survivors,:),1);

                baseProne = min(baseProne,sum(scenP));
                baseWeighted = min(baseWeighted,sum(ww(scenAll)));
            end

            baseNormal = sum(ww(any(CC(chosen,:),1)));

            best = chosen(slot);
            bestProne = baseProne;
            bestWeighted = baseWeighted;
            bestNormal = baseNormal;

            for k = 1:length(cx)

                trial = chosen;
                trial(slot) = k;

                if length(unique(trial)) < 3
                    continue;
                end

                trialProne = inf;
                trialWeighted = inf;

                for failed = 1:3

                    survivors = trial;
                    survivors(failed) = [];

                    scenP = any(CP(survivors,:),1);
                    scenAll = any(CC(survivors,:),1);

                    trialProne = min(trialProne,sum(scenP));
                    trialWeighted = min(trialWeighted, ...
                        sum(ww(scenAll)));
                end

                trialNormal = sum(ww(any(CC(trial,:),1)));

                isBetter = ...
                    trialProne > bestProne || ...
                    (trialProne == bestProne && ...
                     trialWeighted > bestWeighted) || ...
                    (trialProne == bestProne && ...
                     trialWeighted == bestWeighted && ...
                     trialNormal > bestNormal);

                if isBetter
                    best = k;
                    bestProne = trialProne;
                    bestWeighted = trialWeighted;
                    bestNormal = trialNormal;
                end
            end

            if best ~= chosen(slot)
                chosen(slot) = best;
                changed = true;
            end
        end

        if ~changed
            break;
        end
    end

    %% D. NORMAL COVERAGE AND FAILURE RESULTS

    chosenX = cx(chosen);
    chosenY = cy(chosen);

    normP = sum(any(CP(chosen,:),1));
    normL = sum(any(CL(chosen,:),1));
    normV = sum(any(CV(chosen,:),1));

    fprintf('\nOptimised normal-operation coverage:\n');

    fprintf('Flood-prone: %d/%d (%.2f%%)\n', ...
        normP,length(px),100*normP/length(px));

    fprintf('Low-lying: %d/%d (%.2f%%)\n', ...
        normL,length(lx),100*normL/length(lx));

    fprintf('Flood-vulnerable: %d/%d (%.2f%%)\n', ...
        normV,length(vx),100*normV/length(vx));

    fprintf('\nSingle-transmitter failures:\n');

    worstFailure = inf;

    for failed = 1:3

        survivors = chosen;
        survivors(failed) = [];

        fP = sum(any(CP(survivors,:),1));
        fL = sum(any(CL(survivors,:),1));
        fV = sum(any(CV(survivors,:),1));

        worstFailure = min(worstFailure,fP);

        fprintf('TX%d fails: Flood-prone %d/%d (%.2f%%), ', ...
            failed,fP,length(px),100*fP/length(px));

        fprintf('Low-lying %d/%d (%.2f%%), ', ...
            fL,length(lx),100*fL/length(lx));

        fprintf('Vulnerable %d/%d (%.2f%%)\n', ...
            fV,length(vx),100*fV/length(vx));
    end

    %% E. SELECT EMERGENCY SITE

    bestEmergency = 0;
    bestWorstP = -1;
    bestWorstWeighted = -1;
    bestNormalWeighted = -1;

    for k = 1:length(cx)

        if any(chosen == k)
            continue;
        end

        emergencyWorstP = inf;
        emergencyWorstWeighted = inf;

        for failed = 1:3

            survivors = chosen;
            survivors(failed) = [];

            scenarioP = any(CP([survivors,k],:),1);
            scenarioAll = any(CC([survivors,k],:),1);

            emergencyWorstP = min(emergencyWorstP,sum(scenarioP));
            emergencyWorstWeighted = min( ...
                emergencyWorstWeighted,sum(ww(scenarioAll)));
        end

        emergencyNormalWeighted = ...
            sum(ww(any(CC([chosen,k],:),1)));

        better = ...
            emergencyWorstP > bestWorstP || ...
            (emergencyWorstP == bestWorstP && ...
             emergencyWorstWeighted > bestWorstWeighted) || ...
            (emergencyWorstP == bestWorstP && ...
             emergencyWorstWeighted == bestWorstWeighted && ...
             emergencyNormalWeighted > bestNormalWeighted);

        if better
            bestEmergency = k;
            bestWorstP = emergencyWorstP;
            bestWorstWeighted = emergencyWorstWeighted;
            bestNormalWeighted = emergencyNormalWeighted;
        end
    end

    fprintf('\nWorst-case flood-prone coverage:\n');
    fprintf('Without emergency TX: %d/%d (%.2f%%)\n', ...
        worstFailure,length(px),100*worstFailure/length(px));

    fprintf('With emergency TX: %d/%d (%.2f%%)\n', ...
        bestWorstP,length(px),100*bestWorstP/length(px));

    %% F. SAVE LOCATIONS FOR THIS RADIUS

    siteLon = lon0 + cx(chosen)/scaleX;
    siteLat = lat0 + cy(chosen)/scaleY;

    eLon = lon0 + cx(bestEmergency)/scaleX;
    eLat = lat0 + cy(bestEmergency)/scaleY;

    fprintf('\nSelected transmitter coordinates:\n');

    for t = 1:3
        fprintf('TX%d: Lat %.6f, Lon %.6f\n', ...
            t,siteLat(t),siteLon(t));
    end

    fprintf('Emergency TX: Lat %.6f, Lon %.6f\n',eLat,eLon);

    % Separate file for each radius.
    outputFile = sprintf('radius_%02dkm_locations.csv',R);

    siteData = [siteLon(:),siteLat(:);eLon,eLat];

    csvwrite(outputFile,siteData);

    fprintf('Saved coordinates to %s\n',outputFile);

end

fprintf('\n========== RADIUS COMPARISON COMPLETE ==========\n');



