classdef IMUPoseMemory < matlab.System
    % IMUPoseMemory Add summary here
    %
    % This template includes the minimum set of functions required
    % to define a System object.

    % Public, tunable properties
    properties

    end

    % Pre-computed constants or internal states
    properties (Access = private)
        SavedPose = zeros(3,1);
        SavedVelocity = zeros(3,1);
        PrvResetImu = 0;
    end

    methods (Access = protected)
        function setupImpl(obj)
            % Perform one-time calculations, such as computing constants
        end

        function [savedPose, savedVelocity] = stepImpl(obj,resetImu,filteredPose, filteredVelocity)
            % Implement algorithm. Calculate y as a function of input u and
            % internal states.
            
            % Detecte front montant
            if obj.PrvResetImu == 0 && resetImu == 1
                
                % On stocke la position filtrée
                obj.SavedPose = filteredPose;
                obj.SavedVelocity = filteredVelocity;
            end

            obj.PrvResetImu = resetImu;
            
            % Output
            savedPose = obj.SavedPose;
            savedVelocity = obj.SavedVelocity;
        end

        function resetImpl(obj)
            % Initialize / reset internal properties
        end
    end
end
