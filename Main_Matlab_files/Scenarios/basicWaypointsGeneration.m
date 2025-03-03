% Orientation de la map:
% x vers l'avant y vers la gauche et z vers le haut

% Il faut un minimum 3 secondes sans mouvement au début de chaque scénario

%% Scénario 1

% Génération de la matrice WayPts
WayPts = [
    0, 0, 0,   0;   % Point de départ (x, y, z, t)
    0, 0, 0,   3;
    0, 0,  20,   4;   
    0, 0,  20,   8;  
    0, 30,  20,  15;   
    0, 30,  30,  20;
    0, 30,  15,  30;
   20, 30,  30,  40;
   20, 30,  15,  50;
   40, 30,  30,  60;
   40, 30,  15,  70;
    50, 30,  30,  80;
    50, 30,  15,  90;
    60, 30,  30,  100;
    60, 30,  15,  110;
    60, 30,  30,  120;
    60, 30,  15,  130;
    70, 30,  30,  140;
    70, 30,  15,  150;
    80, 30,  30, 160;
    80, 30,  15, 170;
    80, 0,  30, 180;
    80, 0,  15, 190;
    50, 0,  30, 200;
    35, 0,  15, 210;
    20, 0,  30, 220;
    10, 0,  15, 230;
    0, 0,  30, 240;
    0, 0,  15, 250;
    0, 0,   0, 260;
];

% === NOUVELLE FORME DE WAYPOINTS =====
% (t, x, y, z, phi, theta, psi)

% Transfo:
newWayPts = [WayPts(:, 4) WayPts(:, 1:3) zeros(length(WayPts), 3)];
WayPts = newWayPts;
WayPts(2, 5) = pi;

% Sauvegarde dans un fichier .mat
save('C:\Users\vince\Documents\SEN5\CollaborativeSLAM\Scenarios\10\scenario1Waypoints.mat', 'WayPts');

disp('Matrice WayPts générée et sauvegardée dans scenario1Waypoints.mat.');


%% Scenario 2
% % Matrice de base 
% WayPts = [
%     0, 0, 0,   0;   % Point de départ (x, y, z, t)
%     0, 0,  20,   1;   
%     0, 0,  20,   5;  
%     0, 30,  20,  10;   
%     0, 30,  30,  20;   
%    20, 30,  30,  30;   
%    40,  30,  30,  40;   
%     50,   30,  30,  50;   
%     60, 30,  30,  60;   
%     60, 30,  30,  70;   
%     70,   30,  30,  80;   
%     80,   30,   30, 100;    
%     80,   0,   30, 110;
%     50,   0,   30, 120;
%     20,   0,   30, 130;
%     0,   0,   30, 140;
%     0,   0,   0, 150;
% ];
% 
% % x vers l'avant y vers la gauche et z vers le haut
% % Sauvegarde dans un fichier .mat
% save('Scenarios\scenario2Waypoints.mat', 'WayPts');
% 
% disp('Matrice WayPts générée et sauvegardée dans WayPts.mat.');
% 

% Génération de la matrice WayPts originale
WayPts2 = [
    0, 0, 0,   0;   % Point de départ (x, y, z, t)
    0, 0,  20,   1;   
    0, 0,  20,   5;  
    0, 30,  20,  10;   
    0, 30,  30,  20;   
   20, 30,  30,  30;   
   40,  30,  30,  40;   
    50,   30,  30,  50;   
    60, 30,  30,  60;   
    60, 30,  30,  70;   
    70,   30,  30,  80;   
    60,   30,   30, 100;    
    50,   0,   30, 110;
    0,   0,   30, 120;
    0,   0,   30, 130;
    0,   0,   30, 140;
    0,   0,   0, 150;
];

% Inversion du sens du trajet
WayPts = flipud(WayPts2);

% Mise à jour des temps pour inverser leur sens
WayPts(:, 4) = max(WayPts2(:, 4)) - WayPts(:, 4);


% Sauvegarde dans le nouveau format (t, x, y, z, phi, theta, psi)
newWayPts = [WayPts(:,4), WayPts(:, 1:3) zeros(length(WayPts), 3)];
WayPts = newWayPts;

WayPts(3,2) = 0;
WayPts(3, 5) = pi/2;

% Sauvegarde dans un fichier .mat
save('Scenarios\scenario2Waypoints.mat', 'WayPts');

% Affichage du trajet inversé pour validation
disp('Trajet inversé (WayPts) :');
disp(WayPts);


%% Scenario 3
% Le drone fait un tour de bloc
% Les waypts sont notés sous la forme (deltat, x,y,z, psi)
% On transforme ensuite sous la forme  (t, x, y, z, phi, theta, psi)

