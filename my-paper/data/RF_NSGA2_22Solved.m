function RF_NSGA2_22Solved()
%% Two-stage RF surrogate + baselines + figures + NSGA-II optimization
% Comfort is treated as "satisficing" (Comfort>=7), then optimize for health.

clc; close all;
rng('default');

%% ===================== 0) Settings =====================
filePath = 'E:\RTGXTP2\shuju.xlsx';
outDir = fullfile(pwd, 'surrogate_outputs');
if ~exist(outDir, 'dir'); mkdir(outDir); end

tauRULA  = 3;     % low risk if RULA<=3
kComfort = 7;     % high comfort if Comfort>=7

K = 5;            % subject-grouped CV

% ---- Random search ----
% If you want to change random search iterations, edit here
nRand = 50;
% If you want to change MinLeaf range, edit here
minLeafRange = [3, 12];

riskW = 0.70;
comfW = 0.30;

% ---- Optimization switches ----
doOptimize = true;
fastOptimize = true;

% ---- Health-first + comfort-satisficing thresholds (USED IN OPTIMIZATION) ----
riskProbThresh    = 0.70;  % used for plotting/reference only
comfortProbThresh = 0.80;  % **comfort constraint**: require P(Comfort>=7) >= alpha
penaltyWeight     = 50;    % constraint penalty strength

% NSGA-II settings
popSize_fast = 60;   maxGen_fast = 30;
popSize_slow = 150;  maxGen_slow = 80;

% Example target user
target_human = [1, 175, 70, 92, 42, 46];

% Chair bounds (Table 3)
lb = [42.0, 47.5, 95.0, 17.0, 13.0, 55.0];
ub = [50.0, 53.5, 140.0, 23.0, 18.0, 69.0];

% Disable TreeBagger internal parallel (fix parallel-related errors)
tbOpts = statset('UseParallel', false);

%% ===================== 1) Load data =====================
T = readtable(filePath);

col_human = {'Gender', 'Sub_Stature', 'Sub_Weight', ...
             'Sub_Sitting_Height', 'Sub_Popliteal_Height', 'Sub_Buttock_Pop_Len'};
col_chair = {'Chair_Seat_Height', 'Chair_Seat_Depth', 'Chair_Backrest_Angle', ...
             'Chair_Armrest_Height', 'Chair_Lumbar_Height', 'Chair_Headrest_Height'};
col_pose  = {'Neck_Flexion','Trunk_Flexion','Upper_Arm_Flexion','Elbow_Angle','Knee_Angle'};

mustCols = [{'Subject_ID'}, col_human, col_chair, col_pose, {'Comfort_Rating','RULA_Final'}];
missing = setdiff(mustCols, T.Properties.VariableNames);
if ~isempty(missing)
    error('Missing columns: %s', strjoin(missing, ', '));
end

subj = T.Subject_ID;
if isnumeric(subj); subj = string(subj); end
subj = categorical(subj);

X0 = [T{:,col_human}, T{:,col_chair}];
Y_pose = T{:,col_pose};
Yc = T.Comfort_Rating;
Yr = T.RULA_Final;

valid = all(~isnan(X0),2) & all(~isnan(Y_pose),2) & ~isnan(Yc) & ~isnan(Yr) & ~isundefined(subj);
X0 = X0(valid,:);
Y_pose = Y_pose(valid,:);
Yc = Yc(valid);
Yr = Yr(valid);
subj = subj(valid);

fprintf('Data: %d trials, %d subjects\n', size(X0,1), numel(categories(subj)));

yRisk = double(Yr <= tauRULA);
yComf = double(Yc >= kComfort);
fprintf('Class balance: P(lowRisk)=%.3f | P(highComfort>=%.0f)=%.3f\n', mean(yRisk), kComfort, mean(yComf));

%% ===================== 2) Subject-grouped folds =====================
subjList = categories(subj);
nSubj = numel(subjList);
if K > nSubj
    error('K=%d > #subjects=%d', K, nSubj);
end
cvp_subj = cvpartition(nSubj, 'KFold', K);
getFoldMask = @(k) deal( ...
    ismember(subj, subjList(training(cvp_subj,k))), ...
    ismember(subj, subjList(test(cvp_subj,k))) );

