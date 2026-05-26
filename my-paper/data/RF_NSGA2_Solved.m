function RF_NSGA2_Solved()
    %% RF-NSGA-II 最终完整版 (包含所有可视化与修复)
    % 1. 修复了 TreeBagger 缺少重要性参数的报错
    % 2. 包含了 Pareto 方案B (风险约束) 可视化
    % 3. 包含了 特征重要性 可视化
    
    clc; close all;
    rng('default'); % 固定随机种子

    %% ============================================================
    %  1. 数据读取与预处理
    %  ============================================================
    filePath = 'E:\RTGXTP2\shuju.xlsx';
    if ~isfile(filePath)
        error('未找到数据文件: %s', filePath);
    end
    raw_data = readtable(filePath);

    % 特征定义
    col_human = {'Gender', 'Sub_Stature', 'Sub_Weight', ...
                 'Sub_Sitting_Height', 'Sub_Popliteal_Height', 'Sub_Buttock_Pop_Len'};
    col_chair = {'Chair_Seat_Height', 'Chair_Seat_Depth', 'Chair_Backrest_Angle', ...
                 'Chair_Armrest_Height', 'Chair_Lumbar_Height', 'Chair_Headrest_Height'};

    % 提取数据
    X_human_data = raw_data{:, col_human};
    X_chair_data = raw_data{:, col_chair};
    X = [X_human_data, X_chair_data]; 
    Y_comfort = raw_data.Comfort_Rating;
    Y_rula = raw_data.RULA_Final;

    % 数据标准化 (Z-score)
    [X_norm, mu, sigma] = zscore(X); 
    
    fprintf('数据加载成功 (N=%d)。正在训练模型...\n', height(raw_data));

    %% ============================================================
    %  2. 训练随机森林 (已修复报错)
    %  ============================================================
    nTrees = 200; 
    
    % 【关键修复】在此处直接开启 'OOBPredictorImportance'
    % MinLeafSize=1: 强制拟合训练集
    Mdl_Comfort = TreeBagger(nTrees, X_norm, Y_comfort, 'Method', 'regression', ...
        'OOBPrediction', 'on', ...
        'MinLeafSize', 1, ...
        'OOBPredictorImportance', 'on'); % <--- 加上这一句，后面画图就不会报错了

    Mdl_RULA = TreeBagger(nTrees, X_norm, Y_rula, 'Method', 'regression', ...
        'OOBPrediction', 'on', ...
        'MinLeafSize', 1, ...
        'OOBPredictorImportance', 'on');

    %% 3. 精度诊断
    pred_train_c = predict(Mdl_Comfort, X_norm);
    r2_c_train = 1 - sum((Y_comfort - pred_train_c).^2) / sum((Y_comfort - mean(Y_comfort)).^2);
    
    % 实时核验 RMSE
    rmse_check_c = sqrt(mean((Y_comfort - pred_train_c).^2));
    fprintf('>> 训练集拟合度: Comfort R2 = %.4f (RMSE=%.4f)\n', r2_c_train, rmse_check_c);
    
    if r2_c_train > 0.5
        fprintf('>> 模型拟合良好，准备进行优化。\n');
    else
        fprintf('>> 警告：训练集拟合较低。\n');
    end

    %% ============================================================
    %  4. NSGA-II 优化
    %  ============================================================
    
    % 设定目标用户: 男性, 175cm...
    target_human = [1, 175, 70, 92, 42, 46]; 

    % 设定边界 [座高, 座深, 靠背, 扶手, 腰托, 头枕]
    lb = [40,  40,  90,  15,  10,  15]; 
    ub = [55,  55,  125, 30,  25,  30];

    % 定义适应度函数句柄
    fitnessFcn = @(x) evaluate_chair(x, target_human, Mdl_Comfort, Mdl_RULA, mu, sigma);

    fprintf('\n正在运行 NSGA-II 多目标优化...\n');
    
    options = optimoptions('gamultiobj', ...
        'PopulationSize', 100, ...
        'MaxGenerations', 50, ...
        'Display', 'final'); % 不在这里画图，后面单独画更漂亮

    [x_opt, fvals] = gamultiobj(fitnessFcn, 6, [], [], [], [], lb, ub, options);

    %% ============================================================
    %  5. 可视化分析 (所有图表)
    %  ============================================================

    % ---------------------------------------------------------
    % 图 1: Pareto 前沿图 (方案B: 风险约束优化版)
    % ---------------------------------------------------------
    figure('Color', 'w', 'Name', 'Pareto Front Optimized');
    set(gcf, 'Position', [100, 100, 700, 550]); 

    pred_comfort = -fvals(:,1); % 负号转正
    pred_rula    = fvals(:,2);

    tau = 3.3; % 风险阈值

    % 找出满足约束的解
    feasible_idx = find(pred_rula <= tau);

    if ~isempty(feasible_idx)
        [max_c_feasible, idx_local] = max(pred_comfort(feasible_idx));
        idx_star = feasible_idx(idx_local);
        best_strategy = 'Risk-Constrained Opt';
    else
        warning('无满足约束解，退化为全局最优');
        [max_c_feasible, idx_star] = max(pred_comfort);
        best_strategy = 'Unconstrained';
    end
    
    best_chair = x_opt(idx_star, :); % 提取最优参数

    hold on; grid on; box on;
    % 绘制散点
    scatter(pred_rula(pred_rula > tau), pred_comfort(pred_rula > tau), ...
        50, [0.7 0.7 0.7], 'filled', 'MarkerFaceAlpha', 0.6, 'DisplayName', 'High Risk Solutions');
    scatter(pred_rula(pred_rula <= tau), pred_comfort(pred_rula <= tau), ...
        70, [0.2 0.5 0.8], 'filled', 'MarkerFaceAlpha', 0.9, 'DisplayName', sprintf('Feasible Solutions (RULA \\le %.1f)', tau));
    % 绘制阈值线
    xline(tau, '--', {'Risk Threshold', sprintf('\\tau = %.1f', tau)}, ...
        'Color', [0.4660 0.6740 0.1880], 'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom', 'HandleVisibility', 'off');
    % 标记红星
    plot(pred_rula(idx_star), pred_comfort(idx_star), 'p', ...
        'MarkerSize', 18, 'MarkerFaceColor', [0.85 0.32 0.1], 'MarkerEdgeColor', 'k', ...
        'LineWidth', 1.2, 'DisplayName', 'Recommended Solution');
    
    xlabel('Predicted RULA Score (Lower is Better)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Predicted Comfort Rating (Higher is Better)', 'FontSize', 12, 'FontWeight', 'bold');
    title({'Pareto Front of Chair Optimization', 'Trade-off: Comfort vs. Postural Risk'}, 'FontSize', 14);
    legend('Location', 'southeast', 'FontSize', 10, 'Box', 'on');
    hold off;

    % ---------------------------------------------------------
