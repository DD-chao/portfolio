function RF_NSGA2_22Solved_Final()
%% Final paper-ready pipeline (FULL):
% (1) Tuned subject-grouped OOF model comparison (cached OOF for consistency)
% (2) Nested subject-grouped CV + 95% CI (generalization estimate)
% (3) Probability calibration: Brier + reliability diagram (RF)
% (4) Optimization: comfort-satisficing + health-first NSGA-II (formal settings)
%
% Notes:
% - TreeBagger internal parallel disabled for stability.
% - SVM baseline uses decision scores only (no fitPosterior), avoiding warnings.
% - All figures/tables saved to outDir.

clc; close all;
rng('default');

%% ===================== 0) User settings =====================
% ---- Data ----
filePath = 'E:\RTGXTP2\shuju.xlsx';   % <-- CHANGE THIS
outDir   = fullfile(pwd, 'surrogate_outputs_final');
if ~exist(outDir, 'dir'); mkdir(outDir); end

% ---- Task thresholds ----
tauRULA  = 3;    % low risk label: RULA <= 3
kComfort = 7;    % high comfort label: Comfort >= 7 (Likert 1-9)

% ---- Tuned OOF for model comparison ----
K_oof = 5;       % subject-grouped K-fold for tuned OOF

% ---- Random search for tuned OOF (model selection) ----
nRand = 80;                 % **key point** increase for final run (was 50)
minLeafRange = [3, 12];
riskW = 0.70;
comfW = 0.30;
poseW = 0.01;

nTreesSet_pose = [100, 200, 300, 500];
nTreesSet_cls  = [100, 200, 300, 500];
modeSet = {'sqrt','third','all'};

% ---- Nested CV (generalization) ----
runNested = true;
K_outer = 5;
K_inner = 3;
nRand_inner = 40;            % **key point** increase for final run (was 20)
nTreesSet_pose_nested = [200, 500];
nTreesSet_cls_nested  = [200, 500];

% ---- Calibration ----
runCalibration = true;
nCalibBins = 10;

% ---- Optimization (FORMAL settings) ----
runOptimize = true;
fastOptimize = false;        % **key point** formal run
popSize_fast = 60;  maxGen_fast = 30;
popSize_slow = 150; maxGen_slow = 80;   % **key point** formal parameters

% comfort-satisficing & health-first
comfortProbThresh = 0.80;   % require P(Comfort>=7) >= alpha
penaltyWeight     = 50;     % comfort constraint penalty
riskProbRefLine   = 0.70;   % reference line for plotting only

% target user (example)
target_human = [1, 175, 70, 92, 42, 46];

% chair bounds (Table 3)
lb = [42.0, 47.5, 95.0, 17.0, 13.0, 55.0];
ub = [50.0, 53.5, 140.0, 23.0, 18.0, 69.0];

% ---- Stability: disable TreeBagger internal parallel ----
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

N = size(X0,1);
fprintf('Data: %d trials, %d subjects\n', N, numel(categories(subj)));

yRisk = double(Yr <= tauRULA);
yComf = double(Yc >= kComfort);
fprintf('Class balance: P(lowRisk)=%.3f | P(highComfort>=%d)=%.3f\n', mean(yRisk), kComfort, mean(yComf));

%% ===================== 2) Subject-grouped folds (OOF) =====================
[~, getFoldMask_oof] = makeSubjectGroupedFolds(subj, K_oof);

%% ===================== 3) Tuned OOF model selection (cache best OOF predictions) =====================
[best, aucTune, tuneLogTbl] = randTune_andCacheOOF( ...
    X0, Y_pose, yRisk, yComf, getFoldMask_oof, K_oof, ...
    nRand, minLeafRange, nTreesSet_pose, nTreesSet_cls, modeSet, ...
    riskW, comfW, poseW, tbOpts);

writetable(tuneLogTbl, fullfile(outDir,'rand_tune_log.csv'));

fprintf('\n[Best-Tune] it=%d seed=%d score=%.4f\n', best.it, best.seed, best.score);
fprintf('Pose: nT=%d leaf=%d mode=%s\n', best.pose_nTrees, best.pose_minLeaf, best.pose_mode);
fprintf('Risk: nT=%d leaf=%d mode=%s\n', best.risk_nTrees, best.risk_minLeaf, best.risk_mode);
fprintf('Comf: nT=%d leaf=%d mode=%s\n', best.comf_nTrees, best.comf_minLeaf, best.comf_mode);
fprintf('Tune (cached OOF): RiskAUC=%.3f | ComfortAUC=%.3f | PoseMAE=%.2f\n', aucTune.aucR, aucTune.aucC, aucTune.poseMAE);