a = 10;

WayPts3 = [
    0 0 0 0 0;
    3 0 0 0 0; 
    3 0 0 a 0; % Liftoff

    15 85 0 a 0;        % Waypoint A (75; 0)
    5 75 0 a -pi/2;     % Rotate
    
    15 75 -110 a -pi/2;   % Waypoint B (75; 110)
    5 75 -110 a -pi;     % Rotate

    15 -20 -110 a -pi;    % Waypoint C (-20; 110)
    5 -20 -110 a -3*pi/2;% Rotate

    15 -20 0 a -3*pi/2;% Waypoint D (-20; 0);
    5 -20 0 a -2*pi; % Rotate

    % Back to waypoint A for loop closure
    5 0 0 a -2*pi;        % Waypoint A (75; 0)
    
    3 0 0 0 -2*pi;        % Landing
];

% Build waypoints
numposes = length(WayPts3);
t = zeros(numposes, 1);

prvTime = 0;
for i = 2:numposes
    t(i, 1) = prvTime + WayPts3(i, 1);

    prvTime = t(i, 1);
end

WayPts = [t WayPts3(:,2:5) zeros(numposes, 2) ];

% Sauvegarde dans un fichier .mat
save('scenarios\3\scenarioWaypoints.mat', 'WayPts');

%% Scenario 4
% Le drone un aller retour dans l'allée principale
% Les waypts sont notés sous la forme (deltat, x,y,z, psi)
% On transforme ensuite sous la forme  (t, x, y, z, phi, theta, psi)

a = 4;

WayPts4 = [
    0 0 0 0 0;
    1 0 0 0 0; 

    3 0 0 a 0; % Liftoff
    10 50 0 a 0;        % Waypoint A (55; 0)

    10 50 0 a pi/4;     % Rotate to the left

    5 50 -5 a pi/4;        % Waypoint B (55; 0)

    10 50 -5 a pi/2;     % Rotate to the left

    10 50 0 a pi;     % Rotate to the left



    % 5 50 0 a/2 pi;     % Go down
    % 
    % 15 0 0 a/2 pi;   % Waypoint B (0; 0)
    % 
    % 20 0 0 a/2 2*pi;     % Rotate
    % 5 0 0 0 2*pi;        % Landing
];

% Build waypoints
numposes = length(WayPts4);
t = zeros(numposes, 1);

prvTime = 0;
for i = 2:numposes
    t(i, 1) = prvTime + WayPts4(i, 1);

    prvTime = t(i, 1);
end

WayPts = [t WayPts4(:,2:5) zeros(numposes, 2) ];

% Sauvegarde dans un fichier .mat
save('scenarios\4\scenarioWaypoints.mat', 'WayPts');

%% Attention, le scénario 6 est le test réel

%% Scenario 6
% Le drone un aller retour dans l'allée principale, sans virage
% Les waypts sont notés sous la forme (deltat, x,y,z, psi)
% On transforme ensuite sous la forme  (t, x, y, z, phi, theta, psi)

% Altitude
a1 = 4;
a2 = 8;

WayPts6 = [
    0 0 0 0 0;
    1 0 0 0 0; 

    3  0  0 a1 0;          % Liftoff
    10 50 0 a1 0;      % Waypoint A (55; 0; A1)

    5 50 0 a2 0;    % Waypoint B (55; 0; A2) [Go up]

    15 -5 0 a2 0;     % Waypoint C (-5; 0; A2)  [Go back]

    10 0 0 a1 0;     % Rotate to the left   [Go to origin, down]

    5 0 0 0 0;        % Landing
];

% Build waypoints
numposes = length(WayPts6);
t = zeros(numposes, 1);

prvTime = 0;
for i = 2:numposes
    t(i, 1) = prvTime + WayPts6(i, 1);

    prvTime = t(i, 1);
end

WayPts = [t WayPts6(:,2:5) zeros(numposes, 2) ];

% Sauvegarde dans un fichier .mat
save('6/scenarioWaypoints.mat', 'WayPts');

%% Scenario 7
% Le drone un aller retour dans l'allée principale, sans virage
% Les waypts sont notés sous la forme (deltat, x,y,z, psi)
% On transforme ensuite sous la forme  (t, x, y, z, phi, theta, psi)

% Altitude
a1 = 4;
a2 = 8;

WayPts7 = [
    0 0 0 0 0;
    1 0 0 0 0; 

    3  0  0 a1 0;          % Liftoff
    10 50 0 a1 0;      % Waypoint A (55; 0; A1)

    5 50 0 a2 0;    % Waypoint B (55; 0; A2) [Go up]

    15 -5 0 a2 0;     % Waypoint C (-5; 0; A2)  [Go back]

    10 0 0 a1 0;     % Rotate to the left   [Go to origin, down]

    5 0 0 0 0;        % Landing
];