%% 4.2.2 特征重要性对比 (仅座椅参数版 - 聚焦设计变量)
figure('Color', 'w', 'Position', [100, 100, 1000, 450]);

% 1. 定义全部特征名
all_names = {'Gender', 'Stature', 'Weight', 'Sit Ht', 'Pop Ht', 'Buttock Len', ...
             'Seat Ht', 'Seat Dp', 'Back Ang', 'Arm Ht', 'Lumbar Ht', 'Head Ht'};

% 2. 定义要保留的“座椅参数”索引 (后6个)
idx_chair = 7:12; 
chair_names = all_names(idx_chair);

% --- 左图：舒适度 ---
subplot(1, 2, 1);
try imp_c = Mdl_Comfort.OOBPermutedPredictorImportance; catch, imp_c = Mdl_Comfort.OOBPermutedVarDeltaError; end
imp_c_chair = imp_c(idx_chair); % 只取座椅参数

% 归一化 (可选：让它们加起来=1，或者直接用原始值)
% imp_c_chair = imp_c_chair / sum(imp_c_chair); 

[sorted_c, idx_c] = sort(imp_c_chair, 'descend');
b1 = barh(sorted_c, 'FaceColor', [0.2 0.6 0.5]);
grid on;
set(gca, 'YTick', 1:6, 'YTickLabel', chair_names(idx_c), 'FontSize', 11);
xlabel('Relative Importance', 'FontWeight', 'bold');
title('(a) Comfort Drivers (Chair Params Only)', 'FontSize', 12);
for i = 1:6, if sorted_c(i)>0, text(sorted_c(i), i, sprintf(' %.3f', sorted_c(i)), 'FontSize',9); end; end