auc = struct();
auc.RF_risk = safeAUC(yRisk, best.oof_pLowRisk);
auc.RF_comf = safeAUC(yComf, best.oof_pHighComf);
fprintf('\n[Best-OOF (cached, tuned)] Risk AUC=%.3f | Comfort AUC=%.3f\n', auc.RF_risk, auc.RF_comf);

%% ===================== 4) Baselines (model comparison) =====================
oofLog = oof_LogReg_withPose(X0, best.oof_poseHat, yRisk, yComf, getFoldMask_oof, K_oof);
oofSVM = oof_SVM_withPose_scoresOnly(X0, best.oof_poseHat, yRisk, yComf, getFoldMask_oof, K_oof);

auc.Log_risk = safeAUC(yRisk, oofLog.pLowRisk);
auc.Log_comf = safeAUC(yComf, oofLog.pHighComf);
auc.SVM_risk = safeAUC(yRisk, oofSVM.scoreLowRisk);
auc.SVM_comf = safeAUC(yComf, oofSVM.scoreHighComf);

fprintf('\n=== Model comparison (tuned subject-grouped OOF) ===\n');
fprintf('Risk AUC:    RF=%.3f | LogReg+Pose=%.3f | SVM+Pose=%.3f\n', auc.RF_risk, auc.Log_risk, auc.SVM_risk);
fprintf('Comfort AUC: RF=%.3f | LogReg+Pose=%.3f | SVM+Pose=%.3f\n', auc.RF_comf, auc.Log_comf, auc.SVM_comf);

%% ===================== 5) Figures for model comparison + pose error =====================
saveModelComparisonFigures(outDir, yRisk, yComf, best, oofLog, oofSVM, auc, tauRULA, kComfort, comfortProbThresh, riskProbRefLine);

savePoseErrorFigures(outDir, Y_pose, best.oof_poseHat, col_pose);

summaryTbl = table( ...
    {'RF (tuned OOF)';'LogReg+Pose';'SVM+Pose'}, ...
    [auc.RF_risk; auc.Log_risk; auc.SVM_risk], ...
    [auc.RF_comf; auc.Log_comf; auc.SVM_comf], ...
    'VariableNames', {'Model','AUC_Risk','AUC_Comfort'});
writetable(summaryTbl, fullfile(outDir,'auc_summary_table_tuned_oof.csv'));

%% ===================== 6) Calibration (RF only, tuned OOF) =====================
if runCalibration
    [brierRisk, fig1] = reliabilityDiagram(yRisk, best.oof_pLowRisk, nCalibBins, sprintf('Risk: P(RULA<=%d)', tauRULA));
    exportgraphics(fig1, fullfile(outDir,'calib_risk_reliability.png'), 'Resolution', 300);

    [brierComf, fig2] = reliabilityDiagram(yComf, best.oof_pHighComf, nCalibBins, sprintf('Comfort: P(Comfort>=%d)', kComfort));
    exportgraphics(fig2, fullfile(outDir,'calib_comfort_reliability.png'), 'Resolution', 300);

    fid = fopen(fullfile(outDir,'brier_scores.txt'),'w');
    fprintf(fid, 'Brier score (Risk): %.6f\n', brierRisk);
    fprintf(fid, 'Brier score (Comfort): %.6f\n', brierComf);
    fclose(fid);

    fprintf('\nCalibration: Brier(Risk)=%.4f | Brier(Comfort)=%.4f\n', brierRisk, brierComf);
end

%% ===================== 7) Nested subject-grouped CV + 95%CI (generalization) =====================
if runNested
    nestedOut = nestedSubjectGroupedCV( ...
        X0, Y_pose, yRisk, yComf, subj, ...
        K_outer, K_inner, nRand_inner, minLeafRange, ...
        nTreesSet_pose_nested, nTreesSet_cls_nested, modeSet, ...
        riskW, comfW, poseW, tbOpts);

    writetable(nestedOut.foldTable, fullfile(outDir,'nested_cv_results.csv'));
    fid = fopen(fullfile(outDir,'nested_cv_summary.txt'),'w');
    fprintf(fid, '%s\n', nestedOut.summaryText);
    fclose(fid);

    fprintf('\n=== Nested CV Summary (generalization) ===\n%s\n', nestedOut.summaryText);
end

%% ===================== 8) Train final RF models on full data (for optimization) =====================
rng(best.seed, 'twister');
modelsRF = trainFinal_twoStage_RF_flatBest(X0, Y_pose, yRisk, yComf, best, tbOpts);

