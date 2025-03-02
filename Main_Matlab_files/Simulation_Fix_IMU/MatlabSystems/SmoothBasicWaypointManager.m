classdef SmoothBasicWaypointManager < matlab.System
    % WaypointManager Gère les waypoints à suivre

    % Public, tunable properties
    properties
        
    end

    properties (Nontunable)

        % Répertoire des scénarios
        ScenariosDirectory = "C:\Users\vince\Documents\SEN5\CollaborativeSLAM\Scenarios";

        % Nom du scénario à charger
        ScenarioName = "4"

        StepTime = 0.01;
    end

    % Pre-computed constants or internal states
    properties (Access = private)
        % Liste des waypoints sous la forme (t, x,y,z, phi, theta, psi)
        Waypoints = [];

        % Nombre de waypoints
        NumWaypoints = 0;

        % Index du waypoint (à partir de 1)
        currentWaypointIndex = 1;

        currentPosition
        nextWaypoint

        timeElapsed
        previousTime

        % Paramètres et status de l'interpolation
        % Lorsque l'on passe à un nouveau waypoint, on calcul les
        % différents pas de consigne
        % Si le nombre de steps n'est pas rond, on arrondi au supérieur

        % Le delta entre chaque étape d'interpolation
        deltaInterpol

        % On stocke le nombre d'étapes d'interpolations nécessaires
        totalInterpolSteps = 0;
        
        % Etape actuelle (indéxée de 1...N)
        curInterpolStep

        % Fin de la patrouille
        Finished = 0;
    end

    methods (Access = protected)
        function setupImpl(obj)
            % Fichier contenant les waypoints
            WaypointsFile = fullfile(obj.ScenariosDirectory, obj.ScenarioName, "scenarioWaypoints.mat");


            % Chargement du fichier de waypoints
            load(WaypointsFile, 'WayPts');

            obj.Waypoints = WayPts;
            obj.NumWaypoints = length(obj.Waypoints);

            % Debug
            disp(strcat(num2str(obj.NumWaypoints), ' waypoint(s) loaded'));

            % Initialiser la position courante avec le premier waypoint
            obj.currentPosition = obj.Waypoints(1, 2:end); % Waypoints(:, [x, y, z, phi, theta, psi])
            obj.nextWaypoint = obj.Waypoints(2, 2:end);

            obj.previousTime = 0;

        end

        function [waypoint, finished] = stepImpl(obj, time)

            % Vérification si le prochain waypoint est atteint
            if obj.currentWaypointIndex ~= obj.NumWaypoints
                if time >= obj.Waypoints(obj.currentWaypointIndex+1, 1) 
                    obj.currentWaypointIndex = obj.currentWaypointIndex + 1;
                end
            end

            % On atteint le dernier waypoint
            if obj.currentWaypointIndex == obj.NumWaypoints
                % On retourne le dernier waypoint, sans interpolation et on
                % execute pas le reste
                finished = 1;
                waypoint = obj.Waypoints(obj.NumWaypoints, 2:end)';
                return
            else
                finished = 0;
            end


            % Sinon, on effectue une interpolation
            
            % On détermine alpha, le coefficient directeur pour chacune
            % des consignes
            deltaWaypoint = obj.Waypoints(obj.currentWaypointIndex + 1, :) - ...
                           obj.Waypoints(obj.currentWaypointIndex, :);
            
            dt = deltaWaypoint(1);

            % alpha correspond à (dx, dy, dz, dphi, dtheta, dpsi)
            alpha = deltaWaypoint(2:end)./dt;

            % Calcul du temps écoulé depuis le début du waypoint (en
            % secondes)
            elapsedTime = time - obj.Waypoints(obj.currentWaypointIndex, 1);

            
            waypoint = obj.Waypoints(obj.currentWaypointIndex, 2:end) + alpha.*elapsedTime;


            % Retourner la position interpolée
            waypoint = waypoint'; % Transposition pour matrice colonne
            finished = 0;
        end

        function [waypoint, finished] = getOutputSizeImpl(obj)
            % Retourne la taille pour chaque port de sortie
            waypoint = [6, 1];
            finished = [1, 1]; 
        end

        function [waypoint, finished] = getOutputDataTypeImpl(obj)
            % Retourne le type de données pour chaque port de sortie
            waypoint = "double"; 
            finished = "double";
        end

        function [waypoint, finished] = isOutputComplexImpl(obj)
            % Retourne false pour chaque port de sortie avec des données non complexes
            waypoint = false;
            finished = false; 
        end

        function [waypoint, finished] = isOutputFixedSizeImpl(obj)
            % Retourne true pour chaque port de sortie avec une taille fixe
            waypoint = true;
            finished = true;
        end

        function resetImpl(obj)
            % Initialize / reset internal properties
        end
    end
end