%% ===================== 3) Random search (cache OOF of selected best iteration) =====================
[best, aucTune] = randTune_andCacheOOF( ...
    X0, Y_pose, yRisk, yComf, getFoldMask, K, nRand, minLeafRange, riskW, comfW, tbOpts, outDir);

fprintf('\n[Best-Tune] it=%d seed=%d score=%.4f\n', best.it, best.seed, best.score);
fprintf('Pose: nT=%d leaf=%d mode=%s\n', best.pose_nTrees, best.pose_minLeaf, best.pose_mode);
fprintf('Risk: nT=%d leaf=%d mode=%s\n', best.risk_nTrees, best.risk_minLeaf, best.risk_mode);
fprintf('Comf: nT=%d leaf=%d mode=%s\n', best.comf_nTrees, best.comf_minLeaf, best.comf_mode);
fprintf('Tune AUCs (cached OOF): Risk=%.3f | Comfort=%.3f | PoseMAE=%.2f\n', aucTune.aucR, aucTune.aucC, aucTune.poseMAE);

%% ===================== 4) Best-OOF (from cached OOF) =====================
auc = struct();
auc.RF_risk = calcAUC(yRisk, best.oof_pLowRisk);
auc.RF_comf = calcAUC(yComf, best.oof_pHighComf);

fprintf('\n[Best-OOF (cached)] Risk AUC=%.3f | Comfort AUC=%.3f (Comfort>=%d)\n', auc.RF_risk, auc.RF_comf, kComfort);

% baselines with same info (X0 + cached OOF poseHat)
oofLog = oof_LogReg_withPose(X0, best.oof_poseHat, yRisk, yComf, getFoldMask, K);
oofSVM = oof_SVM_withPose(X0, best.oof_poseHat, yRisk, yComf, getFoldMask, K);

auc.Log_risk = calcAUC(yRisk, oofLog.pLowRisk);
auc.Log_comf = calcAUC(yComf, oofLog.pHighComf);
auc.SVM_risk = calcAUC(yRisk, oofSVM.pLowRisk);
auc.SVM_comf = calcAUC(yComf, oofSVM.pHighComf);

fprintf('\n=== OOF metrics (consistent by construction) ===\n');
fprintf('Risk AUC:    RF=%.3f | LogReg+Pose=%.3f | SVM+Pose=%.3f\n', auc.RF_risk, auc.Log_risk, auc.SVM_risk);
fprintf('Comfort AUC: RF=%.3f | LogReg+Pose=%.3f | SVM+Pose=%.3f\n', auc.RF_comf, auc.Log_comf, auc.SVM_comf);

%% ===================== 5) Figures (ALL from cached OOF) =====================
poseMAE  = mean(abs(Y_pose - best.oof_poseHat), 1);
poseRMSE = sqrt(mean((Y_pose - best.oof_poseHat).^2, 1));

fig = figure('Color','w','Name','Pose CV Error');
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile; bar(poseMAE); grid on;
set(gca,'XTick',1:numel(col_pose),'XTickLabel',col_pose,'XTickLabelRotation',30);
ylabel('MAE (deg)'); title('Pose MAE (OOF, cached)');
nexttile; bar(poseRMSE); grid on;
set(gca,'XTick',1:numel(col_pose),'XTickLabel',col_pose,'XTickLabelRotation',30);
ylabel('RMSE (deg)'); title('Pose RMSE (OOF, cached)');
exportgraphics(fig, fullfile(outDir,'pose_error_cv.png'), 'Resolution', 300);

fig = figure('Color','w','Name','ROC Risk (OOF)');
hold on; grid on; box on;
plotROC(yRisk, best.oof_pLowRisk,  sprintf('RF (AUC=%.3f)', auc.RF_risk));
plotROC(yRisk, oofLog.pLowRisk,    sprintf('LogReg+Pose (AUC=%.3f)', auc.Log_risk));
plotROC(yRisk, oofSVM.pLowRisk,    sprintf('SVM+Pose (AUC=%.3f)', auc.SVM_risk));
xlabel('FPR'); ylabel('TPR');
title(sprintf('Risk ROC (RULA<=%d)', tauRULA));
legend('Location','best'); hold off;
exportgraphics(fig, fullfile(outDir,'roc_risk_cv.png'), 'Resolution', 300);

