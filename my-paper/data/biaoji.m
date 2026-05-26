%% RULA 姿态分析系统 (有序版)
% 功能：按数字顺序处理图片，确保与Excel数据行对应

clear; clc; close all;

%% 1. 设置路径
imgFolder = 'E:\RTGXTP2'; 
outputExcel = 'RULA_Data_Ordered.xlsx'; 

if ~isfolder(imgFolder)
    error(['文件夹不存在: ' imgFolder]);
end

% 获取所有图片
filePattern = fullfile(imgFolder, '*.jpg'); 
files = dir(filePattern);
% 兼容png
if isempty(files)
    filePattern = fullfile(imgFolder, '*.png');
    files = dir(filePattern);
end

if isempty(files)
    error('未找到图片！');
end

%% 2. 核心升级：执行自然排序 (Natural Sort)
% 目的：确保 2.jpg 排在 10.jpg 前面
fileNames = {files.name};

% 使用正则表达式提取文件名中的第一个数字
% 例如 'S1_Cond.jpg' -> 1, 'S10_Cond.jpg' -> 10
fileNumbers = regexp(fileNames, '\d+', 'match', 'once');
fileNumbers = str2double(fileNumbers);

% 处理没有数字的文件名（防止报错）
fileNumbers(isnan(fileNumbers)) = inf; 

% 执行排序
[~, sortedIdx] = sort(fileNumbers);
sortedFiles = files(sortedIdx); % 重新排列文件结构体

nFiles = length(sortedFiles);
fprintf('已按数字顺序加载 %d 张图片。\n', nFiles);

%% 3. 初始化变量
pointNames = {'1.眼角', '2.耳屏', '3.肩峰', '4.手肘', '5.手腕', ...
              '6.手掌', '7.大转子', '8.膝盖', '9.脚踝'};
nPoints = length(pointNames);
resultTable = table();

%% 4. 循环处理
for i = 1:nFiles
    % 获取当前图片信息
    thisFile = sortedFiles(i);
    fileName = thisFile.name;
    fullPath = fullfile(imgFolder, fileName);
    
    % 提取ID (方便核对)
    currentID = regexp(fileName, '\d+', 'match', 'once');
    if isempty(currentID)
        currentID = '0';
    end
    
    try
        img = imread(fullPath);
    catch
        warning(['跳过损坏图片: ' fileName]);
        continue;
    end
    
    % --- 显示界面 ---
    f = figure('Name', ['处理进度: ' num2str(i) '/' num2str(nFiles) ' --- 当前文件: ' fileName], ...
               'NumberTitle', 'off', 'WindowState', 'maximized');
    imshow(img);
    hold on;
    
    title(['当前文件: ' fileName ' (ID: ' currentID ')'], 'FontSize', 16, 'Color', 'blue', 'Interpreter', 'none');
    
    x = zeros(nPoints, 1);
    y = zeros(nPoints, 1);
    
    % --- 交互取点 ---
    for k = 1:nPoints
        text(50, 100, ['请点击: \color{red}' pointNames{k}], ...
             'FontSize', 20, 'FontWeight', 'bold', 'BackgroundColor', 'white', 'EdgeColor', 'black');
        
        [px, py] = ginput(1);
        x(k) = px; y(k) = py;
        
        plot(x(k), y(k), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
        text(x(k)+10, y(k), num2str(k), 'Color', 'yellow', 'FontSize', 12);
    end
    
    % --- 计算角度 (带方向修正) ---
    % 1. 颈部前屈 (垂直线 vs 肩耳连线)
    angle_neck = atan2d(x(2)-x(3), -(y(2)-y(3)));
    
    % 2. 躯干前倾 (垂直线 vs 髋肩连线)
    angle_trunk = atan2d(x(3)-x(7), -(y(3)-y(7)));
    
    % 3. 上臂前屈 (垂直线 vs 肩肘连线)
    % 注意：如果手肘在肩膀后面(后伸)，这里会自动算出负值，符合逻辑
    angle_upper = atan2d(x(4)-x(3), -(y(4)-y(3)));
    
    % 4. 下臂/肘关节角 (上臂向量 vs 下臂向量)
    vec_up = [x(4)-x(3), -(y(4)-y(3))];
    vec_low = [x(5)-x(4), -(y(5)-y(4))];
    % 计算两向量夹角
    cos_elbow = dot(vec_up, vec_low) / (norm(vec_up)*norm(vec_low));
    angle_elbow = acosd(cos_elbow); 
    
    % 5. 膝关节内角 (大腿 vs 小腿)
    vec_thigh = [x(8)-x(7), -(y(8)-y(7))];
    vec_shank = [x(9)-x(8), -(y(9)-y(8))];
    cos_knee = dot(vec_thigh, vec_shank) / (norm(vec_thigh)*norm(vec_shank));
    angle_knee = acosd(cos_knee);
    
    % --- 连线可视化 ---
    skeleton = [1 2; 2 3; 3 4; 4 5; 5 6; 3 7; 7 8; 8 9];
    for j = 1:size(skeleton,1)
        plot(x(skeleton(j,:)), y(skeleton(j,:)), 'g-', 'LineWidth', 2);
    end
    
    % --- 自动保存带标记图 ---
    [~, fname, fext] = fileparts(fileName);
    saveas(f, fullfile(imgFolder, [fname '_Marked' fext]));
    
    % --- 存入表格 ---
    newRow = table({fileName}, str2double(currentID), angle_neck, angle_trunk, angle_upper, angle_elbow, angle_knee, ...
        'VariableNames', {'FileName', 'SubjectID', 'Neck_Flexion', 'Trunk_Flexion', 'Upper_Arm_Flexion', 'Elbow_Angle', 'Knee_Angle'});
    
    resultTable = [resultTable; newRow];
    
    close(f);
end

%% 5. 导出最终有序Excel
writetable(resultTable, fullfile(imgFolder, outputExcel));
fprintf('全部完成！数据已按顺序保存至: %s\n', outputExcel);
