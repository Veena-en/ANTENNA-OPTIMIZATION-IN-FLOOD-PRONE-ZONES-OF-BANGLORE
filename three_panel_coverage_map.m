
clear;
clc;
close all;

%% ============================================================
% BELLANDUR FLOOD-RESILIENT EMERGENCY COMMUNICATION PROJECT
% Three separate figures: 1 km, 5 km and 10 km scenarios
%
% Required CSV files:
%   radius_01km_locations.csv
%   radius_05km_locations.csv
%   radius_10km_locations.csv
%
% CSV convention:
%   Column 1 = longitude
%   Column 2 = latitude
%   Rows 1-3 = main transmitters
%   Row 4   = emergency transmitter
%% ============================================================

%% 1. STUDY AREA
WEST  = 77.490;
EAST  = 77.710;
SOUTH = 12.850;
NORTH = 13.130;

lat0 = 12.990;
scaleX = 111.320*cosd(lat0);
scaleY = 111.320;

radii = [1 5 10];

%% 2. LOAD TRANSMITTER COORDINATES
files = {
    'radius_01km_locations.csv'
    'radius_05km_locations.csv'
    'radius_10km_locations.csv'
};

sites = cell(1,3);

for i = 1:3

    if exist(files{i},'file') ~= 2
        error('Missing file: %s. Check your working folder.',files{i});
    end

    sites{i} = csvread(files{i});

    if size(sites{i},1) < 4 || size(sites{i},2) < 2
        error('Unexpected CSV format in %s.',files{i});
    end

    sites{i} = sites{i}(1:4,1:2);
end

%% 3. LOAD KML POINT DATASETS
lowFile = '8e87a2fc-e014-4c6e-81f1-d5cb4db57a46.kml';
proneFile = '00fb1229-dcfd-4f59-a2c2-006f734c5b41 (1).kml';
vulnFile = '6b3c63b0-f461-4e9c-a2c2-006f734c5b41 (1).kml';

% The flood-prone filename used in the previous script is retained below.
proneFile = '00fb1229-dcfd-4f59-813f-885e0c629add (1).kml';

[lowLon,lowLat] = readKMLPoints( ...
    lowFile,WEST,EAST,SOUTH,NORTH);

[proneLon,proneLat] = readKMLPoints( ...
    proneFile,WEST,EAST,SOUTH,NORTH);

[vulnLon,vulnLat] = readKMLPoints( ...
    vulnFile,WEST,EAST,SOUTH,NORTH);

if isempty(proneLon)
    error('No flood-prone points loaded. Check the KML filename and coordinates.');
end

fprintf('\nLoaded data:\n');
fprintf('Low-lying points: %d\n',length(lowLon));
fprintf('Flood-prone points: %d\n',length(proneLon));
fprintf('Flood-vulnerable points: %d\n',length(vulnLon));

%% 4. OPTIONAL FLOOD-ZONE GEOJSON
geoFile = 'bengaluru_flood_zones(1).geojson';

if exist(geoFile,'file') ~= 2
    geoFile = 'bengaluru_flood_zones.geojson';
end

haveGeoJSON = false;
geo = [];

if exist(geoFile,'file') == 2
    try
        geo = jsondecode(fileread(geoFile));
        haveGeoJSON = isfield(geo,'features');

        if haveGeoJSON
            fprintf('Flood polygons loaded from %s\n',geoFile);
        end
    catch
        warning('Could not parse GeoJSON. Continuing with point datasets.');
    end
else
    fprintf('Flood-zone GeoJSON not found; point layers will be shown.\n');
end

%% 5. VISUAL STYLE
cLow = [0.10 0.38 0.85];        % Blue
cVuln = [0.70 0.20 0.72];       % Purple
cProne = [0.88 0.20 0.16];      % Red
cCovered = [0.08 0.62 0.35];    % Green
cTX = [1.00 0.72 0.12];         % Yellow
cEmergency = [0.00 0.68 0.78];  % Cyan
cBoundary = [0.12 0.20 0.30];   % Dark blue-grey

theta = linspace(0,2*pi,240);