fig = figure('Color','w','Name','ROC Comfort (OOF)');
hold on; grid on; box on;
plotROC(yComf, best.oof_pHighComf, sprintf('RF (AUC=%.3f)', auc.RF_comf));
plotROC(yComf, oofLog.pHighComf,   sprintf('LogReg+Pose (AUC=%.3f)', auc.Log_comf));
plotROC(yComf, oofSVM.pHighComf,   sprintf('SVM+Pose (AUC=%.3f)', auc.SVM_comf));
xlabel('FPR'); ylabel('TPR');
title(sprintf('Comfort ROC (Comfort>=%d)', kComfort));
legend('Location','best'); hold off;
exportgraphics(fig, fullfile(outDir,'roc_comfort_cv.png'), 'Resolution', 300);

fig = figure('Color','w','Name','AUC Comparison');
models = {'RF','LogReg+Pose','SVM+Pose'};
riskVals = [auc.RF_risk, auc.Log_risk, auc.SVM_risk];
comfVals = [auc.RF_comf, auc.Log_comf, auc.SVM_comf];
bar([riskVals; comfVals]'); grid on; box on;
set(gca,'XTickLabel',models);
ylabel('AUC');
legend({sprintf('Risk (RULA<=%d)',tauRULA), sprintf('Comfort (>= %d)',kComfort)}, 'Location','best');
title('Model comparison (OOF, cached RF)');
exportgraphics(fig, fullfile(outDir,'auc_comparison_cv.png'), 'Resolution', 300);

fig = figure('Color','w','Name','Prob Scatter (OOF, RF cached)');
gscatter(best.oof_pLowRisk, best.oof_pHighComf, categorical(yRisk,[0 1],{'highRisk','lowRisk'}));
grid on; box on;
xline(riskProbThresh, '--k', 'LineWidth', 1.2);
yline(comfortProbThresh, '--k', 'LineWidth', 1.2);
xlabel(sprintf('P(RULA<=%d) (OOF)', tauRULA));
ylabel(sprintf('P(Comfort>=%d) (OOF)', kComfort));
title('Predicted probabilities (OOF, cached RF)');
exportgraphics(fig, fullfile(outDir,'prob_scatter_cv.png'), 'Resolution', 300);

summaryTbl = table(models(:), riskVals(:), comfVals(:), 'VariableNames', {'Model','AUC_Risk','AUC_Comfort'});
writetable(summaryTbl, fullfile(outDir,'auc_summary_table.csv'));

save(fullfile(outDir,'best_and_auc.mat'), 'best', 'auc', 'tauRULA', 'kComfort', 'minLeafRange', 'nRand');

%% ===================== 6) Train final RF models on full data (for optimization) =====================
% NOTE: this is for NSGA-II fitness evaluation, not for reporting OOF AUC.
rng(best.seed, 'twister');
modelsRF = trainFinal_twoStage_RF_flatBest(X0, Y_pose, yRisk, yComf, best, tbOpts);