% --- 右图：RULA ---
subplot(1, 2, 2);
try imp_r = Mdl_RULA.OOBPermutedPredictorImportance; catch, imp_r = Mdl_RULA.OOBPermutedVarDeltaError; end
imp_r_chair = imp_r(idx_chair); % 只取座椅参数

[sorted_r, idx_r] = sort(imp_r_chair, 'descend');
b2 = barh(sorted_r, 'FaceColor', [0.2 0.4 0.7]);
grid on;
set(gca, 'YTick', 1:6, 'YTickLabel', chair_names(idx_r), 'FontSize', 11);
xlabel('Relative Importance', 'FontWeight', 'bold');
title('(b) Risk Drivers (Chair Params Only)', 'FontSize', 12);
for i = 1:6, if sorted_r(i)>0, text(sorted_r(i), i, sprintf(' %.3f', sorted_r(i)), 'FontSize',9); end; end

sgtitle('Feature Importance of Design Parameters: Subjective vs. Objective', 'FontSize', 14, 'FontWeight', 'bold');




    % ---------------------------------------------------------
    % 图 3: 3D 响应曲面
    % ---------------------------------------------------------
    figure('Color', 'w', 'Name', '3D Response Surface');
    grid_size = 30;
    h_range = linspace(40, 55, grid_size);  
    a_range = linspace(90, 125, grid_size); 
    [HH, AA] = meshgrid(h_range, a_range);
    
    num_points = grid_size^2;
    user_vec = repmat(target_human, num_points, 1);
    
    % 固定其他参数为最优解
    chair_vec = [HH(:), repmat(best_chair(2), num_points, 1), AA(:), ...
                 repmat(best_chair(4), num_points, 1), repmat(best_chair(5), num_points, 1), repmat(best_chair(6), num_points, 1)];
    
    input_grid_norm = ([user_vec, chair_vec] - mu) ./ sigma;
    pred_grid = predict(Mdl_Comfort, input_grid_norm);
    ZZ = reshape(pred_grid, grid_size, grid_size);
    
    surf(HH, AA, ZZ, 'EdgeColor', 'none');
    colormap jet; colorbar; hold on;
    plot3(best_chair(1), best_chair(3), pred_comfort(idx_star), 'p', 'MarkerSize', 20, 'MarkerFaceColor', 'w', 'MarkerEdgeColor','k');
    
    xlabel('Seat Height (cm)'); ylabel('Backrest Angle (deg)'); zlabel('Predicted Comfort');
    title('Effect of Seat Height & Backrest on Comfort', 'FontSize', 14);
    view(-30, 30);

    % ---------------------------------------------------------
    % 图 4: 参数对比图
    % ---------------------------------------------------------
    figure('Color', 'w', 'Name', 'Parameter Comparison');
    baseline_chair = mean(X_chair_data); 
    data_compare = [baseline_chair; best_chair];
    b = bar(data_compare', 'grouped');
    b(1).FaceColor = [0.5 0.5 0.5]; b(2).FaceColor = [0.8 0.2 0.2];
    xticklabels({'Height', 'Depth', 'Angle', 'Armrest', 'Lumbar', 'Headrest'});
    ylabel('Parameter Value');
    legend('Average Existing', 'Optimized', 'Location', 'NorthWest');
    title('Comparison: Average Design vs. Optimized Design');
    grid on;
    
    % 结果打印
    fprintf('\n=== 最终推荐方案 (基于方案B: 风险约束) ===\n');
    fprintf('舒适度: %.2f, RULA: %.2f\n', pred_comfort(idx_star), pred_rula(idx_star));
    names = col_chair;
    for i = 1:length(names)
        fprintf('%s: %.1f\n', names{i}, best_chair(i));
    end

end 

%% --- 辅助函数 ---
function val = evaluate_chair(chair_params, human_params, model_c, model_r, mu, sigma)
    input_raw = [human_params, chair_params];
    input_norm = (input_raw - mu) ./ sigma;
    val(1) = -predict(model_c, input_norm);
    val(2) = predict(model_r, input_norm);
end