%% 6. GENERATE THREE SEPARATE FIGURES
for panel = 1:3

    R = radii(panel);
    S = sites{panel};

    txLon = S(:,1);
    txLat = S(:,2);

    %% CREATE FIGURE
    fig = figure(panel);
    clf(fig);

    set(fig,'Color',[0.96 0.97 0.99], ...
        'Position',[80 50 1200 900]);

    %% MAIN MAP AXES
    ax = axes('Parent',fig, ...
        'Position',[0.105 0.255 0.80 0.59]);

    hold(ax,'on');

    set(ax,'Color','white', ...
        'FontSize',11, ...
        'LineWidth',1.0, ...
        'XColor',[0.25 0.29 0.35], ...
        'YColor',[0.25 0.29 0.35]);

    %% 6A. FLOOD-ZONE POLYGONS
    if haveGeoJSON
        try
            for f = 1:numel(geo.features)

                geom = geo.features(f).geometry;

                if isempty(geom)
                    continue;
                end

                if strcmp(geom.type,'Polygon')
                    polygons = {geom.coordinates};
                elseif strcmp(geom.type,'MultiPolygon')
                    polygons = geom.coordinates;
                else
                    continue;
                end

                for p = 1:numel(polygons)

                    poly = polygons{p};

                    if iscell(poly)
                        rings = poly;
                    else
                        rings = {poly};
                    end

                    if isempty(rings)
                        continue;
                    end

                    % Exterior ring only
                    coords = rings{1};

                    if isempty(coords)
                        continue;
                    end

                    coords = reshape(coords,[],2);

                    x = coords(:,1);
                    y = coords(:,2);

                    if max(x) < WEST || min(x) > EAST || ...
                       max(y) < SOUTH || min(y) > NORTH
                        continue;
                    end

                    patch(ax,x,y,[1.0 0.78 0.72], ...
                        'FaceAlpha',0.20, ...
                        'EdgeColor',[0.83 0.36 0.29], ...
                        'LineWidth',0.6);
                end
            end
        catch
            warning('Some GeoJSON polygons could not be plotted.');
        end
    end

    %% 6B. COVERAGE CIRCLES
    for t = 1:4

        circleLon = txLon(t) + (R/scaleX)*cos(theta);
        circleLat = txLat(t) + (R/scaleY)*sin(theta);

        if t <= 3
            plot(ax,circleLon,circleLat,'-', ...
                'Color',cBoundary,'LineWidth',1.8);
        else
            plot(ax,circleLon,circleLat,'--', ...
                'Color',cEmergency,'LineWidth',2.2);
        end
    end

    %% 6C. LOW-LYING AND VULNERABLE POINTS
    hLow = plot(ax,lowLon,lowLat,'.', ...
        'Color',cLow,'MarkerSize',9);

    hVuln = plot(ax,vulnLon,vulnLat,'.', ...
        'Color',cVuln,'MarkerSize',9);

    %% 6D. CALCULATE FLOOD-PRONE COVERAGE
    nearestDistance = inf(length(proneLon),1);

    for t = 1:4

        dx = (proneLon-txLon(t))*scaleX;
        dy = (proneLat-txLat(t))*scaleY;

        d = sqrt(dx.^2 + dy.^2);

        nearestDistance = min(nearestDistance,d);
    end

    isCovered = nearestDistance <= R;

    %% 6E. UNCOVERED FLOOD-PRONE POINTS
    hUncovered = plot(ax, ...
        proneLon(~isCovered),proneLat(~isCovered),'o', ...
        'MarkerSize',5.5, ...
        'MarkerFaceColor',cProne, ...
        'MarkerEdgeColor','none');

    %% 6F. COVERED FLOOD-PRONE POINTS
    hCovered = plot(ax, ...
        proneLon(isCovered),proneLat(isCovered),'o', ...
        'MarkerSize',5.5, ...
        'MarkerFaceColor',cCovered, ...
        'MarkerEdgeColor','none');

    %% 6G. MAIN TRANSMITTERS
    hTX = plot(ax,txLon(1:3),txLat(1:3),'p', ...
        'MarkerSize',14, ...
        'MarkerFaceColor',cTX, ...
        'MarkerEdgeColor',[0.12 0.12 0.12], ...
        'LineWidth',1.1);

    %% 6H. EMERGENCY TRANSMITTER
    hEmergency = plot(ax,txLon(4),txLat(4),'s', ...
        'MarkerSize',11, ...
        'MarkerFaceColor',cEmergency, ...
        'MarkerEdgeColor',[0.1 0.1 0.1], ...
        'LineWidth',1.1);

    %% 6I. MAP TITLE AND AXES
    title(ax,sprintf('%d km Coverage Scenario',R), ...
        'FontSize',16, ...
        'FontWeight','bold', ...
        'Color',[0.10 0.18 0.30]);

    xlabel(ax,'Longitude (degrees E)','FontSize',12);
    ylabel(ax,'Latitude (degrees N)','FontSize',12);

    xlim(ax,[WEST EAST]);
    ylim(ax,[SOUTH NORTH]);

    grid(ax,'on');
    box(ax,'on');

    set(ax,'GridColor',[0.82 0.85 0.90]);

    %% 6J. COVERAGE STATISTICS
    totalProne = length(proneLon);
    coveredCount = sum(isCovered);
    percentage = 100*coveredCount/max(1,totalProne);

    annotation(fig,'textbox',[0.18 0.905 0.64 0.04], ...
        'String',sprintf( ...
        'Flood-prone points covered: %d/%d (%.1f%%)', ...
        coveredCount,totalProne,percentage), ...
        'EdgeColor','none', ...
        'HorizontalAlignment','center', ...
        'FontSize',13, ...
        'FontWeight','bold', ...
        'Color',[0.10 0.35 0.22]);

    %% 6K. LEGEND HANDLES
    hMainCircle = plot(ax,nan,nan,'-', ...
        'Color',cBoundary,'LineWidth',1.8);

    hEmergencyCircle = plot(ax,nan,nan,'--', ...
        'Color',cEmergency,'LineWidth',2.2);

    lgd = legend(ax, ...
        [hLow hVuln hUncovered hCovered hTX ...
         hEmergency hMainCircle hEmergencyCircle], ...
        {'Low-lying locations', ...
         'Flood-vulnerable locations', ...
         'Uncovered flood-prone points', ...
         'Covered flood-prone points', ...
         'Main transmitters (TX1-TX3)', ...
         'Emergency transmitter', ...
         'Main TX coverage boundary', ...
         'Emergency TX coverage boundary'}, ...
        'Location','southoutside', ...
        'FontSize',9);

    set(lgd,'Box','off');

    %% 6L. FOOTNOTE
    annotation(fig,'textbox',[0.05 0.015 0.90 0.035], ...
        'String',['Idealised distance-based simulation, not measured RF coverage. ' ...
        'Percentages refer to mapped points, not population.'], ...
        'EdgeColor','none', ...
        'HorizontalAlignment','center', ...
        'FontSize',9, ...
        'Color',[0.35 0.38 0.43]);

    %% 6M. SAVE PNG
    outputFile = sprintf('bellandur_coverage_%dkm.png',R);

    print(fig,outputFile,'-dpng','-r300');

    fprintf('\n%d km scenario\n',R);
    fprintf('Flood-prone points covered: %d/%d (%.2f%%)\n', ...
        coveredCount,totalProne,percentage);
    fprintf('Saved: %s\n',outputFile);

    hold(ax,'off');
end

fprintf('\nAll three separate figures have been generated.\n');


%% ============================================================
% LOCAL FUNCTION: READ KML COORDINATES
%% ============================================================
function [lon,lat] = readKMLPoints(filename,WEST,EAST,SOUTH,NORTH)

    lon = [];
    lat = [];

    if exist(filename,'file') ~= 2
        error('Missing KML file: %s',filename);
    end

    raw = fileread(filename);

    blocks = regexp(raw, ...
        '<coordinates[^>]*>(.*?)</coordinates>', ...
        'tokens');

    for b = 1:length(blocks)

        coordinateText = strtrim(blocks{b}{1});
        entries = regexp(coordinateText,'\s+','split');

        for j = 1:length(entries)

            values = strsplit(entries{j},',');

            if length(values) < 2
                continue;
            end

            x = str2double(values{1});
            y = str2double(values{2});

            if isfinite(x) && isfinite(y) && ...
               x >= WEST && x <= EAST && ...
               y >= SOUTH && y <= NORTH

                lon(end+1,1) = x;
                lat(end+1,1) = y;
            end
        end
    end
end