%% ===================== 7) Optimization (Comfort-satisficing, Health-first) =====================
if doOptimize
    fprintf('\n=== Starting NSGA-II optimization (Comfort constraint, Health-first) ===\n');
    if fastOptimize
        popSize = popSize_fast; maxGen = maxGen_fast;
        fprintf('[Optimize] FAST: pop=%d gen=%d\n', popSize, maxGen);
    else
        popSize = popSize_slow; maxGen = maxGen_slow;
        fprintf('[Optimize] SLOW: pop=%d gen=%d\n', popSize, maxGen);
    end

    % To be safe with your previous parallel errors, keep NSGA-II serial first.
    usePar = false;

    fitnessFcn = @(z) fitness_healthFirst_withComfortConstraint(z, target_human, modelsRF, comfortProbThresh, penaltyWeight);

    options = optimoptions('gamultiobj', ...
        'PopulationSize', popSize, ...
        'MaxGenerations', maxGen, ...
        'Display','iter', ...
        'UseParallel', usePar);

    [z_pop, fvals] = gamultiobj(fitnessFcn, 6, [], [], [], [], lb, ub, options);

    pLow_pop = -fvals(:,1);   % because f1=-pLow
    pen_pop  =  fvals(:,2);   % comfort penalty

    % compute pHigh for all solutions (for reporting/plotting)
    pHigh_pop = nan(size(pLow_pop));
    for i = 1:size(z_pop,1)
        [pLow_i, pHigh_i] = predictProbs_twoStage(modelsRF, target_human, z_pop(i,:));
        pHigh_pop(i) = pHigh_i;
    end

    feasible = (pHigh_pop >= comfortProbThresh);
    idxFea = find(feasible);

    if ~isempty(idxFea)
        [~, ii] = max(pLow_pop(idxFea));
        idxStar = idxFea(ii);
    else
        [~, idxStar] = min(pen_pop - 0.01*pLow_pop);
    end

    zStar = z_pop(idxStar,:);
    [pLowStar, pHighStar] = predictProbs_twoStage(modelsRF, target_human, zStar);

    fprintf('\n=== Recommended chair settings ===\n');
    names = {'Seat Height','Seat Depth','Backrest Angle','Armrest Height','Lumbar Height','Headrest Height'};
    for j=1:6
        fprintf('%s: %.2f\n', names{j}, zStar(j));
    end
    fprintf('Pred P(RULA<=%d)=%.3f | Pred P(Comfort>=%d)=%.3f | ComfortThresh=%.2f\n', ...
        tauRULA, pLowStar, kComfort, pHighStar, comfortProbThresh);

    fig = figure('Color','w','Name','Optimization scatter');
    hold on; grid on; box on;
    scatter(pLow_pop, pHigh_pop, 45, [0.2 0.5 0.8], 'filled');
    plot(pLowStar, pHighStar, 'rp', 'MarkerSize', 16, 'MarkerFaceColor','r');
    xline(riskProbThresh, '--k', 'LineWidth', 1.2);
    yline(comfortProbThresh, '--k', 'LineWidth', 1.2);
    xlabel(sprintf('P(RULA<=%d)', tauRULA));
    ylabel(sprintf('P(Comfort>=%d)', kComfort));
    title('NSGA-II solutions (comfort-satisficing, health-first)');
    hold off;
    exportgraphics(fig, fullfile(outDir,'opt_scatter_healthFirst.png'), 'Resolution', 300);
end

fprintf('\nAll outputs saved to: %s\n', outDir);
end

%% =====================================================================
%% Random tune AND cache OOF predictions for the best iteration
function [best, aucTune] = randTune_andCacheOOF(X0, Y_pose, yRisk, yComf, getFoldMask, K, nIter, minLeafRange, riskW, comfW, tbOpts, outDir)

nTreesSet_pose = [100, 200, 300, 500];
nTreesSet_cls  = [100, 200, 300, 500];
modeSet = {'sqrt','third','all'};

bestScore = inf;
best = struct('it',0,'seed',0,'score',inf);
best.oof_pLowRisk = [];
best.oof_pHighComf = [];
best.oof_poseHat = [];

logFile = fullfile(outDir, 'rand_tune_log.txt');
fid = fopen(logFile,'w');
fprintf(fid, 'it,seed,aucR,aucC,poseMAE,score,pose_nTrees,pose_leaf,pose_mode,risk_nTrees,risk_leaf,risk_mode,comf_nTrees,comf_leaf,comf_mode\n');

fprintf('\n[RandTune] %d iters, MinLeaf in [%d,%d]...\n', nIter, minLeafRange(1), minLeafRange(2));