% Build waypoints
numposes = length(WayPts7);
t = zeros(numposes, 1);

prvTime = 0;
for i = 2:numposes
    t(i, 1) = prvTime + WayPts7(i, 1);

    prvTime = t(i, 1);
end

WayPts = [t WayPts7(:,2:5) zeros(numposes, 2) ];

% Sauvegarde dans un fichier .mat
save('7/scenarioWaypoints.mat', 'WayPts');

%% Scenario 8
% Le drone un aller retour dans l'allée principale, avec virage
% Les waypts sont notés sous la forme (deltat, x,y,z, psi)
% On transforme ensuite sous la forme  (t, x, y, z, phi, theta, psi)

% Altitude
a1 = 4;
a2 = 8;

%    [Land]
% 
%       E <=================
% C ========================> D     --- a2
% ^                           
% ^                           
% A <======================== B     
% A ========================> B     --- a1
% ^
% ^
% O

% Temps de déplacement entre deux waypoints
Dt = 12; % secondes

% Temps de rotation
Dr = 25; % secondes

WayPts8 = [
    0 0 0 0 0;
    1 0 0 0 0; 

    3  0  0 a1 0;      % Liftoff (A)
    Dt 50 0 a1 0;      %  B

    2 50 0 a1 0;       % Ne pas bouger pendant X secondes

    Dt  65 0 a1 pi;    % Turn and slide to the right

    Dt 0 0 a1 pi;      % A (0; 0; A1)  [Go back to origin]
    Dr -15 0 a1 2*pi;  % [Turn left at A]

    5 -15 0 a2 2*pi;   % [Go up] to waypoint C (0; 0; A2)

    Dt 50 0 a2 2*pi;   % D (50; 0; A2)
    Dr 65 0 a2 3*pi;   % [Turn left at D]

    Dt 15 0 a2 3*pi;   % Waypoint E (15; 0; A2)

    10 15 0 0 3*pi;     % Landing
];

% Build waypoints
numposes = length(WayPts8);
t = zeros(numposes, 1);

prvTime = 0;
for i = 2:numposes
    t(i, 1) = prvTime + WayPts8(i, 1);

    prvTime = t(i, 1);
end

WayPts = [t WayPts8(:,2:5) zeros(numposes, 2) ];

% Sauvegarde dans un fichier .mat
save('8/scenarioWaypoints.mat', 'WayPts');

%% Scenario 9

% Altitude
a1 = 4;
a2 = 8;

% Altitude
a1 = 4;
a2 = 8;

% Travel time
tt = 15;

% Up tipe
ut = 5;

% Rotate time
rt = 10;

ya = 2;
yb= -2;
% Drone A
%
% D <================ C
%                     ^
%                     ^
% A ================> B
BasicWayPts9A = [
    0 0 ya 0 0;
    1 0 ya 0 0; 

    3  0  ya a1 0;    % Liftoff at A
    tt 50 ya a1 0;    % Go to B
    ut 50 ya a2 0;     % Go up to C
    rt 50 ya a2 pi; % Rotate
    tt 0 ya a2 pi;     % Go to D

    5 0 ya 0 pi;        % Landing
];

% Drone B
% D ================> C
% ^                   
% ^                   
% A <================ B
BasicWayPts9B = [
    0 50 yb 0 -pi;
    1 50 yb 0 -pi; 

    3  50  yb a1 -pi;    % Liftoff at B
    tt 0 yb a1 -pi;      % Go to A
    ut 0 yb a2 -pi;       % Go up to D

    rt 0  yb a2 0;      % Rotate
    tt 50 yb a2 0;       % Go to C

    5 50 yb 0 0;        % Landing
];

WayPts9A = buildWaypoints(BasicWayPts9A);
WayPts9B = buildWaypoints(BasicWayPts9B);

% Sauvegarde dans un fichier .mat
WayPts = WayPts9A;
save('9a/scenarioWaypoints.mat', 'WayPts');

WayPts = WayPts9B;
save('9b/scenarioWaypoints.mat', 'WayPts');


% Function to build all the waypoints from basic waypoint list
function waypoints = buildWaypoints(points)
    % Build waypoints
    numposes = length(points);
    t = zeros(numposes, 1);
    
    prvTime = 0;
    for i = 2:numposes
        t(i, 1) = prvTime + points(i, 1);
    
        prvTime = t(i, 1);
    end
    
    waypoints = [t points(:,2:5) zeros(numposes, 2) ];
end