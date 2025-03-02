%% Enregistre la map générée

scenarioName = "4";
player = pcplayer([-50 20], [-5 60], [-2 50]);
player.view(rotatedWorldPoints)

% save(strcat('scenarios\',scenarioName,'\map\generated_map.mat'), "vSetKeyFrames", "mapPointSet")


%% Rotate worldpoints

% Matrice de rotation pour changer les axes de la map
rot = [1 0 0; 0 0 -1; 0 1 0];

rotatedWorldPoints = mapPointSet.WorldPoints * rot;

player = pcplayer([-50 20], [-5 60], [-2 50]);
player.view(rotatedWorldPoints)

% Stocke les nouvelles valeurs
pointIndices = (1:length(rotatedWorldPoints))';
rotatedWpSet = updateWorldPoints(mapPointSet,pointIndices,rotatedWorldPoints);

mapPointSet = rotatedWpSet;

save(strcat('scenarios\',scenarioName,'\map\generated_map_rotated.mat'), "vSetKeyFrames", "mapPointSet")