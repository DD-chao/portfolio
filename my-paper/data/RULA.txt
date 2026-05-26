%% RULA 分数计算器 (最终完美版)
% 修正说明：
% 1. 躯干：正数=后靠(Recline)。<60度且有支撑 = 1分。
% 2. 颈部：正数=低头(Flexion)，负数=后仰(Extension)。
% 3. 严格标准：颈部后仰即判4分。

clear; clc;

%% 1. 设置
imgFolder = 'E:\RTGXTP2'; 
inputFile = 'RULA_Data_Ordered.xlsx'; 
outputFile = 'RULA_Data_Final_Perfect.xlsx'; 

fullPath = fullfile(imgFolder, inputFile);
if ~isfile(fullPath)
    error('未找到输入文件: %s', fullPath);
end

data = readtable(fullPath);
nRows = height(data);
fprintf('正在处理 %d 组数据 (最终逻辑修正)...\n', nRows);

%% 2. 查表矩阵
Matrix_A = [1 2 2; 2 3 3; 3 3 4; 4 4 4; 5 5 6; 7 7 8];
Matrix_B = [1 3 2 3 4 5; 2 3 2 3 4 5; 3 3 3 4 4 5; 5 5 5 6 6 7; 7 7 7 7 7 8; 8 8 8 8 8 8];
Matrix_C = [1 2 3 3 4 5 5; 2 2 3 4 4 5 5; 3 3 3 4 4 5 6; 3 3 3 4 5 6 6; 4 4 4 5 6 7 7; 4 4 5 6 6 7 7; 5 5 6 6 7 7 7; 5 5 7 7 7 7 7];

%% 3. 循环计算
rula_final = zeros(nRows, 1);
score_A_vec = zeros(nRows, 1);
score_B_vec = zeros(nRows, 1);

for i = 1:nRows
    % 读取原始角度
    raw_neck = data.Neck_Flexion(i);
    raw_trunk = data.Trunk_Flexion(i);
    raw_up_arm = data.Upper_Arm_Flexion(i);
    raw_elbow = data.Elbow_Angle(i);
    
    % ========================================================
    % 1. 上臂修正 (几何修正)
    % ========================================================
    real_up_arm = 180 - abs(raw_up_arm);
    
    % ========================================================
    % 2. 躯干修正 (方向修正)
    % ========================================================
    % 正数 = 后靠 (Recline)，负数 = 前倾 (Flexion)
    
    trunk_score = 1; 
    if raw_trunk >= 0
        % --- 后靠状态 ---
        if raw_trunk <= 60
            trunk_score = 1; % 有靠背支撑，给1分 (之前误判为3分)
        else
            trunk_score = 4; % 躺太过了
        end
    else
        % --- 前倾状态 ---
        abs_trunk = abs(raw_trunk);
        if abs_trunk <= 20, trunk_score = 2;
        elseif abs_trunk <= 60, trunk_score = 3;
        else, trunk_score = 4; end
    end
    
    % ========================================================
    % 3. 颈部打分 (正负逻辑修正)
    % ========================================================
    % 你的数据：正数=低头(好)，负数=后仰(坏)
    % 所以直接用原始值判断，不需要取反
    
    neck_angle = raw_neck; 
    
    neck_score = 1;
    if neck_angle >= 0
        % --- 低头 (Flexion) ---
        if neck_angle <= 10
            neck_score = 1; % 0-10度 完美
        elseif neck_angle <= 20
            neck_score = 2;
        else
            neck_score = 3;
        end
    else
        % --- 后仰 (Extension) ---
        % 严格 RULA: 后仰即 4分
        neck_score = 4; 
    end

    % ========================================================
    % 4. 计算其余分数
    % ========================================================
    
    % 下臂
    la_score = 1;
    if raw_elbow < 60 || raw_elbow > 100
        la_score = 2;
    end
    
    % Score A (上肢)
    if real_up_arm <= 20, ua_s = 1;
    elseif real_up_arm <= 45, ua_s = 2;
    elseif real_up_arm <= 90, ua_s = 3;
    else, ua_s = 4; end
    
    idx_ua = min(ua_s, 6);
    idx_la = min(la_score, 3);
    score_A = Matrix_A(idx_ua, idx_la);
    score_A = min(score_A, 9);
    
    % Score B (躯干)
    idx_neck = min(neck_score, 6);
    idx_trunk = min(trunk_score, 6);
    score_B = Matrix_B(idx_neck, idx_trunk);
    score_B = min(score_B, 9);
    
    % 最终分
    idx_A = min(score_A, 8);
    idx_B = min(score_B, 7);
    final_score = Matrix_C(idx_A, idx_B);
    
    % 存入
    rula_final(i) = final_score;
    score_A_vec(i) = score_A;
    score_B_vec(i) = score_B;
end

%% 保存
data.Score_A = score_A_vec;
data.Score_B = score_B_vec;
data.RULA_Final = rula_final;

writetable(data, fullfile(imgFolder, outputFile));
fprintf('修正完成！\n');
fprintf('图3 (3.jpg) 的 Score_B 应该会降到 1 或 2。\n');
fprintf('图4 (4.jpg) 的 Score_B 应该保持较高 (因颈部后仰)。\n');
fprintf('结果已保存: %s\n', outputFile);