for it = 1:nIter
    seed = 1000 + it;
    rng(seed, 'twister');

    pose_nTrees = nTreesSet_pose(randi(numel(nTreesSet_pose)));
    pose_minLeaf = randi(minLeafRange);
    pose_mode = modeSet{randi(numel(modeSet))};

    risk_nTrees = nTreesSet_cls(randi(numel(nTreesSet_cls)));
    risk_minLeaf = randi(minLeafRange);
    risk_mode = modeSet{randi(numel(modeSet))};

    comf_nTrees = nTreesSet_cls(randi(numel(nTreesSet_cls)));
    comf_minLeaf = randi(minLeafRange);
    comf_mode = modeSet{randi(numel(modeSet))};

    phat_r = nan(size(yRisk));
    phat_c = nan(size(yComf));
    poseHat = nan(size(Y_pose));

    for k = 1:K
        [idxTr, idxTe] = getFoldMask(k);

        Xtr = X0(idxTr,:); Xte = X0(idxTe,:);
        mu_k = mean(Xtr,1);
        sd_k = std(Xtr,0,1); sd_k(sd_k==0)=1;
        Xtr_n = (Xtr - mu_k)./sd_k;
        Xte_n = (Xte - mu_k)./sd_k;

        p0 = size(Xtr_n,2);
        numPred_pose = mode2numPred(pose_mode, p0);

        poseModels = cell(1, size(Y_pose,2));
        for j = 1:size(Y_pose,2)
            poseModels{j} = TreeBagger(pose_nTrees, Xtr_n, Y_pose(idxTr,j), ...
                'Method','regression', 'MinLeafSize', pose_minLeaf, ...
                'NumPredictorsToSample', numPred_pose, 'Options', tbOpts);
        end

        Pose_tr = zeros(sum(idxTr), size(Y_pose,2));
        Pose_te = zeros(sum(idxTe), size(Y_pose,2));
        for j = 1:size(Y_pose,2)
            Pose_tr(:,j) = predict(poseModels{j}, Xtr_n);
            Pose_te(:,j) = predict(poseModels{j}, Xte_n);
        end
        poseHat(idxTe,:) = Pose_te;

        Xtr_feat = [Xtr_n, Pose_tr];
        Xte_feat = [Xte_n, Pose_te];

        numPred_risk = mode2numPred(risk_mode, size(Xtr_feat,2));
        mdlR = TreeBagger(risk_nTrees, Xtr_feat, categorical(yRisk(idxTr),[0 1],{'highRisk','lowRisk'}), ...
            'Method','classification', 'MinLeafSize', risk_minLeaf, ...
            'NumPredictorsToSample', numPred_risk, 'Options', tbOpts);
        [~, postR] = predict(mdlR, Xte_feat);
        idxLow = find(strcmp(string(mdlR.ClassNames), 'lowRisk'), 1);
        phat_r(idxTe) = postR(:, idxLow);

        numPred_comf = mode2numPred(comf_mode, size(Xtr_feat,2));
        mdlC = TreeBagger(comf_nTrees, Xtr_feat, categorical(yComf(idxTr),[0 1],{'low','high'}), ...
            'Method','classification', 'MinLeafSize', comf_minLeaf, ...
            'NumPredictorsToSample', numPred_comf, 'Options', tbOpts);
        [~, postC] = predict(mdlC, Xte_feat);
        idxHigh = find(strcmp(string(mdlC.ClassNames), 'high'), 1);
        phat_c(idxTe) = postC(:, idxHigh);
    end

    aucR = calcAUC(yRisk, phat_r);
    aucC = calcAUC(yComf, phat_c);
    poseMAE = mean(mean(abs(Y_pose - poseHat), 2), 1);
    score = riskW*(1-aucR) + comfW*(1-aucC) + 0.01*poseMAE;

    fprintf('[Rand %02d/%02d] AUC_R=%.3f AUC_C=%.3f PoseMAE=%.2f score=%.4f\n', it, nIter, aucR, aucC, poseMAE, score);

    fprintf(fid, '%d,%d,%.6f,%.6f,%.6f,%.6f,%d,%d,%s,%d,%d,%s,%d,%d,%s\n', ...
        it, seed, aucR, aucC, poseMAE, score, ...
        pose_nTrees, pose_minLeaf, pose_mode, ...
        risk_nTrees, risk_minLeaf, risk_mode, ...
        comf_nTrees, comf_minLeaf, comf_mode);

    if score < bestScore
        bestScore = score;

        best.it = it;
        best.seed = seed;
        best.score = score;

        best.pose_nTrees = pose_nTrees;
        best.pose_minLeaf = pose_minLeaf;
        best.pose_mode = pose_mode;

        best.risk_nTrees = risk_nTrees;
        best.risk_minLeaf = risk_minLeaf;
        best.risk_mode = risk_mode;

        best.comf_nTrees = comf_nTrees;
        best.comf_minLeaf = comf_minLeaf;
        best.comf_mode = comf_mode;

        best.oof_pLowRisk = phat_r;
        best.oof_pHighComf = phat_c;
        best.oof_poseHat = poseHat;

        best.aucR_tune = aucR;
        best.aucC_tune = aucC;
        best.poseMAE_tune = poseMAE;
    end
