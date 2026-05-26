function RF_NSGA2_NestedCV_CI()
%% Nested subject-grouped CV + 95% CI for two-stage RF surrogates
% Outer CV: subject-grouped generalization estimate
% Inner CV: random-search tuning on outer-train only
% Metrics: AUC_Risk (RULA<=tau), AUC_Comfort (Comfort>=k), Pose MAE on outer-test
%
% NOTE:
% - This is the FAST, reviewer-friendly validation you can report.
% - It does NOT include NSGA-II optimization or JACK.

clc; close all;
rng('default');

%% ===================== 0) Settings =====================
filePath = 'E:\RTGXTP2\shuju.xlsx';

tauRULA  = 3;
kComfort = 7;

% ===================== You can change these 4 knobs =====================
K_outer = 5;          % OUTER subject-grouped folds
K_inner = 3;          % INNER subject-grouped folds (fast)
nRand_inner = 20;     % INNER random-search iterations (fast)
minLeafRange = [3,12];% MinLeaf search range

% health-first weights used in inner tuning score
riskW = 0.70;
comfW = 0.30;
poseW = 0.01;         % small penalty for pose error

% Search spaces (keep small for speed)
nTreesSet_pose = [200, 500];
nTreesSet_cls  = [200, 500];
modeSet = {'sqrt','third','all'};

% Disable TreeBagger internal parallel (fix your previous error)
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

yRisk = double(Yr <= tauRULA);
yComf = double(Yc >= kComfort);

fprintf('Data: %d trials, %d subjects\n', size(X0,1), numel(categories(subj)));
fprintf('Class balance: P(lowRisk)=%.3f | P(highComfort>=%.0f)=%.3f\n', mean(yRisk), kComfort, mean(yComf));

%% ===================== 2) Outer subject-grouped CV split =====================
subjList = categories(subj);
nSubj = numel(subjList);
if K_outer > nSubj
    error('K_outer=%d > #subjects=%d', K_outer, nSubj);
end

cvp_outer = cvpartition(nSubj, 'KFold', K_outer);

% store outer results
AUC_R_outer = nan(K_outer,1);
AUC_C_outer = nan(K_outer,1);
PoseMAE_outer = nan(K_outer,1);

best_outer = cell(K_outer,1);

%% ===================== 3) Outer loop =====================
fprintf('\n=== Nested subject-grouped CV ===\n');

for fo = 1:K_outer
    fprintf('\n[Outer %d/%d]\n', fo, K_outer);

    subj_te = subjList(test(cvp_outer, fo));
    subj_tr = subjList(training(cvp_outer, fo));

    idxTe = ismember(subj, subj_te);
    idxTr = ismember(subj, subj_tr);

    X_tr = X0(idxTr,:);   X_te = X0(idxTe,:);
    P_tr = Y_pose(idxTr,:); P_te = Y_pose(idxTe,:);
    yR_tr = yRisk(idxTr); yR_te = yRisk(idxTe);
    yC_tr = yComf(idxTr); yC_te = yComf(idxTe);
    subj_tr_vec = subj(idxTr);

    % -------- Inner tuning on OUTER TRAIN only --------
    best = innerTuneRandomSearch( ...
        X_tr, P_tr, yR_tr, yC_tr, subj_tr_vec, ...
        K_inner, nRand_inner, minLeafRange, nTreesSet_pose, nTreesSet_cls, modeSet, ...
        riskW, comfW, poseW, tbOpts, ...
        10000*fo); % base seed per outer fold

    best_outer{fo} = best;

    fprintf('  Best inner: Pose(nT=%d leaf=%d %s) Risk(nT=%d leaf=%d %s) Comf(nT=%d leaf=%d %s)\n', ...
        best.pose_nTrees, best.pose_minLeaf, best.pose_mode, ...
        best.risk_nTrees, best.risk_minLeaf, best.risk_mode, ...
        best.comf_nTrees, best.comf_minLeaf, best.comf_mode);

    % -------- Train on full OUTER TRAIN, evaluate on OUTER TEST --------
    rng(20000*fo + 7, 'twister'); % fixed for reproducibility at outer level

    [pLow_te, pHigh_te, poseHat_te] = fitTwoStageAndPredict( ...
        X_tr, P_tr, yR_tr, yC_tr, ...
        X_te, best, tbOpts);

    % AUC guards: perfcurve requires both classes present
    AUC_R_outer(fo) = safeAUC(yR_te, pLow_te);
    AUC_C_outer(fo) = safeAUC(yC_te, pHigh_te);

    PoseMAE_outer(fo) = mean(abs(P_te - poseHat_te), 'all');

    fprintf('  Outer-test: AUC_R=%.3f | AUC_C=%.3f | PoseMAE=%.2f deg\n', ...
        AUC_R_outer(fo), AUC_C_outer(fo), PoseMAE_outer(fo));
end

%% ===================== 4) Summary + 95% CI =====================
fprintf('\n=== Summary (Outer CV) ===\n');
summarizeWithCI('Risk AUC (RULA<=3)', AUC_R_outer);
summarizeWithCI(sprintf('Comfort AUC (Comfort>=%d)', kComfort), AUC_C_outer);
summarizeWithCI('Pose MAE (deg)', PoseMAE_outer);

% Save to CSV
outTbl = table((1:K_outer)', AUC_R_outer, AUC_C_outer, PoseMAE_outer, ...
    'VariableNames', {'OuterFold','AUC_Risk','AUC_Comfort','PoseMAE_deg'});
