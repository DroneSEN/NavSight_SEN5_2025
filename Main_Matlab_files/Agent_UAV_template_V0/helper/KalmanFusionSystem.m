classdef KalmanFusionSystem < matlab.System & matlab.system.mixin.Propagates
    % KalmanFusionSystem Implémente un filtre de Kalman pour la fusion SLAM-IMU dans Simulink

    properties
        dt = 0.1 % Intervalle d'échantillonnage
        noise_std = 0.5 % Écart-type du bruit IMU
        Q = 0.01 * eye(6) % Bruit du modèle
        R = diag([0.3, 0.3, 0.3, 1, 1, 1]) % Matrice de bruit des mesures
    end

    properties (Access = private)
        A % Matrice de transition d'état 
        H % Matrice d'observation
        X_est % État estimé
        P_est % Covariance estimée
    end

    methods (Access = protected)
        function num = getNumInputsImpl(~)
            % Définir le nombre d'entrées (SLAM + IMU = 2)
            num = 2;
        end

        function num = getNumOutputsImpl(~)
            % Définir le nombre de sorties (position filtrée = 1)
            num = 1;
        end

        function sz = getOutputSizeImpl(~)
            % Définir la taille de la sortie (vecteur 1x3 pour x,y,z)
            sz = [1 3];
        end

        function dt = getOutputDataTypeImpl(~)
            % Définir le type de données de sortie
            dt = 'double';
        end

        function cp = isOutputComplexImpl(~)
            % Spécifier si la sortie est complexe
            cp = false;
        end

        function fs = isOutputFixedSizeImpl(~)
            % Spécifier si la taille de sortie est fixe
            fs = true;
        end

        function setupImpl(obj)
            % Initialisation du système
            obj.A = [1 0 0 obj.dt 0 0;
                    0 1 0 0 obj.dt 0;
                    0 0 1 0 0 obj.dt;
                    0 0 0 1 0 0;
                    0 0 0 0 1 0;
                    0 0 0 0 0 1];

            obj.H = [1 0 0 0 0 0;
                    0 1 0 0 0 0;
                    0 0 1 0 0 0;
                    1 0 0 0 0 0;
                    0 1 0 0 0 0;
                    0 0 1 0 0 0];

            % Initialisation des états à zéro
            obj.X_est = zeros(6,1);
            obj.P_est = eye(6);
        end

        function [pos_filtered] = stepImpl(obj, pos_slam, pos_imu)
            % Vérifier que les entrées sont au bon format
            pos_slam = reshape(pos_slam, [3,1]);
            pos_imu = reshape(pos_imu, [3,1]);

            % Ajouter du bruit à l'IMU
            pos_imu_noisy = pos_imu + obj.noise_std * randn(size(pos_imu));

            % Étape de prédiction
            X_pred = obj.A * obj.X_est;
            P_pred = obj.A * obj.P_est * obj.A' + obj.Q;

            % Étape de mise à jour
            Z_k = [pos_slam; pos_imu_noisy];
            K = P_pred * obj.H' / (obj.H * P_pred * obj.H' + obj.R);

            % Mise à jour de l'état et de la covariance
            obj.X_est = X_pred + K * (Z_k - obj.H * X_pred);
            obj.P_est = (eye(6) - K * obj.H) * P_pred;

            % Retourner la position filtrée
            pos_filtered = obj.X_est(1:3)';
        end

        function resetImpl(obj)
            % Réinitialisation du système
            obj.X_est = zeros(6,1);
            obj.P_est = eye(6);
        end
    end
end