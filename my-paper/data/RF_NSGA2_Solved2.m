function RF_NSGA2_Solved()
    %% RF-NSGA-II 终极可视化增强版
    % 1. 包含 Comfort 和 RULA 的训练精度报告
    % 2. 包含 3D 响应曲面图
    % 3. 所有图表增加数值标记
    
    clc; close all;
    rng('default'); 

    %% 1. 数据读取与预处理
    filePath = 'E:\RTGXTP2\shuju.xlsx';
    if ~isfile(filePath)
        error('未找到数据文件: %s', filePath);
    end
    raw_data = readtable(filePath);

    col_human = {'Gender', 'Sub_Stature', 'Sub_Weight', ...
                 'Sub_Sitting_Height', 'Sub_Popliteal_Height', 'Sub_Buttock_Pop_Len'};
    col_chair = {'Chair_Seat_Height', 'Chair_Seat_Depth', 'Chair_Backrest_Angle', ...
                 'Chair_Armrest_Height', 'Chair_Lumbar_Height', 'Chair_Headrest_Height'};

    X_human_data = raw_data{:, col_human};
    X_chair_data = raw_data{:, col_chair};
    X = [X_human_data, X_chair_data]; 
    Y_comfort = raw_data.Comfort_Rating;
    Y_rula = raw_data.RULA_Final;

    [X_norm, mu, sigma] = zscore(X); 
    
    fprintf('数据加载成功 (N=%d)。正在训练模型...\n', height(raw_data));

    %% 2. 训练随机森林 (Comfort + RULA)
    nTrees = 60; MaxDepth = 4 
    
    % 开启 OOB 重要性计算
    Mdl_Comfort = TreeBagger(nTrees, X_norm, Y_comfort, 'Method', 'regression', ...
        'OOBPrediction', 'on', 'MinLeafSize', 3, 'OOBPredictorImportance', 'on'); 

    Mdl_RULA = TreeBagger(nTrees, X_norm, Y_rula, 'Method', 'regression', ...
        'OOBPrediction', 'on', 'MinLeafSize', 3, 'OOBPredictorImportance', 'on');

    %% 3. 精度诊断 (增加 RULA 报告)
    pred_train_c = predict(Mdl_Comfort, X_norm);
    pred_train_r = predict(Mdl_RULA, X_norm);
    
    r2_c_train = 1 - sum((Y_comfort - pred_train_c).^2) / sum((Y_comfort - mean(Y_comfort)).^2);
    r2_r_train = 1 - sum((Y_rula    - pred_train_r).^2) / sum((Y_rula    - mean(Y_rula)).^2);
    
    fprintf('>> 训练集拟合度: Comfort R2 = %.4f | RULA R2 = %.4f\n', r2_c_train, r2_r_train);
    
    if r2_c_train > 0.5 && r2_r_train > 0.5
        fprintf('>> 双模型拟合良好，准备进行优化。\n');
    else
        fprintf('>> 警告：训练集拟合较低。\n');
    end

    
    %% 4. NSGA-II 优化
    target_human = [1, 175, 70, 92, 42, 46]; 
    lb = [40,  40,  90,  15,  10,  55]; 
    ub = [55,  55,  125, 30,  25,  75];

    fitnessFcn = @(x) evaluate_chair(x, target_human, Mdl_Comfort, Mdl_RULA, mu, sigma);

    fprintf('\n正在运行 NSGA-II 多目标优化...\n');
    options = optimoptions('gamultiobj', 'PopulationSize', 100, 'MaxGenerations', 50, 'Display', 'off');
    [x_opt, fvals] = gamultiobj(fitnessFcn, 6, [], [], [], [], lb, ub, options);

    %% 5. 可视化分析 (四大图表)

    % --- 准备数据 ---
    pred_comfort = -fvals(:,1); 
    pred_rula    = fvals(:,2);
    
    tau = 3; 
    feasible_idx = find(pred_rula <= tau);
    
    if ~isempty(feasible_idx)
        [max_c_feasible, idx_local] = max(pred_comfort(feasible_idx));
        idx_star = feasible_idx(idx_local);
    else
        [max_c_feasible, idx_star] = max(pred_comfort);
    end
    best_chair = x_opt(idx_star, :);

    % =========================================================
    % 图 1: Pareto 前沿图 (带数值标记)
    % =========================================================
    figure('Color', 'w', 'Name', 'Pareto Front');
    set(gcf, 'Position', [100, 100, 650, 500]); 
    
    hold on; grid on; box on;
    scatter(pred_rula(pred_rula > tau), pred_comfort(pred_rula > tau), 50, [0.7 0.7 0.7], 'filled', 'DisplayName', 'High Risk');
    scatter(pred_rula(pred_rula <= tau), pred_comfort(pred_rula <= tau), 70, [0.2 0.5 0.8], 'filled', 'DisplayName', 'Feasible');
    xline(tau, '--g', 'LineWidth', 1.5, 'HandleVisibility', 'off');
    
    % 标记红星
    plot(pred_rula(idx_star), pred_comfort(idx_star), 'rp', 'MarkerSize', 18, 'MarkerFaceColor', 'r', 'DisplayName', 'Recommended');
    
    % 添加数值标签框
    text(pred_rula(idx_star)+0.05, pred_comfort(idx_star), ...
        {sprintf('  Comfort: %.2f', pred_comfort(idx_star)), sprintf('  RULA: %.2f', pred_rula(idx_star))}, ...
        'FontSize', 10, 'BackgroundColor', 'w', 'EdgeColor', 'k', 'Margin', 3);
    
    xlabel('Predicted RULA Score'); ylabel('Predicted Comfort Rating');
    title('Optimization Trade-off: Comfort vs. Risk');
    legend('Location', 'southeast'); hold off;

    % =========================================================
    % 图 2: 特征重要性对比 (Comfort vs. RULA) - 带数值
    % =========================================================
    figure('Color', 'w', 'Position', [150, 150, 1100, 450]);
    
    % 标签
    all_names = {'Gender', 'Stature', 'Weight', 'Sit Ht', 'Pop Ht', 'Buttock Len', ...
                 'Seat Ht', 'Seat Dp', 'Back Ang', 'Arm Ht', 'Lumbar Ht', 'Head Ht'};
    idx_chair = 7:12; 
    chair_names = all_names(idx_chair);
    
    % 左图：Comfort
    subplot(1, 2, 1);
    try imp_c = Mdl_Comfort.OOBPermutedPredictorImportance; catch, imp_c = Mdl_Comfort.OOBPermutedVarDeltaError; end
    imp_c_chair = imp_c(idx_chair); 
    [sorted_c, idx_c] = sort(imp_c_chair, 'descend');
    barh(sorted_c, 'FaceColor', [0.2 0.6 0.5]); grid on;
    set(gca, 'YTick', 1:6, 'YTickLabel', chair_names(idx_c), 'FontSize', 10);
    xlabel('Importance'); title('(a) Subjective Comfort Drivers');
    % 标数值
    for i=1:6, text(sorted_c(i), i, sprintf(' %.3f', sorted_c(i)), 'FontSize',9); end
    
    % 右图：RULA
    subplot(1, 2, 2);
    try imp_r = Mdl_RULA.OOBPermutedPredictorImportance; catch, imp_r = Mdl_RULA.OOBPermutedVarDeltaError; end
    imp_r_chair = imp_r(idx_chair);
    [sorted_r, idx_r] = sort(imp_r_chair, 'descend');
    barh(sorted_r, 'FaceColor', [0.2 0.4 0.7]); grid on;
    set(gca, 'YTick', 1:6, 'YTickLabel', chair_names(idx_r), 'FontSize', 10);
    xlabel('Importance'); title('(b) Objective Risk Drivers');
    % 标数值
    for i=1:6, text(sorted_r(i), i, sprintf(' %.3f', sorted_r(i)), 'FontSize',9); end
    
    sgtitle('Feature Importance Comparison: Design Parameters Only', 'FontSize', 14);

    % =========================================================
    % 图 3: 3D 响应曲面 (已补上)
    % =========================================================
    figure('Color', 'w', 'Name', '3D Response Surface');
    grid_size = 30;
    h_range = linspace(40, 55, grid_size);  
    a_range = linspace(90, 125, grid_size); 
    [HH, AA] = meshgrid(h_range, a_range);
    
    num_points = grid_size^2;
    user_vec = repmat(target_human, num_points, 1);
    
    chair_vec = [HH(:), repmat(best_chair(2), num_points, 1), AA(:), ...
                 repmat(best_chair(4), num_points, 1), repmat(best_chair(5), num_points, 1), repmat(best_chair(6), num_points, 1)];
    
    input_grid_norm = ([user_vec, chair_vec] - mu) ./ sigma;
    pred_grid = predict(Mdl_Comfort, input_grid_norm);
    ZZ = reshape(pred_grid, grid_size, grid_size);
    
    surf(HH, AA, ZZ, 'EdgeColor', 'none', 'FaceAlpha', 0.9);
    colormap jet; colorbar; hold on;
    % 标记最优解
    plot3(best_chair(1), best_chair(3), pred_comfort(idx_star), 'p', 'MarkerSize', 20, 'MarkerFaceColor', 'w', 'MarkerEdgeColor','k');
    
    xlabel('Seat Height (cm)'); ylabel('Backrest Angle (deg)'); zlabel('Predicted Comfort');
    title('Effect of Seat Height & Backrest on Comfort', 'FontSize', 14);
    view(-30, 30);

    % =========================================================
    % 图 4: 参数对比图 (带数值)
    % =========================================================
    figure('Color', 'w', 'Name', 'Parameter Comparison');
    baseline_chair = mean(X_chair_data); 
    data_plot = [baseline_chair; best_chair];
    b = bar(data_plot', 'grouped');
    b(1).FaceColor = [0.6 0.6 0.6]; b(2).FaceColor = [0.8 0.2 0.2];
    xticklabels({'Height', 'Depth', 'Angle', 'Armrest', 'Lumbar', 'Headrest'});
    ylabel('Parameter Value');
    legend('Average', 'Optimized', 'Location', 'NorthWest');
    title('Design Comparison'); grid on;
    
    % 标数值
    for k = 1:2
        xtips = b(k).XEndPoints;
        ytips = b(k).YEndPoints;
        for i = 1:length(xtips)
            text(xtips(i), ytips(i), sprintf('%.1f', ytips(i)), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
        end
    end
    
    % 结果打印
    fprintf('\n=== 最终推荐方案 ===\n');
    fprintf('舒适度: %.2f, RULA: %.2f\n', pred_comfort(idx_star), pred_rula(idx_star));
    for i = 1:6
        fprintf('%s: %.1f\n', chair_names{i}, best_chair(i));
    end

end 

%% --- 辅助函数 ---
function val = evaluate_chair(chair_params, human_params, model_c, model_r, mu, sigma)
    input_raw = [human_params, chair_params];
    input_norm = (input_raw - mu) ./ sigma;
    val(1) = -predict(model_c, input_norm);
    val(2) = predict(model_r, input_norm);
end
