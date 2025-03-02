# Projet SLAM Collaboratif
## Organisation du répertoire de travail du projet d'essaim



- Simulation
  
  Permet de générer la vidéo, données IMU et ground Truth pour chacun des scénarios

- Scenarios
  
  Contient l'ensemble des scénarios (identifiés par un numéro)
  Contient les fichiers pour générer un trajet, ainsi qu'un fichier pour construire la structure du dataset à partir de la sortie de la simulation
  
  Chaque scénario est organisé de la sorte:
  - /images : Contient les frames du scénarios
  - /map : Contient la cartographie réalisée par le SLAM
  - scenarioWaypoints.mat : Waypoints du scénario
  - simulationOutput.mat  : Variable out de la simulation (qui doit être sauvegardé après la simu)
  - uavData.mat           : Dataset construit à partir du fichier simulationOutput.mat, fournis au SLAM

  Appelation des scénarios:
  - Les scénarios de l'agent principal sont notés par un nombre (ex: 1, 2, 3, …)
  - L'agent secondaire se base sur une carte d'un scénario principal, mais effectue un trajet différent, on note donc: {id principal}_reloc_{id secondaire}.
    
    Exemple: Pour le scénario 2, si on a plusieurs trajets d'agent secondaire on a alors : 2_1, 2_2, 2_3, ...


- Relocalization_agent
  
  Contient le Simulink de l'agent secondaire qui effectue la relocalisation
  Il se base sur les maps générées dans les scénarios principaux, et les scénarios secondaires (Identifié par {id principal}_reloc_{id secondaire})

- SLAM V0
  
  Première version du SLAM, qui permet de générer la carte à partir d'un scénario principal
  La carte (mapPointSet et vSetKeyframes) doit être sauvegardé dans le répertoire du scénario (dans /map)


## Tutoriel

**I. Génération du path et du dataset**
1. Entrez dans le répertoire /Scénarios
2. Créer un répertoire avec un numéro de scénario
3. Ajouter à l'intérieur un répertoire /images et /map
4. A l'aide du fichier "basicWaypointsGeneration.m", générez les waypoints, ATTENTION, lancez uniquement la section qui concerne VOTRE scénario

5. Allez dans le répertoire /Simulation
6. Ouvez le simulink
7. Configurez le WaypointManager et le ScenarioRecorder avec le numéro de scénario
8. Lancez la simulation
9. A la fin de la simulation, enregistrez la variable ".out" dans le répertoire du scénario, dans un fichier appelé "simulationOutput"

10. Retournez dans le répertoire /Scénarios
11. Ouvrez le script "constructDataset.m"
12. En haut du fichier, configurez le nom du scénario
13. Exécutez le fichier, cela va générer un fichier "uavData.mat" dans le répertoire du scénario

**II. SLAM Offline**
1. Allez dans le répertoire SLAM_v0
2. Ajoutez "helpers_modif" au path
3. Lancez le fichier "Optim_MonocularVisualInertialSLAMExample.mlx"
4. Configurez le nom du scénario à charger
5. Lancez le SLAM, ce dernier prendra du temps pour générer la map
6. La map sera sauvegardée automatiquement dans le répertoire /map du scénario
    Si jamais elle n'est pas sauvegardée: sélectionnez les variables "mapPointSet" et "vSetKeyframes" et sauvegardez les dans /Scénarios/{ID}/map/generated_map.mat

**III. Relocalisation**
1. Allez dans le répertoire Relocalization_agent_v0
2. Ajoutez les repertoire /Helpersagent2 et /MatlabSystems au path
3. Ouvrez le simulink
4. Configurez le ScenarioReader ainsi que le bloc de Relocalization avec le bon identifiant de scénario
5. Lancez le simulink