classdef PositionAccelFilter < matlab.System
    % Système pour filtrer les sauts de position avec validation par accélération
    
    properties
        % Paramètres de détection
        maxPositionJump = 0.5;     % mètres
        maxAcceleration = 5.0;     % m/s^2
        windowSize = 5;            % Taille de la fenêtre d'historique
        alpha = 0.2;               % Facteur de lissage (0 = que l'historique, 1 = que la nouvelle position)
    end
    
    properties (Access = private)
        positionHistory
        lastPosition
        historyIndex
        isInitialized
        dt
    end
    
    methods (Access = protected)
        function setupImpl(obj)
            obj.positionHistory = zeros(3, obj.windowSize);
            obj.lastPosition = zeros(3, 1);
            obj.historyIndex = 1;
            obj.isInitialized = false;
            obj.dt = 0.1; % Pas de temps supposé, à ajuster selon votre système
        end
        
        function [filteredPosition, isJump] = stepImpl(obj, position, acceleration)
            if ~obj.isInitialized
                obj.positionHistory(:, :) = repmat(position, 1, obj.windowSize);
                obj.lastPosition = position;
                obj.isInitialized = true;
                filteredPosition = position;
                isJump = false;
                return;
            end
            
            % Calcul du saut de position
            positionJump = norm(position - obj.lastPosition);
            
            % Calcul de l'accélération théorique nécessaire pour ce saut
            theoreticalAccel = 2 * (position - obj.lastPosition) / (obj.dt^2);
            
            % Détection de saut basée sur:
            % 1. L'amplitude du saut
            % 2. La cohérence avec l'accélération mesurée
            isJump = (positionJump > obj.maxPositionJump) && ...
                    (norm(acceleration) < 0.5 * norm(theoreticalAccel));
            
            % Mise à jour de l'historique
            obj.positionHistory(:, obj.historyIndex) = obj.lastPosition;
            obj.historyIndex = mod(obj.historyIndex, obj.windowSize) + 1;
            
            if isJump
                % Si saut détecté, utiliser principalement l'historique
                meanPos = mean(obj.positionHistory, 2);
                % Filtrage plus agressif
                filteredPosition = meanPos + obj.alpha * (position - meanPos);
            else
                % Pas de saut : utiliser la nouvelle position
                filteredPosition = position;
            end
            
            % Mise à jour de la dernière position valide
            obj.lastPosition = filteredPosition;
        end
        
        function resetImpl(obj)
            obj.positionHistory = zeros(3, obj.windowSize);
            obj.lastPosition = zeros(3, 1);
            obj.historyIndex = 1;
            obj.isInitialized = false;
        end
    end
end