writetable(outTbl, 'nested_cv_results.csv');
fprintf('Saved: nested_cv_results.csv\n');

end

%% =====================================================================
%% Inner tuning: random search on outer-train with subject-grouped CV
function best = innerTuneRandomSearch(X, P, yR, yC, subjVec, K_inner, nRand, minLeafRange, nTreesSet_pose, nTreesSet_cls, modeSet, riskW, comfW, poseW, tbOpts, baseSeed)

subjList = categories(subjVec);
nSubj = numel(subjList);
if K_inner > nSubj
    K_inner = max(2, min(3, nSubj)); % keep it feasible
end
cvp_in = cvpartition(nSubj, 'KFold', K_inner);

bestScore = inf;
best = struct();

for it = 1:nRand
    seed = baseSeed + it;
    rng(seed, 'twister');

    % sample hyperparams
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
        subj_te = subjList(test(cvp_in, k));
        subj_tr = subjList(training(cvp_in, k));

        idxTe = ismember(subjVec, subj_te);
        idxTr = ismember(subjVec, subj_tr);

        Xtr = X(idxTr,:); Xte = X(idxTe,:);
        Ptr = P(idxTr,:); Pte = P(idxTe,:);
        yRtr = yR(idxTr); yCtr = yC(idxTr);

        % standardize on train fold
        mu = mean(Xtr,1);
        sd = std(Xtr,0,1); sd(sd==0)=1;
        Xtr_n = (Xtr - mu)./sd;
        Xte_n = (Xte - mu)./sd;

        % pose models
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

        % risk classifier
        numPred_risk = mode2numPred(risk_mode, size(Xtr_feat,2));
        mdlR = TreeBagger(risk_nTrees, Xtr_feat, categorical(yRtr,[0 1],{'highRisk','lowRisk'}), ...
            'Method','classification', 'MinLeafSize', risk_minLeaf, ...
            'NumPredictorsToSample', numPred_risk, 'Options', tbOpts);
        [~, postR] = predict(mdlR, Xte_feat);
        idxLow = find(strcmp(string(mdlR.ClassNames), 'lowRisk'), 1);
        phat_r(idxTe) = postR(:, idxLow);

        % comfort classifier
        numPred_comf = mode2numPred(comf_mode, size(Xtr_feat,2));
        mdlC = TreeBagger(comf_nTrees, Xtr_feat, categorical(yCtr,[0 1],{'low','high'}), ...
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
        best.score = score;
    end
end
end

%% =====================================================================
%% Fit two-stage on full train, predict on test
function [pLow_te, pHigh_te, poseHat_te] = fitTwoStageAndPredict(Xtr_raw, Ptr_raw, yRtr, yCtr, Xte_raw, best, tbOpts)

% standardize using full train
mu = mean(Xtr_raw,1);
sd = std(Xtr_raw,0,1); sd(sd==0)=1;
Xtr = (Xtr_raw - mu)./sd;
Xte = (Xte_raw - mu)./sd;

% pose models
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

% risk model
numPred_risk = mode2numPred(best.risk_mode, size(Xtr_feat,2));
mdlR = TreeBagger(best.risk_nTrees, Xtr_feat, categorical(yRtr,[0 1],{'highRisk','lowRisk'}), ...
    'Method','classification', 'MinLeafSize', best.risk_minLeaf, ...
    'NumPredictorsToSample', numPred_risk, 'Options', tbOpts);
[~, postR] = predict(mdlR, Xte_feat);
idxLow = find(strcmp(string(mdlR.ClassNames), 'lowRisk'), 1);
pLow_te = postR(:, idxLow);

% comfort model
numPred_comf = mode2numPred(best.comf_mode, size(Xtr_feat,2));
mdlC = TreeBagger(best.comf_nTrees, Xtr_feat, categorical(yCtr,[0 1],{'low','high'}), ...
    'Method','classification', 'MinLeafSize', best.comf_minLeaf, ...
    'NumPredictorsToSample', numPred_comf, 'Options', tbOpts);
[~, postC] = predict(mdlC, Xte_feat);
idxHigh = find(strcmp(string(mdlC.ClassNames), 'high'), 1);
pHigh_te = postC(:, idxHigh);

end

%% =====================================================================
%% AUC with guard
function auc = safeAUC(y01, score)
if any(isnan(score)) || numel(unique(y01)) < 2
    auc = NaN;
    return;
end
try
    [~,~,~,auc] = perfcurve(y01, score, 1);
catch
    auc = NaN;
end
end

%% =====================================================================
%% Summary with 95% CI (t-interval)
function summarizeWithCI(name, x)
x = x(~isnan(x));
n = numel(x);
mu = mean(x);
sd = std(x,0);

if n < 2
    fprintf('%s: mean=%.3f (insufficient n for CI)\n', name, mu);
    return;
end

% t critical; if tinv unavailable, fallback to normal approx
try
    tcrit = tinv(0.975, n-1);
catch
    tcrit = 1.96;
end
half = tcrit * sd / sqrt(n);
fprintf('%s: mean=%.3f | SD=%.3f | 95%%CI=[%.3f, %.3f] (n=%d)\n', name, mu, sd, mu-half, mu+half, n);
end

%% =====================================================================
%% mode -> NumPredictorsToSample
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