%% ===================== 9) Optimization (comfort-satisficing, health-first) =====================
if runOptimize
    fprintf('\n=== NSGA-II optimization (comfort-satisficing, health-first) ===\n');

    if fastOptimize
        popSize = popSize_fast; maxGen = maxGen_fast;
        fprintf('[Optimize] FAST: pop=%d gen=%d\n', popSize, maxGen);
    else
        popSize = popSize_slow; maxGen = maxGen_slow;
        fprintf('[Optimize] FORMAL: pop=%d gen=%d\n', popSize, maxGen);
    end

    usePar = false; % stability first
    fitnessFcn = @(z) fitness_healthFirst_withComfortConstraint(z, target_human, modelsRF, comfortProbThresh, penaltyWeight);

    options = optimoptions('gamultiobj', ...
        'PopulationSize', popSize, ...
        'MaxGenerations', maxGen, ...
        'Display','iter', ...
        'UseParallel', usePar);

    [z_pop, fvals] = gamultiobj(fitnessFcn, 6, [], [], [], [], lb, ub, options);

    pLow_pop = -fvals(:,1);
    pen_pop  =  fvals(:,2);

    % compute pHigh for all solutions for selection + plot
    pHigh_pop = nan(size(pLow_pop));
    for i = 1:size(z_pop,1)
        [~, pHigh_i] = predictProbs_twoStage(modelsRF, target_human, z_pop(i,:));
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
    for j = 1:6
        fprintf('%s: %.2f\n', names{j}, zStar(j));
    end
    fprintf('Pred P(RULA<=%d)=%.3f | Pred P(Comfort>=%d)=%.3f | ComfortThresh=%.2f\n', ...
        tauRULA, pLowStar, kComfort, pHighStar, comfortProbThresh);

    % save optimization population
    optTbl = array2table([z_pop, pLow_pop, pHigh_pop, pen_pop], ...
        'VariableNames', {'SeatHeight','SeatDepth','BackrestAngle','ArmrestHeight','LumbarHeight','HeadrestHeight', ...
                          'PredP_LowRisk','PredP_HighComfort','ComfortPenalty'});
    writetable(optTbl, fullfile(outDir,'opt_population.csv'));

    optStarTbl = array2table([zStar, pLowStar, pHighStar], ...
        'VariableNames', {'SeatHeight','SeatDepth','BackrestAngle','ArmrestHeight','LumbarHeight','HeadrestHeight', ...
                          'PredP_LowRisk','PredP_HighComfort'});
    writetable(optStarTbl, fullfile(outDir,'opt_recommended.csv'));

    % plot optimization scatter
    fig = figure('Color','w','Name','NSGA-II solutions');
    hold on; grid on; box on;
    scatter(pLow_pop, pHigh_pop, 45, [0.2 0.5 0.8], 'filled');
    plot(pLowStar, pHighStar, 'rp', 'MarkerSize', 16, 'MarkerFaceColor','r');
    xline(riskProbRefLine, '--k', 'LineWidth', 1.2);
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
%% Helper: folds
function [subjList, getFoldMask] = makeSubjectGroupedFolds(subj, K)
subjList = categories(subj);
nSubj = numel(subjList);
if K > nSubj
    error('K=%d > #subjects=%d', K, nSubj);
end
cvp = cvpartition(nSubj, 'KFold', K);
getFoldMask = @(k) deal( ...
    ismember(subj, subjList(training(cvp,k))), ...
    ismember(subj, subjList(test(cvp,k))) );
end

%% =====================================================================
%% Random tune AND cache OOF predictions (RF two-stage)
function [best, aucTune, logTbl] = randTune_andCacheOOF(X0, Y_pose, yRisk, yComf, getFoldMask, K, nIter, minLeafRange, nTreesSet_pose, nTreesSet_cls, modeSet, riskW, comfW, poseW, tbOpts)

bestScore = inf;
best = struct('it',0,'seed',0,'score',inf);

best.oof_pLowRisk = [];
best.oof_pHighComf = [];
best.oof_poseHat = [];

logTbl = table('Size',[nIter 10], ...
    'VariableTypes', {'double','double','double','double','double','double','double','double','string','string'}, ...
    'VariableNames', {'it','seed','aucR','aucC','poseMAE','score','pose_nTrees','risk_nTrees','pose_mode','risk_mode'});
