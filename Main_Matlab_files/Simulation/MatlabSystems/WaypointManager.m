classdef WaypointManager < matlab.System
    % WaypointManager Gère les waypoints à suivre
    %
    % This template includes the minimum set of functions required
    % to define a System object.

    % Public, tunable properties
    properties

    end

    % Pre-computed constants or internal states
    properties (Access = private)
        % Index du waypoint (à partir de 1)
        CurrentWaypointIndex = 1;

        % Fin de la patrouille
        Finished = 0;

        % Flag utilisé pour détecter un front montant sur forceNextWaypoint
        PrvForceNextWaypoint = 0;

        % Temps passé sur le waypoint (en secondes)
        ElapsedTimeWaypoint = 0;

        % Temps au précédent cycle
        PreviousTime = 0;
    end

    methods (Access = protected)
        function setupImpl(obj)
            % Perform one-time calculations, such as computing constants
        end

        function [waypoint, finished, elapsedTimeWaypoint] = stepImpl(obj,enable, lookaheadDistance, currentPos, waypoints, numWaypoints, forceNextWaypoint, requiredTime, time)

            % On calcule le temps de cycle
            sampleTime = time - obj.PreviousTime;
            
            if enable
                % Calcul de la distance entre le drone et le waypoint actuel
                errorPos = sqrt(sum((currentPos - waypoints(obj.CurrentWaypointIndex, 1:3)).^2));
    
                obj.Finished = 0;
                
                % Si la distance est acceptable on incrémente le compteur
                if (errorPos <= lookaheadDistance)
                    
                    % On incrémente le temps passé sur le waypoint
                    obj.ElapsedTimeWaypoint = obj.ElapsedTimeWaypoint + sampleTime;

                end

                % Si le temps passé sur le waypoint est supérieur au temps requis
                % ou si on force le passage au waypoint suivant
                if obj.ElapsedTimeWaypoint >= requiredTime || obj.PrvForceNextWaypoint ~= forceNextWaypoint

                    % Si on n'est pas sur le dernier waypoint
                    if obj.CurrentWaypointIndex ~= numWaypoints
                        obj.CurrentWaypointIndex = obj.CurrentWaypointIndex + 1;

                        % On réinitialise le temps passé sur le waypoint
                        obj.ElapsedTimeWaypoint = 0;
                    else
                        % Si on est sur le dernier waypoint
                        obj.Finished = 1;
                    end
                end

            else
                % Si le WaypointManager n'est pas activé
                obj.Finished = 0;
                obj.CurrentWaypointIndex = 1;
            end

            % On actualise le flag pour détecter les front montants
            obj.PrvForceNextWaypoint = forceNextWaypoint;
            
            % On actualise le temps au précédent cycle
            obj.PreviousTime = time;

            % On retourne le temps passé sur le waypoint actuel
            elapsedTimeWaypoint = obj.ElapsedTimeWaypoint;

            % On retourne le waypoint actuel
            finished = obj.Finished;
            waypoint = waypoints(obj.CurrentWaypointIndex, 1:3);
        end

        function [waypoint, finished, elapsedTimeWaypoint] = getOutputSizeImpl(obj)
            % Retourne la taille pour chaque port de sortie
            waypoint = [1, 3];
            finished = [1, 1]; 
            elapsedTimeWaypoint = [1, 1];
        end

        function [waypoint, finished, elapsedTimeWaypoint] = getOutputDataTypeImpl(obj)
            % Retourne le type de données pour chaque port de sortie
            waypoint = "double"; 
            finished = "double";
            elapsedTimeWaypoint = "double";
        end

        function [waypoint, finished, elapsedTimeWaypoint] = isOutputComplexImpl(obj)
            % Retourne false pour chaque port de sortie avec des données non complexes
            waypoint = false;
            finished = false; 
            elapsedTimeWaypoint = false;
        end

        function [waypoint, finished, elapsedTimeWaypoint] = isOutputFixedSizeImpl(obj)
            % Retourne true pour chaque port de sortie avec une taille fixe
            waypoint = true;
            finished = true;
            elapsedTimeWaypoint = true;
        end

        function resetImpl(obj)
            % Initialize / reset internal properties
        end
    end
end
