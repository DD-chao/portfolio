function RF_NSGA2_Solved()
    %% RF-NSGA-II 终极修复版 (封装为函数以解决报错)
    % 功能：修复 'evaluate_chair' 无法识别的问题，并添加训练集精度检查
    
    % 初始化
    clc; close all;
    rng('default'); % 固定随机种子，保证每次结果一样

    %% 1. 数据读取与预处理
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

    %% 2. 训练随机森林
    nTrees = 200; 
    
    % MinLeafSize=1: 强制树生长得很深，尽量拟合训练数据
    Mdl_Comfort = TreeBagger(nTrees, X_norm, Y_comfort, 'Method', 'regression', ...
        'OOBPrediction', 'on', 'MinLeafSize', 1);

    Mdl_RULA = TreeBagger(nTrees, X_norm, Y_rula, 'Method', 'regression', ...
        'OOBPrediction', 'on', 'MinLeafSize', 1);

    %% 3. 精度诊断 (关键步骤)
    
    % A. 计算 OOB R2 (验证集精度 - 可能会低)
    r2_c_oob = 1 - sum((Y_comfort - oobPredict(Mdl_Comfort)).^2) / sum((Y_comfort - mean(Y_comfort)).^2);
    r2_r_oob = 1 - sum((Y_rula    - oobPredict(Mdl_RULA)).^2)    / sum((Y_rula    - mean(Y_rula)).^2);
    
    % B. 计算 训练集 R2 (记忆精度 - 应该很高)
    % 这是为了确认模型是否有效。如果这个值高，说明模型可以作为代理模型使用。
    pred_train_c = predict(Mdl_Comfort, X_norm);
    pred_train_r = predict(Mdl_RULA, X_norm);
    
    r2_c_train = 1 - sum((Y_comfort - pred_train_c).^2) / sum((Y_comfort - mean(Y_comfort)).^2);
    r2_r_train = 1 - sum((Y_rula    - pred_train_r).^2) / sum((Y_rula    - mean(Y_rula)).^2);
    % ... (在 r2_c_train 计算代码的下面插入) ...

% 现场计算 RMSE (Self-Check)
rmse_check_c = sqrt(mean((Y_comfort - pred_train_c).^2));
rmse_check_r = sqrt(mean((Y_rula    - pred_train_r).^2));

fprintf('>> 实时核验 RMSE: Comfort = %.4f, RULA = %.4f\n', rmse_check_c, rmse_check_r);


    fprintf('\n=== 模型精度诊断 ===\n');
    fprintf('Comfort (OOB验证): %.4f | Comfort (训练拟合): %.4f\n', r2_c_oob, r2_c_train);
    fprintf('RULA    (OOB验证): %.4f | RULA    (训练拟合): %.4f\n', r2_r_oob, r2_r_train);
    
    if r2_c_train > 0.5
        fprintf('>> 训练集拟合良好，模型已学会数据规律，可以进行优化。\n');
    else
        fprintf('>> 警告：训练集拟合也较低，可能是数据噪音太大。\n');
    end

    %% 4. NSGA-II 优化
    
    % 设定目标用户
    target_human = [1, 175, 70, 92, 42, 46]; 

    % 设定边界 [座高, 座深, 靠背, 扶手, 腰托, 头枕]
    lb = [40,  40,  90,  15,  10,  15]; 
    ub = [55,  55,  125, 30,  25,  30];

    % 定义适应度函数句柄
    fitnessFcn = @(x) evaluate_chair(x, target_human, Mdl_Comfort, Mdl_RULA, mu, sigma);

    fprintf('\n正在运行 NSGA-II 多目标优化...\n');
    
    % 设置 GA 参数
    options = optimoptions('gamultiobj', ...
        'PopulationSize', 100, ...
        'MaxGenerations', 50, ...
        'Display', 'final', ...
        'PlotFcn', @gaplotpareto); % 画图

    [x_opt, fvals] = gamultiobj(fitnessFcn, 6, [], [], [], [], lb, ub, options);

    %% 5. 结果展示
    final_comfort = -fvals(:,1);
    final_rula = fvals(:,2);

    % 找最优解
    [max_c, idx_c] = max(final_comfort);
    best_chair = x_opt(idx_c, :);

    fprintf('\n=== 优化结果 (Comfort Max) ===\n');
    fprintf('预测舒适度: %.2f\n', max_c);
    fprintf('预测 RULA : %.2f\n', final_rula(idx_c));
    fprintf('--- 推荐参数 ---\n');
    names = col_chair;
    for i = 1:length(names)
        fprintf('%s: %.1f\n', names{i}, best_chair(i));
    end
    %% 可视化 1: Pareto 前沿图 (展示舒适与健康的权衡)
