function val = evaluate_chair(chair_params, human_params, model_c, model_r, mu, sigma)
    % EVALUATE_CHAIR 适应度评估函数
    % 输入: 
    %   chair_params: GA生成的座椅参数 (1x6)
    %   human_params: 目标用户身体数据 (1x6)
    %   model_c, model_r: 训练好的随机森林模型
    %   mu, sigma: 用于标准化的均值和标准差
    
    % 1. 拼接输入向量 [人体特征, 座椅参数]
    input_raw = [human_params, chair_params];
    
    % 2. 执行 Z-score 标准化 (必须与训练时一致)
    input_norm = (input_raw - mu) ./ sigma;
    
    % 3. 调用模型预测
    pred_c = predict(model_c, input_norm);
    pred_r = predict(model_r, input_norm);
    
    % 4. 定义优化目标 (NSGA-II 默认求最小值)
    % 目标1: 最大化舒适度 -> 也就是最小化 (-舒适度)
    val(1) = -pred_c; 
    
    % 目标2: 最小化 RULA 分数
    val(2) = pred_r;
end
