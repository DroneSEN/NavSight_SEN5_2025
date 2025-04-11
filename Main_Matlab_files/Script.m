% Changer de dossier
cd('C:\Users\pchen5\projet git\NavSight_SEN5_2025\Main_Matlab_files\SLAM_v0')

% Ajouter le dossier au path
addpath('C:\Users\pchen5\projet git\NavSight_SEN5_2025\Main_Matlab_files\SLAM_v0\helpers_modif')

% Lire tout le fichier
filePath = 'Optim_MonocularVisualInertialSLAMExample.m';
fileText = fileread(filePath);

% Remplacer la valeur de SCENARIO_NAME (valeur entre guillemets)
newScenario = '50301';
fileText = regexprep(fileText, 'SCENARIO_NAME\s*=\s*".*?"', ['SCENARIO_NAME = "', newScenario, '"']);

% Réécrire le fichier avec la nouvelle valeur
fid = fopen(filePath, 'w');
fwrite(fid, fileText);
fclose(fid);

% Exécuter le script modifié
run(filePath)