figure('Color', 'w', 'Name', 'Pareto Front');
final_comfort = -fvals(:,1); % 负号转正
final_rula = fvals(:,2);

% 1. 绘制所有解的散点
scatter(final_rula, final_comfort, 60, 'filled', 'MarkerFaceColor', [0.6 0.6 0.6]); hold on;

% 2. 标记出最优解 (Max Comfort)
[max_c, idx_c] = max(final_comfort);
plot(final_rula(idx_c), max_c, 'rp', 'MarkerSize', 15, 'MarkerFaceColor', 'r');
text(final_rula(idx_c)+0.05, max_c, '  Recommend Solution', 'FontSize', 12, 'FontWeight', 'bold');

% 3. 美化图表
grid on;
xlabel('RULA Score (Lower is Better)', 'FontSize', 12);
ylabel('Comfort Rating (Higher is Better)', 'FontSize', 12);
title('Optimization Trade-off: Health vs. Comfort', 'FontSize', 14);
legend('Pareto Solutions', 'Best Comfort Choice', 'Location', 'SouthWest');

% 绘制区域背景 (可选)
xline(3, '--g', 'Low Risk Boundary');
yline(7, '--b', 'High Comfort Boundary');

%% 可视化 2: 3D 响应曲面 (座高 vs 靠背 vs 舒适度)
% 固定其他参数，只变动座高和靠背
figure('Color', 'w', 'Name', '3D Response Surface');

% 1. 生成网格
grid_size = 30;
h_range = linspace(40, 55, grid_size);  % 座高范围
a_range = linspace(90, 125, grid_size); % 靠背范围
[HH, AA] = meshgrid(h_range, a_range);

% 2. 准备预测矩阵
% 固定其他参数为最优解的值
fixed_depth = best_chair(2);
fixed_arm = best_chair(4);
fixed_lumbar = best_chair(5);
fixed_head = best_chair(6);

% 目标用户 (175cm)
user_vec = repmat(target_human, grid_size^2, 1);

% 构建输入矩阵
chair_vec = [HH(:), repmat(fixed_depth, grid_size^2, 1), AA(:), ...
             repmat(fixed_arm, grid_size^2, 1), repmat(fixed_lumbar, grid_size^2, 1), repmat(fixed_head, grid_size^2, 1)];

input_raw = [user_vec, chair_vec];

% 3. 标准化并预测 (利用之前的 mu 和 sigma)
input_norm_grid = (input_raw - mu) ./ sigma;
pred_comfort_grid = predict(Mdl_Comfort, input_norm_grid);
ZZ = reshape(pred_comfort_grid, grid_size, grid_size);

% 4. 绘图
surf(HH, AA, ZZ, 'EdgeColor', 'none');
colormap jet; colorbar;
hold on;

% 标记出最优解的位置
plot3(best_chair(1), best_chair(3), max_c, 'rp', 'MarkerSize', 20, 'MarkerFaceColor', 'w');

xlabel('Seat Height (cm)');
ylabel('Backrest Angle (deg)');
zlabel('Predicted Comfort');
title('Effect of Seat Height & Backrest on Comfort', 'FontSize', 14);
view(-30, 30); % 调整视角

%% 可视化 3: 参数对比图 (标准化对比)
figure('Color', 'w', 'Name', 'Parameter Comparison');

% 定义基准（Baseline）：比如所有样本的平均值
baseline_chair = mean(X_chair_data); 
optimized_chair = best_chair;