end

fclose(fid);

aucTune.aucR = best.aucR_tune;
aucTune.aucC = best.aucC_tune;
aucTune.poseMAE = best.poseMAE_tune;
end

%% =====================================================================
%% Train final RF models (flat best) for NSGA-II
function modelsRF = trainFinal_twoStage_RF_flatBest(X0, Y_pose, yRisk, yComf, best, tbOpts)

modelsRF.mu = mean(X0,1);
modelsRF.sd = std(X0,0,1); modelsRF.sd(modelsRF.sd==0)=1;
X0n = (X0 - modelsRF.mu)./modelsRF.sd;

p0 = size(X0n,2);
numPred_pose = mode2numPred(best.pose_mode, p0);

modelsRF.poseModels = cell(1, size(Y_pose,2));
for j = 1:size(Y_pose,2)
    modelsRF.poseModels{j} = TreeBagger(best.pose_nTrees, X0n, Y_pose(:,j), ...
        'Method','regression', 'MinLeafSize', best.pose_minLeaf, ...
        'NumPredictorsToSample', numPred_pose, 'Options', tbOpts);
end

PoseHat = zeros(size(X0n,1), size(Y_pose,2));
for j = 1:size(Y_pose,2)
    PoseHat(:,j) = predict(modelsRF.poseModels{j}, X0n);
end
Xfeat = [X0n, PoseHat];

numPred_risk = mode2numPred(best.risk_mode, size(Xfeat,2));
modelsRF.riskModel = TreeBagger(best.risk_nTrees, Xfeat, categorical(yRisk,[0 1],{'highRisk','lowRisk'}), ...
    'Method','classification', 'MinLeafSize', best.risk_minLeaf, ...
    'NumPredictorsToSample', numPred_risk, 'Options', tbOpts);

numPred_comf = mode2numPred(best.comf_mode, size(Xfeat,2));
modelsRF.comfModel = TreeBagger(best.comf_nTrees, Xfeat, categorical(yComf,[0 1],{'low','high'}), ...
    'Method','classification', 'MinLeafSize', best.comf_minLeaf, ...
    'NumPredictorsToSample', numPred_comf, 'Options', tbOpts);
end

%% =====================================================================
%% Optimization fitness: health-first + comfort constraint penalty
function f = fitness_healthFirst_withComfortConstraint(chair, human, modelsRF, comfortProbThresh, penaltyWeight)
    [pLow, pHigh] = predictProbs_twoStage(modelsRF, human, chair);

    f1 = -pLow;  % maximize health probability

    shortfall = max(0, comfortProbThresh - pHigh);
    f2 = penaltyWeight * (shortfall^2); % 0 if comfort constraint met

    f = [f1, f2];
end

function [pLow, pHigh] = predictProbs_twoStage(modelsRF, human, chair)
    x0 = [human, chair];
    x0n = (x0 - modelsRF.mu) ./ modelsRF.sd;

    poseHat = zeros(1, numel(modelsRF.poseModels));
    for j = 1:numel(modelsRF.poseModels)
        poseHat(j) = predict(modelsRF.poseModels{j}, x0n);
    end

    xFeat = [x0n, poseHat];

    [~, postR] = predict(modelsRF.riskModel, xFeat);
    idxLow = find(strcmp(string(modelsRF.riskModel.ClassNames), 'lowRisk'), 1);
    pLow = postR(:, idxLow);

    [~, postC] = predict(modelsRF.comfModel, xFeat);
    idxHigh = find(strcmp(string(modelsRF.comfModel.ClassNames), 'high'), 1);
    pHigh = postC(:, idxHigh);
end

%% =====================================================================
%% Fitness (original two-objective, kept for reference)
function f = fitness_twoStage(chair, human, modelsRF)
    [pLow, pHigh] = predictProbs_twoStage(modelsRF, human, chair);
    f = [-pHigh, -pLow];