logTbl = removevars(logTbl, {'pose_mode','risk_mode'}); %#ok<NASGU>
% We will store full config in a simple struct array instead
cfg = repmat(struct(), nIter, 1);

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
        Ptr = Y_pose(idxTr,:);

        mu = mean(Xtr,1);
        sd = std(Xtr,0,1); sd(sd==0)=1;
        Xtr_n = (Xtr - mu)./sd;
        Xte_n = (Xte - mu)./sd;

        numPred_pose = mode2numPred(pose_mode, size(Xtr_n,2));
        poseModels = cell(1, size(Y_pose,2));
        for j = 1:size(Y_pose,2)
            poseModels{j} = TreeBagger(pose_nTrees, Xtr_n, Ptr(:,j), ...
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

    aucR = safeAUC(yRisk, phat_r);
    aucC = safeAUC(yComf, phat_c);
    poseMAE = mean(abs(Y_pose - poseHat), 'all');
    score = riskW*(1-aucR) + comfW*(1-aucC) + poseW*poseMAE;

    fprintf('[Rand %02d/%02d] AUC_R=%.3f AUC_C=%.3f PoseMAE=%.2f score=%.4f\n', it, nIter, aucR, aucC, poseMAE, score);

    cfg(it).it = it; cfg(it).seed = seed;
    cfg(it).aucR = aucR; cfg(it).aucC = aucC; cfg(it).poseMAE = poseMAE; cfg(it).score = score;
    cfg(it).pose_nTrees = pose_nTrees; cfg(it).pose_minLeaf = pose_minLeaf; cfg(it).pose_mode = pose_mode;
    cfg(it).risk_nTrees = risk_nTrees; cfg(it).risk_minLeaf = risk_minLeaf; cfg(it).risk_mode = risk_mode;
    cfg(it).comf_nTrees = comf_nTrees; cfg(it).comf_minLeaf = comf_minLeaf; cfg(it).comf_mode = comf_mode;

    if score < bestScore
        bestScore = score;

        best.it = it; best.seed = seed; best.score = score;

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

% write log table from cfg
logTbl = table([cfg.it]', [cfg.seed]', [cfg.aucR]', [cfg.aucC]', [cfg.poseMAE]', [cfg.score]', ...
    [cfg.pose_nTrees]', [cfg.pose_minLeaf]', string({cfg.pose_mode})', ...
    [cfg.risk_nTrees]', [cfg.risk_minLeaf]', string({cfg.risk_mode})', ...
    [cfg.comf_nTrees]', [cfg.comf_minLeaf]', string({cfg.comf_mode})', ...
    'VariableNames', {'it','seed','aucR','aucC','poseMAE','score', ...
                      'pose_nTrees','pose_minLeaf','pose_mode', ...
                      'risk_nTrees','risk_minLeaf','risk_mode', ...
                      'comf_nTrees','comf_minLeaf','comf_mode'});

aucTune.aucR = best.aucR_tune;
aucTune.aucC = best.aucC_tune;
aucTune.poseMAE = best.poseMAE_tune;
end

%% =====================================================================
%% Baseline: LogReg+Pose
function oof = oof_LogReg_withPose(X0, poseHatOOF, yRisk, yComf, getFoldMask, K)
oof.pLowRisk = nan(size(yRisk));
oof.pHighComf = nan(size(yComf));
Xfull = [X0, poseHatOOF];

for k = 1:K
    [idxTr, idxTe] = getFoldMask(k);

    Xtr = Xfull(idxTr,:); Xte = Xfull(idxTe,:);
    mu = mean(Xtr,1);
    sd = std(Xtr,0,1); sd(sd==0)=1;
    Xtr_n = (Xtr - mu)./sd;
    Xte_n = (Xte - mu)./sd;

    mdlR = fitglm(Xtr_n, yRisk(idxTr), 'Distribution','binomial');
    oof.pLowRisk(idxTe) = predict(mdlR, Xte_n);

    mdlC = fitglm(Xtr_n, yComf(idxTr), 'Distribution','binomial');
    oof.pHighComf(idxTe) = predict(mdlC, Xte_n);
end
end

%% =====================================================================
%% Baseline: SVM+Pose (scores only)
function oof = oof_SVM_withPose_scoresOnly(X0, poseHatOOF, yRisk, yComf, getFoldMask, K)
oof.scoreLowRisk = nan(size(yRisk));
oof.scoreHighComf = nan(size(yComf));
Xfull = [X0, poseHatOOF];

for k = 1:K
    [idxTr, idxTe] = getFoldMask(k);

    Xtr = Xfull(idxTr,:); Xte = Xfull(idxTe,:);
    mu = mean(Xtr,1);
    sd = std(Xtr,0,1); sd(sd==0)=1;
    Xtr_n = (Xtr - mu)./sd;
    Xte_n = (Xte - mu)./sd;

    ytrR = categorical(yRisk(idxTr), [0 1], {'highRisk','lowRisk'});
    mdlR = fitcsvm(Xtr_n, ytrR, 'KernelFunction','rbf', 'Standardize',false);
    [~, scoreR] = predict(mdlR, Xte_n);
    oof.scoreLowRisk(idxTe) = pickScoreColumn(mdlR.ClassNames, scoreR, 'lowRisk');

    ytrC = categorical(yComf(idxTr), [0 1], {'low','high'});
    mdlC = fitcsvm(Xtr_n, ytrC, 'KernelFunction','rbf', 'Standardize',false);
    [~, scoreC] = predict(mdlC, Xte_n);
    oof.scoreHighComf(idxTe) = pickScoreColumn(mdlC.ClassNames, scoreC, 'high');
end
end

function s = pickScoreColumn(classNames, scoreMat, positiveClass)
cls = string(classNames);
idx = find(cls == string(positiveClass), 1);
if isempty(idx)
    error('Positive class %s not found.', positiveClass);
end
if size(scoreMat,2) == 1
    s = scoreMat(:,1);
else
    s = scoreMat(:, idx);
end
end

%% =====================================================================
%% Figures: model comparison
function saveModelComparisonFigures(outDir, yRisk, yComf, best, oofLog, oofSVM, auc, tauRULA, kComfort, comfortProbThresh, riskProbRefLine)

% Risk ROC
fig = figure('Color','w','Name','Risk ROC (tuned OOF)');
hold on; grid on; box on;
plotROC(yRisk, best.oof_pLowRisk, sprintf('RF (AUC=%.3f)', auc.RF_risk));
plotROC(yRisk, oofLog.pLowRisk,   sprintf('LogReg+Pose (AUC=%.3f)', auc.Log_risk));
plotROC(yRisk, oofSVM.scoreLowRisk, sprintf('SVM+Pose (AUC=%.3f)', auc.SVM_risk));
xlabel('FPR'); ylabel('TPR');
title(sprintf('Risk ROC (tuned subject-grouped OOF): RULA<=%d', tauRULA));
legend('Location','best'); hold off;
exportgraphics(fig, fullfile(outDir,'roc_risk_tuned_oof.png'), 'Resolution', 300);

% Comfort ROC
fig = figure('Color','w','Name','Comfort ROC (tuned OOF)');
hold on; grid on; box on;
plotROC(yComf, best.oof_pHighComf, sprintf('RF (AUC=%.3f)', auc.RF_comf));
plotROC(yComf, oofLog.pHighComf,   sprintf('LogReg+Pose (AUC=%.3f)', auc.Log_comf));
plotROC(yComf, oofSVM.scoreHighComf, sprintf('SVM+Pose (AUC=%.3f)', auc.SVM_comf));
xlabel('FPR'); ylabel('TPR');
title(sprintf('Comfort ROC (tuned subject-grouped OOF): Comfort>=%d', kComfort));
legend('Location','best'); hold off;
exportgraphics(fig, fullfile(outDir,'roc_comfort_tuned_oof.png'), 'Resolution', 300);

% AUC bar
fig = figure('Color','w','Name','AUC Comparison (tuned OOF)');
models = {'RF','LogReg+Pose','SVM+Pose'};
riskVals = [auc.RF_risk, auc.Log_risk, auc.SVM_risk];
comfVals = [auc.RF_comf, auc.Log_comf, auc.SVM_comf];
bar([riskVals; comfVals]'); grid on; box on;
set(gca,'XTickLabel',models);
ylabel('AUC');
legend({sprintf('Risk (RULA<=%d)',tauRULA), sprintf('Comfort (>= %d)',kComfort)}, 'Location','best');
title('Model comparison (tuned subject-grouped OOF)');
exportgraphics(fig, fullfile(outDir,'auc_comparison_tuned_oof.png'), 'Resolution', 300);

% RF probability scatter
fig = figure('Color','w','Name','Prob Scatter (tuned OOF)');
gscatter(best.oof_pLowRisk, best.oof_pHighComf, categorical(yRisk,[0 1],{'highRisk','lowRisk'}));
grid on; box on;
xline(riskProbRefLine, '--k', 'LineWidth', 1.2);
yline(comfortProbThresh, '--k', 'LineWidth', 1.2);
xlabel(sprintf('P(RULA<=%d) (OOF)', tauRULA));
ylabel(sprintf('P(Comfort>=%d) (OOF)', kComfort));
title('RF probability scores (tuned OOF)');
exportgraphics(fig, fullfile(outDir,'prob_scatter_tuned_oof.png'), 'Resolution', 300);
end

%% =====================================================================
%% Figures: pose error (tuned OOF cached)
function savePoseErrorFigures(outDir, Y_pose_true, Y_pose_hat, col_pose)
poseMAE  = mean(abs(Y_pose_true - Y_pose_hat), 1);
poseRMSE = sqrt(mean((Y_pose_true - Y_pose_hat).^2, 1));

fig = figure('Color','w','Name','Pose CV Error (tuned OOF)');
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

nexttile;
bar(poseMAE); grid on; box on;
set(gca,'XTick',1:numel(col_pose),'XTickLabel',col_pose,'XTickLabelRotation',30);
ylabel('MAE (deg)');
title('Pose MAE (OOF, cached)');

nexttile;
bar(poseRMSE); grid on; box on;
set(gca,'XTick',1:numel(col_pose),'XTickLabel',col_pose,'XTickLabelRotation',30);
ylabel('RMSE (deg)');
title('Pose RMSE (OOF, cached)');

exportgraphics(fig, fullfile(outDir,'pose_error_tuned_oof.png'), 'Resolution', 300);
end

%% =====================================================================
%% Reliability diagram + Brier
function [brier, fig] = reliabilityDiagram(y01, p, nBins, titleStr)
y01 = y01(:); p = p(:);
p = min(1, max(0, p));
brier = mean((p - y01).^2);

edges = linspace(0,1,nBins+1);
binId = discretize(p, edges);

obs = nan(nBins,1);
pred = nan(nBins,1);
cnt = zeros(nBins,1);

for b = 1:nBins
    idx = (binId==b);
    cnt(b) = sum(idx);
    if cnt(b) > 0
        obs(b) = mean(y01(idx));
        pred(b) = mean(p(idx));
    end
end

fig = figure('Color','w','Name',['Reliability: ', titleStr]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

nexttile;
plot([0 1],[0 1],'--','Color',[0.5 0.5 0.5],'LineWidth',1.2); hold on; grid on; box on;
plot(pred, obs, '-o', 'LineWidth', 1.6);
xlabel('Mean predicted probability');
ylabel('Observed frequency');
title({titleStr, sprintf('Brier=%.4f', brier)});
xlim([0 1]); ylim([0 1]);
hold off;

nexttile;
bar(cnt); grid on; box on;
xlabel('Bin'); ylabel('Count');
title('Counts per bin');
end

%% =====================================================================
%% Nested CV + 95%CI (outer-fold t interval)
function out = nestedSubjectGroupedCV(X0, Y_pose, yRisk, yComf, subj, K_outer, K_inner, nRand_inner, minLeafRange, nTreesSet_pose, nTreesSet_cls, modeSet, riskW, comfW, poseW, tbOpts)

subjList = categories(subj);
nSubj = numel(subjList);
if K_outer > nSubj
    error('K_outer=%d > #subjects=%d', K_outer, nSubj);
end
cvp_outer = cvpartition(nSubj, 'KFold', K_outer);

AUC_R = nan(K_outer,1);
AUC_C = nan(K_outer,1);
PoseMAE = nan(K_outer,1);

for fo = 1:K_outer
    subj_te = subjList(test(cvp_outer,fo));
    subj_tr = subjList(training(cvp_outer,fo));

    idxTe = ismember(subj, subj_te);
    idxTr = ismember(subj, subj_tr);

    Xtr = X0(idxTr,:); Xte = X0(idxTe,:);
    Ptr = Y_pose(idxTr,:); Pte = Y_pose(idxTe,:);
    yRtr = yRisk(idxTr); yRte = yRisk(idxTe);
    yCtr = yComf(idxTr); yCte = yComf(idxTe);
    subj_tr_vec = subj(idxTr);

    best = innerTuneRandomSearch( ...
        Xtr, Ptr, yRtr, yCtr, subj_tr_vec, ...
        K_inner, nRand_inner, minLeafRange, nTreesSet_pose, nTreesSet_cls, modeSet, ...
        riskW, comfW, poseW, tbOpts, 10000*fo);

    rng(20000*fo+7,'twister');
    [pLow, pHigh, poseHat] = fitTwoStageAndPredict(Xtr, Ptr, yRtr, yCtr, Xte, best, tbOpts);

    AUC_R(fo) = safeAUC(yRte, pLow);
    AUC_C(fo) = safeAUC(yCte, pHigh);
    PoseMAE(fo) = mean(abs(Pte - poseHat), 'all');
end

foldTable = table((1:K_outer)', AUC_R, AUC_C, PoseMAE, ...
    'VariableNames', {'OuterFold','AUC_Risk','AUC_Comfort','PoseMAE_deg'});

summaryText = "";
summaryText = summaryText + summarizeWithCItext('Risk AUC (RULA<=3)', AUC_R) + newline;
summaryText = summaryText + summarizeWithCItext('Comfort AUC (Comfort>=7)', AUC_C) + newline;
summaryText = summaryText + summarizeWithCItext('Pose MAE (deg)', PoseMAE);

out.foldTable = foldTable;
out.summaryText = char(summaryText);
end

function best = innerTuneRandomSearch(X, P, yR, yC, subjVec, K_inner, nRand, minLeafRange, nTreesSet_pose, nTreesSet_cls, modeSet, riskW, comfW, poseW, tbOpts, baseSeed)

subjList = categories(subjVec);
nSubj = numel(subjList);
K_inner = min(K_inner, nSubj);
if K_inner < 2
    K_inner = 2;
end
cvp_in = cvpartition(nSubj, 'KFold', K_inner);

bestScore = inf;
best = struct();

for it = 1:nRand
    seed = baseSeed + it;
    rng(seed,'twister');

    pose_nTrees = nTreesSet_pose(randi(numel(nTreesSet_pose)));
    pose_minLeaf = randi(minLeafRange);
    pose_mode = modeSet{randi(numel(modeSet))};

    risk_nTrees = nTreesSet_cls(randi(numel(nTreesSet_cls)));
    risk_minLeaf = randi(minLeafRange);
    risk_mode = modeSet{randi(numel(modeSet))};

    comf_nTrees = nTreesSet_cls(randi(numel(nTreesSet_cls)));
    comf_minLeaf = randi(minLeafRange);
    comf_mode = modeSet{randi(numel(modeSet))};

    phat_r = nan(size(yR));
    phat_c = nan(size(yC));
    poseHat = nan(size(P));

    for k = 1:K_inner
        subj_te = subjList(test(cvp_in,k));
        subj_tr = subjList(training(cvp_in,k));

        idxTe = ismember(subjVec, subj_te);
        idxTr = ismember(subjVec, subj_tr);

        Xtr = X(idxTr,:); Xte = X(idxTe,:);
        Ptr = P(idxTr,:);

        mu = mean(Xtr,1);
        sd = std(Xtr,0,1); sd(sd==0)=1;
        Xtr_n = (Xtr - mu)./sd;
        Xte_n = (Xte - mu)./sd;

        numPred_pose = mode2numPred(pose_mode, size(Xtr_n,2));
        poseModels = cell(1, size(P,2));
        for j = 1:size(P,2)
            poseModels{j} = TreeBagger(pose_nTrees, Xtr_n, Ptr(:,j), ...
                'Method','regression', 'MinLeafSize', pose_minLeaf, ...
                'NumPredictorsToSample', numPred_pose, 'Options', tbOpts);
        end

        Pose_tr = zeros(sum(idxTr), size(P,2));
        Pose_te = zeros(sum(idxTe), size(P,2));
        for j = 1:size(P,2)
            Pose_tr(:,j) = predict(poseModels{j}, Xtr_n);
            Pose_te(:,j) = predict(poseModels{j}, Xte_n);
        end
        poseHat(idxTe,:) = Pose_te;

        Xtr_feat = [Xtr_n, Pose_tr];
        Xte_feat = [Xte_n, Pose_te];

        numPred_risk = mode2numPred(risk_mode, size(Xtr_feat,2));
        mdlR = TreeBagger(risk_nTrees, Xtr_feat, categorical(yR(idxTr),[0 1],{'highRisk','lowRisk'}), ...
            'Method','classification', 'MinLeafSize', risk_minLeaf, ...
            'NumPredictorsToSample', numPred_risk, 'Options', tbOpts);
        [~, postR] = predict(mdlR, Xte_feat);
        idxLow = find(strcmp(string(mdlR.ClassNames), 'lowRisk'), 1);
        phat_r(idxTe) = postR(:, idxLow);

        numPred_comf = mode2numPred(comf_mode, size(Xtr_feat,2));
        mdlC = TreeBagger(comf_nTrees, Xtr_feat, categorical(yC(idxTr),[0 1],{'low','high'}), ...
            'Method','classification', 'MinLeafSize', comf_minLeaf, ...
            'NumPredictorsToSample', numPred_comf, 'Options', tbOpts);
        [~, postC] = predict(mdlC, Xte_feat);
        idxHigh = find(strcmp(string(mdlC.ClassNames), 'high'), 1);
        phat_c(idxTe) = postC(:, idxHigh);
    end

    aucR = safeAUC(yR, phat_r);
    aucC = safeAUC(yC, phat_c);
    poseMAE = mean(abs(P - poseHat), 'all');
    score = riskW*(1-aucR) + comfW*(1-aucC) + poseW*poseMAE;

    if score < bestScore
        bestScore = score;
        best.pose_nTrees = pose_nTrees;
        best.pose_minLeaf = pose_minLeaf;
        best.pose_mode = pose_mode;
        best.risk_nTrees = risk_nTrees;
        best.risk_minLeaf = risk_minLeaf;
        best.risk_mode = risk_mode;
        best.comf_nTrees = comf_nTrees;
        best.comf_minLeaf = comf_minLeaf;
        best.comf_mode = comf_mode;
    end
end
end

function [pLow_te, pHigh_te, poseHat_te] = fitTwoStageAndPredict(Xtr_raw, Ptr_raw, yRtr, yCtr, Xte_raw, best, tbOpts)

mu = mean(Xtr_raw,1);
sd = std(Xtr_raw,0,1); sd(sd==0)=1;
Xtr = (Xtr_raw - mu)./sd;
Xte = (Xte_raw - mu)./sd;

numPred_pose = mode2numPred(best.pose_mode, size(Xtr,2));
poseModels = cell(1, size(Ptr_raw,2));
for j = 1:size(Ptr_raw,2)
    poseModels{j} = TreeBagger(best.pose_nTrees, Xtr, Ptr_raw(:,j), ...
        'Method','regression', 'MinLeafSize', best.pose_minLeaf, ...
        'NumPredictorsToSample', numPred_pose, 'Options', tbOpts);
end

Pose_tr = zeros(size(Xtr,1), size(Ptr_raw,2));
poseHat_te = zeros(size(Xte,1), size(Ptr_raw,2));
for j = 1:size(Ptr_raw,2)
    Pose_tr(:,j) = predict(poseModels{j}, Xtr);
    poseHat_te(:,j) = predict(poseModels{j}, Xte);
end

Xtr_feat = [Xtr, Pose_tr];
Xte_feat = [Xte, poseHat_te];

numPred_risk = mode2numPred(best.risk_mode, size(Xtr_feat,2));
mdlR = TreeBagger(best.risk_nTrees, Xtr_feat, categorical(yRtr,[0 1],{'highRisk','lowRisk'}), ...
    'Method','classification', 'MinLeafSize', best.risk_minLeaf, ...
    'NumPredictorsToSample', numPred_risk, 'Options', tbOpts);
[~, postR] = predict(mdlR, Xte_feat);
idxLow = find(strcmp(string(mdlR.ClassNames), 'lowRisk'), 1);
pLow_te = postR(:, idxLow);

numPred_comf = mode2numPred(best.comf_mode, size(Xtr_feat,2));
mdlC = TreeBagger(best.comf_nTrees, Xtr_feat, categorical(yCtr,[0 1],{'low','high'}), ...
    'Method','classification', 'MinLeafSize', best.comf_minLeaf, ...
    'NumPredictorsToSample', numPred_comf, 'Options', tbOpts);
[~, postC] = predict(mdlC, Xte_feat);
idxHigh = find(strcmp(string(mdlC.ClassNames), 'high'), 1);
pHigh_te = postC(:, idxHigh);
end

function txt = summarizeWithCItext(name, x)
x = x(~isnan(x));
n = numel(x);
mu = mean(x);
sd = std(x,0);
if n < 2
    txt = sprintf('%s: mean=%.3f (n=%d)', name, mu, n);
    return;
end
tcrit = tinv(0.975, n-1);
half = tcrit * sd / sqrt(n);
txt = sprintf('%s: mean=%.3f | SD=%.3f | 95%%CI=[%.3f, %.3f] (n=%d)', name, mu, sd, mu-half, mu+half, n);
end

%% =====================================================================
%% Train final models for optimization (two-stage RF)
function modelsRF = trainFinal_twoStage_RF_flatBest(X0, Y_pose, yRisk, yComf, best, tbOpts)

modelsRF.mu = mean(X0,1);
modelsRF.sd = std(X0,0,1); modelsRF.sd(modelsRF.sd==0)=1;
X0n = (X0 - modelsRF.mu)./modelsRF.sd;

numPred_pose = mode2numPred(best.pose_mode, size(X0n,2));
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
%% Optimization fitness (health-first + comfort constraint)
function f = fitness_healthFirst_withComfortConstraint(chair, human, modelsRF, comfortProbThresh, penaltyWeight)
[pLow, pHigh] = predictProbs_twoStage(modelsRF, human, chair);
f1 = -pLow;
shortfall = max(0, comfortProbThresh - pHigh);
f2 = penaltyWeight * (shortfall^2);
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
%% Metrics + plotting helpers
function auc = safeAUC(y01, score)
if any(isnan(score)) || numel(unique(y01)) < 2
    auc = NaN; return;
end
[~,~,~,auc] = perfcurve(y01, score, 1);
end

function plotROC(y01, score, labelStr)
[x,y,~,~] = perfcurve(y01, score, 1);
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
