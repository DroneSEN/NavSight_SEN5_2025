clear;
clc;

% Définition du scénario
scenario_num = 050301; % Changer ce nombre pour choisir le scénario

% Définition du dossier de sauvegarde (compatibilité avec la classe)
dossier_scenario = fullfile("C:\Users\vince\Downloads\NavSight_SEN5_2025-main\NavSight_SEN5_2025-main\Main_Matlab_files\Scenarios", num2str(scenario_num));
if ~exist(dossier_scenario, 'dir')
    mkdir(dossier_scenario);
end
cd(dossier_scenario);
mkdir('map');
mkdir('images');


% Définition des waypoints avec le temps et les angles
waypoints = [
    0 0 0; 
    10 0 2; 
    20 0 4; 
    30 0 6;
    40 0 8;
    50 0 10;
];

t = (0:size(waypoints,1)-1)'; % Génération d'un temps fictif
waypoints = [t, waypoints, zeros(size(waypoints, 1), 3)]; % Ajout des angles phi, theta, psi

% Sauvegarde du fichier sous le bon nom attendu par la classe
WayPts = waypoints; % Assure la compatibilité avec la classe
fichier_mat = fullfile(dossier_scenario, "scenarioWaypoints.mat");
save(fichier_mat, 'WayPts');

fprintf("Fichier enregistré : %s\n", fichier_mat);