end

%% =====================================================================
%% Baselines
function oof = oof_LogReg_withPose(X0, poseHatOOF, yRisk, yComf, getFoldMask, K)
oof.pLowRisk = nan(size(yRisk));
oof.pHighComf = nan(size(yComf));
Xfull = [X0, poseHatOOF];

for k = 1:K
    [idxTr, idxTe] = getFoldMask(k);

    Xtr = Xfull(idxTr,:); Xte = Xfull(idxTe,:);
    mu_k = mean(Xtr,1);
    sd_k = std(Xtr,0,1); sd_k(sd_k==0)=1;
    Xtr_n = (Xtr - mu_k)./sd_k;
    Xte_n = (Xte - mu_k)./sd_k;

    mdlR = fitglm(Xtr_n, yRisk(idxTr), 'Distribution','binomial');
    oof.pLowRisk(idxTe) = predict(mdlR, Xte_n);

    mdlC = fitglm(Xtr_n, yComf(idxTr), 'Distribution','binomial');
    oof.pHighComf(idxTe) = predict(mdlC, Xte_n);
end
end

function oof = oof_SVM_withPose(X0, poseHatOOF, yRisk, yComf, getFoldMask, K)
oof.pLowRisk = nan(size(yRisk));
oof.pHighComf = nan(size(yComf));
Xfull = [X0, poseHatOOF];

for k = 1:K
    [idxTr, idxTe] = getFoldMask(k);

    Xtr = Xfull(idxTr,:); Xte = Xfull(idxTe,:);
    mu_k = mean(Xtr,1);
    sd_k = std(Xtr,0,1); sd_k(sd_k==0)=1;
    Xtr_n = (Xtr - mu_k)./sd_k;
    Xte_n = (Xte - mu_k)./sd_k;

    ytrR = categorical(yRisk(idxTr), [0 1], {'highRisk','lowRisk'});
    mdlR = fitcsvm(Xtr_n, ytrR, 'KernelFunction','rbf', 'Standardize',false);
    try
        mdlR = fitPosterior(mdlR, Xtr_n, ytrR);
        [~, postR] = predict(mdlR, Xte_n);
        idxLow = find(strcmp(string(mdlR.ClassNames),'lowRisk'),1);
        oof.pLowRisk(idxTe) = postR(:, idxLow);
    catch
        [~, score] = predict(mdlR, Xte_n);
        s = score(:, min(2,size(score,2)));
        oof.pLowRisk(idxTe) = 1./(1+exp(-s));
    end

    ytrC = categorical(yComf(idxTr), [0 1], {'low','high'});
    mdlC = fitcsvm(Xtr_n, ytrC, 'KernelFunction','rbf', 'Standardize',false);
    try
        mdlC = fitPosterior(mdlC, Xtr_n, ytrC);
        [~, postC] = predict(mdlC, Xte_n);
        idxHigh = find(strcmp(string(mdlC.ClassNames),'high'),1);
        oof.pHighComf(idxTe) = postC(:, idxHigh);
    catch
        [~, score] = predict(mdlC, Xte_n);
        s = score(:, min(2,size(score,2)));
        oof.pHighComf(idxTe) = 1./(1+exp(-s));
    end
end
end

%% =====================================================================
%% Utilities
function auc = calcAUC(yTrue01, pScore)
[~,~,~,auc] = perfcurve(yTrue01, pScore, 1);
end

function plotROC(yTrue01, pScore, labelStr)
[x,y,~,~] = perfcurve(yTrue01, pScore, 1);
plot(x,y,'LineWidth',1.6,'DisplayName',labelStr);
end

function numPred = mode2numPred(mode, p)
switch lower(mode)
    case 'all'
        numPred = p;
    case 'sqrt'
        numPred = max(1, floor(sqrt(p)));
    case 'third'
        numPred = max(1, floor(p/3));
    otherwise
        error('Unknown mode');
end
end

function usePar = tryStartParallel()
usePar = false;
try
    parpool;
    usePar = true;
    fprintf('[Parallel] Enabled.\n');
catch
    usePar = false;
    fprintf('[Parallel] Not available, continue in serial.\n');
end
end