% 数据准备
data_compare = [baseline_chair; optimized_chair];
b = bar(data_compare', 'grouped');

% 美化
b(1).FaceColor = [0.5 0.5 0.5]; % 平均方案 (灰色)
b(2).FaceColor = [0.8 0.2 0.2]; % 优化方案 (红色)

xticklabels({'Height', 'Depth', 'Angle', 'Armrest', 'Lumbar', 'Headrest'});
ylabel('Parameter Value (cm / deg)');
title('Comparison: Average Design vs. Optimized Design');
legend('Average Existing Chair', 'AI-Optimized Chair');
grid on;

% 在柱子上标数值
x_tips1 = b(1).XEndPoints; y_tips1 = b(1).YEndPoints;
x_tips2 = b(2).XEndPoints; y_tips2 = b(2).YEndPoints;
text(x_tips1, y_tips1, string(round(y_tips1,1)),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',8);
text(x_tips2, y_tips2, string(round(y_tips2,1)),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',8,'Color','r');

%% 可视化 1: Pareto 前沿图 (风险约束优化版)
figure('Color', 'w', 'Name', 'Pareto Front Optimized');
set(gcf, 'Position', [100, 100, 700, 550]); % 设置图片长宽比，更适合论文

% 数据准备
pred_comfort = -fvals(:,1); % 负号转正
pred_rula    = fvals(:,2);

% --- 核心逻辑：方案B (RULA <= tau 下最大化舒适度) ---
tau = 3.3; % 设定风险阈值 (根据你的数据分布微调，比如3.0或3.3)

% 找出满足约束的解
feasible_idx = find(pred_rula <= tau);

if ~isempty(feasible_idx)
    % 在可行解中找舒适度最高的
    [max_c_feasible, idx_local] = max(pred_comfort(feasible_idx));
    idx_star = feasible_idx(idx_local);
    best_strategy = 'Risk-Constrained Opt';
else
    warning('没有满足 RULA <= %.1f 的解，退化为无约束最大舒适度', tau);
    [max_c_feasible, idx_star] = max(pred_comfort);
    best_strategy = 'Unconstrained Max Comfort';
end

% --- 绘图 ---
hold on; grid on; box on;

% 1. 绘制“高风险解”（灰色，作为背景）
scatter(pred_rula(pred_rula > tau), pred_comfort(pred_rula > tau), ...
    50, [0.7 0.7 0.7], 'filled', 'MarkerFaceAlpha', 0.6, ...
    'DisplayName', 'High Risk Solutions');

% 2. 绘制“低风险可行解”（蓝色，重点展示）
scatter(pred_rula(pred_rula <= tau), pred_comfort(pred_rula <= tau), ...
    70, [0.2 0.5 0.8], 'filled', 'MarkerFaceAlpha', 0.9, ...
    'DisplayName', sprintf('Feasible Solutions (RULA \\le %.1f)', tau));

% 3. 绘制风险阈值线
xline(tau, '--', {'Risk Threshold', sprintf('\\tau = %.1f', tau)}, ...
    'Color', [0.4660 0.6740 0.1880], 'LineWidth', 1.5, ...
    'LabelVerticalAlignment', 'bottom', 'FontSize', 11, ...
    'HandleVisibility', 'off'); % 不进图例

% 4. 标记最终推荐解 (红星)
plot(pred_rula(idx_star), pred_comfort(idx_star), 'p', ...
    'MarkerSize', 18, 'MarkerFaceColor', [0.85 0.32 0.1], 'MarkerEdgeColor', 'k', ...
    'LineWidth', 1.2, 'DisplayName', 'Recommended Solution');

% 添加文字标注
text(pred_rula(idx_star) - 0.05, pred_comfort(idx_star) + 0.08, ...
    {'  \bf{Optimal Choice}', sprintf('  Comfort: %.2f', pred_comfort(idx_star)), sprintf('  RULA: %.2f', pred_rula(idx_star))}, ...
    'FontSize', 10, 'BackgroundColor', 'w', 'EdgeColor', 'k', 'Margin', 3);

% --- 美化坐标轴 ---
xlabel('Predicted RULA Score (Lower is Better)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Predicted Comfort Rating (Higher is Better)', 'FontSize', 12, 'FontWeight', 'bold');
title({'Pareto Front of Chair Optimization', 'Trade-off: Comfort vs. Postural Risk'}, 'FontSize', 14);

% 图例设置
legend('Location', 'southeast', 'FontSize', 10, 'Box', 'on');

% 微调坐标范围 (留白)
xlim([min(pred_rula)-0.2, max(pred_rula)+0.2]);
ylim([min(pred_comfort)-0.2, max(pred_comfort)+0.3]);

hold off;

% 输出推荐结果供核对
fprintf('\n>>> 最终推荐方案 (%s) <<<\n', best_strategy);
fprintf('舒适度: %.2f, RULA: %.2f\n', pred_comfort(idx_star), pred_rula(idx_star));
fprintf('对应参数索引: %d\n', idx_star);




end % 主函数结束

%% --- 辅助函数 (必须放在 End 后面) ---
function val = evaluate_chair(chair_params, human_params, model_c, model_r, mu, sigma)
    % 1. 拼接
    input_raw = [human_params, chair_params];
    % 2. 标准化
    input_norm = (input_raw - mu) ./ sigma;
    % 3. 预测
    pred_c = predict(model_c, input_norm);
    pred_r = predict(model_r, input_norm);
    % 4. 输出
    val(1) = -pred_c;
    val(2) = pred_r;
end



