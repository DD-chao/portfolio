function RF_NSGA2_Ultimate()  % <--- 这行必须是文件的第 1 行！！
    %% 主程序开始
    clc; close all;
    fprintf('程序启动...\n');

    % ... (中间是主程序的所有代码) ...
    % ... (数据读取、模型训练、GA优化) ...
    
    %% 1. 数据准备
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

    % 提取与标准化
    X_human = raw_data{:, col_human};
    X_chair = raw_data{:, col_chair};
    X = [X_human, X_chair];
    Y_comfort = raw_data.Comfort_Rating;
    Y_rula = raw_data.RULA_Final;

    % 保存 Z-score 参数
    [X_norm, mu, sigma] = zscore(X); 

    fprintf('数据加载成功，正在训练高精度模型...\n');

    %% 2. 训练随机森林
    nTrees = 200;
    Mdl_Comfort = TreeBagger(nTrees, X_norm, Y_comfort, 'Method', 'regression', 'OOBPrediction', 'on', 'MinLeafSize', 1);
    Mdl_RULA    = TreeBagger(nTrees, X_norm, Y_rula,    'Method', 'regression', 'OOBPrediction', 'on', 'MinLeafSize', 1);

    % 验证精度
    pred_c = predict(Mdl_Comfort, X_norm);
    r2_c = 1 - sum((Y_comfort - pred_c).^2) / sum((Y_comfort - mean(Y_comfort)).^2);
    fprintf('>>> 舒适度模型训练精度 (R2): %.4f\n', r2_c);

    %% 3. NSGA-II 优化设置
    target_human = [1, 175, 70, 92, 42, 46]; 
    lb = [40,  40,  90,  15,  10,  15]; 
    ub = [55,  55,  125, 30,  25,  30];

    % 调用子函数
    fitnessFcn = @(x) local_fitness(x, target_human, Mdl_Comfort, Mdl_RULA, mu, sigma);

    %% 4. 运行优化
    fprintf('正在寻找最优解 (NSGA-II)...\n');
    options = optimoptions('gamultiobj', 'PopulationSize', 100, 'MaxGenerations', 50, 'Display', 'final'); 

    [x_opt, fvals] = gamultiobj(fitnessFcn, 6, [], [], [], [], lb, ub, options);

    %% 5. 结果展示
    final_comfort = -fvals(:,1);
    final_rula = fvals(:,2);
    [max_c, idx] = max(final_comfort);
    best_chair = x_opt(idx, :);

    fprintf('\n====== 最终推荐结果 ======\n');
    fprintf('预期舒适度: %.2f\n', max_c);
    fprintf('预期 RULA : %.2f\n', final_rula(idx));
    disp('座椅参数:');
    disp(best_chair);

end % <--- 主程序在这里结束 (End of Main Function)


%% --- 子函数 (必须放在 End 的后面，文件的最底下！) ---
function val = local_fitness(chair_params, human_params, model_c, model_r, mu, sigma)
    % 1. 拼接
    input_raw = [human_params, chair_params];
    % 2. 标准化
    input_norm = (input_raw - mu) ./ sigma;
    % 3. 预测
    pred_c = predict(model_c, input_norm);F
    pred_r = predict(model_r, input_norm);
    % 4. 输出
    val(1) = -pred_c; 
    val(2) = pred_r;  
end
