%% Paramètres configurables

% Les données sont au format:
% - XYZ_estime : [Nx3]

XYZ_estime = permute(out.Localization_AgentA.Pose_XYZ_Kalman_Filtered.Data, [3 1 2]);
gtruth = permute(out.Localization_AgentA.Pose_XYZ_GroundTruth_Filtered.Data, [3 1 2]);

start_idx = 250;  % Point de départ de l'analyse
num_samples = size(XYZ_estime, 1) - start_idx + 1;
% Chargement des données
XYZ_estime = XYZ_estime(start_idx:end, :);
gtruth = gtruth(start_idx:end, :);


% 1. RMSE (Root Mean Square Error)
% Mesure la racine carrée de la moyenne des erreurs au carré
% Plus sensible aux grandes erreurs que le MAE
squared_errors = (XYZ_estime - gtruth).^2;
rmse_global = sqrt(mean(squared_errors, 'all'));
rmse_x = sqrt(mean(squared_errors(:,1)));
rmse_y = sqrt(mean(squared_errors(:,2)));
rmse_z = sqrt(mean(squared_errors(:,3)));
% 2. MAE (Mean Absolute Error)
% Moyenne des valeurs absolues des erreurs
% Moins sensible aux valeurs extrêmes que le RMSE
mae = mean(abs(XYZ_estime - gtruth), 'all');
mae_xyz = mean(abs(XYZ_estime - gtruth));
% 3. Erreur maximale
% La plus grande erreur observée
max_error = max(sqrt(sum(squared_errors,2)));
max_error_xyz = max(abs(XYZ_estime - gtruth));
% 4. Écart-type de l'erreur
% Mesure la dispersion des erreurs autour de la moyenne
std_error = std(XYZ_estime - gtruth);
% 5. Coefficient de corrélation
% Mesure la similarité entre estimation et vérité (1 = parfait, 0 = aucune correlation)
corr_x = corrcoef(XYZ_estime(:,1), gtruth(:,1));
corr_y = corrcoef(XYZ_estime(:,2), gtruth(:,2));
corr_z = corrcoef(XYZ_estime(:,3), gtruth(:,3));
% 6. Pourcentage d'erreurs avec seuils adaptés pour système moins précis
errors = sqrt(sum(squared_errors,2));
threshold_20cm = sum(errors < 0.20) / length(errors) * 100;
threshold_50cm = sum(errors < 0.50) / length(errors) * 100;
threshold_1m = sum(errors < 1.00) / length(errors) * 100;
% Affichage des résultats avec explications
fprintf('=== Analyse détaillée des erreurs ===\n\n');
fprintf('Échantillons analysés: %d à %d (total: %d)\n\n', start_idx, start_idx+num_samples-1, num_samples);
fprintf('1. RMSE (Root Mean Square Error) - Sensible aux grandes erreurs:\n');
fprintf('   Global: %.2f m\n', rmse_global);
fprintf('   Par axe: X: %.2f m, Y: %.2f m, Z: %.2f m\n', rmse_x, rmse_y, rmse_z);
fprintf('\n2. MAE (Mean Absolute Error) - Moyenne des erreurs absolues:\n');
fprintf('   Global: %.2f m\n', mae);
fprintf('   Par axe: X: %.2f m, Y: %.2f m, Z: %.2f m\n', mae_xyz);
fprintf('\n3. Erreur maximale - Pire cas observé:\n');
fprintf('   Maximum global: %.2f m\n', max_error);
fprintf('   Par axe: X: %.2f m, Y: %.2f m, Z: %.2f m\n', max_error_xyz);
fprintf('\n4. Écart-type - Dispersion des erreurs:\n');
fprintf('   Par axe: X: %.2f m, Y: %.2f m, Z: %.2f m\n', std_error);
fprintf('\n5. Corrélation avec la vérité terrain (1 = parfait):\n');
fprintf('   X: %.3f, Y: %.3f, Z: %.3f\n', corr_x(1,2), corr_y(1,2), corr_z(1,2));
fprintf('\n6. Distribution des erreurs:\n');
fprintf('   Erreurs < 20cm: %.1f%%\n', threshold_20cm);
fprintf('   Erreurs < 50cm: %.1f%%\n', threshold_50cm);
fprintf('   Erreurs < 1m: %.1f%%\n', threshold_1m);
% Visualisations
figure('Name', 'Analyse détaillée des erreurs');
% Plot 1: Erreur au cours du temps
% Montre l'évolution de l'erreur totale pour chaque échantillon
subplot(2,2,1);
time_vector = (start_idx:start_idx+length(errors)-1);
plot(time_vector, errors);
title('Évolution temporelle de l''erreur de position');
xlabel('Numéro d''échantillon');
ylabel('Erreur de position (m)');
grid on;
% Plot 2: Histogramme des erreurs
% Montre la distribution des erreurs (combien d'occurrences pour chaque niveau d'erreur)
subplot(2,2,2);
histogram(errors, 30, 'Normalization', 'probability');
title('Distribution des erreurs');
xlabel('Erreur (m)');
ylabel('Fréquence relative');
% Plot 3: Boxplot des erreurs par dimension
% Montre la distribution des erreurs pour chaque axe (médiane, quartiles, outliers)
subplot(2,2,3);
boxplot(XYZ_estime - gtruth, 'Labels', {'X', 'Y', 'Z'});
title('Distribution des erreurs par axe');
ylabel('Erreur (m)');