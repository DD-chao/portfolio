%% 第4章 实验描述与数据统计 (最终无错版)
clear; clc; close all;


%% 1. 加载数据
filename = 'shuju.xlsx'; 
if ~isfile(filename)
    error('未找到数据文件: %s', filename);
end
data = readtable(filename);


% 简单去重处理 (假设前100行是独立受试者，或者直接统计全部再除以2)
% 这里我们统计全部200行，你在填表时把 N 除以 2 即可，均值不受影响
subjects = data; 


fprintf('数据加载成功，共 %d 行样本。\n', height(subjects));


%% 2. 计算 Table 1 统计数据 (直接计算，不调用函数)
% 区分男女 (0=女, 1=男)
males = subjects(subjects.Gender == 1, :);
females = subjects(subjects.Gender == 0, :);


fprintf('\n=== Table 1. Demographics Statistics (请将 N 手动除以 2) ===\n');
fprintf('%-20s | Male (n=%d) | Female (n=%d) | Total (N=%d)\n', ...
    'Variable', height(males), height(females), height(subjects));
fprintf('-------------------------------------------------------------\n');


% Stature
fprintf('%-20s | %.1f±%.1f   | %.1f±%.1f     | %.1f±%.1f\n', 'Stature (cm)', ...
    mean(males.Sub_Stature), std(males.Sub_Stature), ...
    mean(females.Sub_Stature), std(females.Sub_Stature), ...
    mean(subjects.Sub_Stature), std(subjects.Sub_Stature));


% Weight
fprintf('%-20s | %.1f±%.1f   | %.1f±%.1f     | %.1f±%.1f\n', 'Weight (kg)', ...
    mean(males.Sub_Weight), std(males.Sub_Weight), ...
    mean(females.Sub_Weight), std(females.Sub_Weight), ...
    mean(subjects.Sub_Weight), std(subjects.Sub_Weight));


% BMI (需要计算)
bmi_m = males.Sub_Weight ./ ((males.Sub_Stature/100).^2);
bmi_f = females.Sub_Weight ./ ((females.Sub_Stature/100).^2);
bmi_all = subjects.Sub_Weight ./ ((subjects.Sub_Stature/100).^2);


fprintf('%-20s | %.1f±%.1f    | %.1f±%.1f     | %.1f±%.1f\n', 'BMI (kg/m^2)', ...
    mean(bmi_m), std(bmi_m), ...
    mean(bmi_f), std(bmi_f), ...
    mean(bmi_all), std(bmi_all));


% Sitting Height
fprintf('%-20s | %.1f±%.1f    | %.1f±%.1f     | %.1f±%.1f\n', 'Sitting Height', ...
    mean(males.Sub_Sitting_Height), std(males.Sub_Sitting_Height), ...
    mean(females.Sub_Sitting_Height), std(females.Sub_Sitting_Height), ...
    mean(subjects.Sub_Sitting_Height), std(subjects.Sub_Sitting_Height));


% Popliteal Height
fprintf('%-20s | %.1f±%.1f    | %.1f±%.1f     | %.1f±%.1f\n', 'Popliteal Height', ...
    mean(males.Sub_Popliteal_Height), std(males.Sub_Popliteal_Height), ...
    mean(females.Sub_Popliteal_Height), std(females.Sub_Popliteal_Height), ...
    mean(subjects.Sub_Popliteal_Height), std(subjects.Sub_Popliteal_Height));


fprintf('-------------------------------------------------------------\n');
fprintf('(注：请手动在 Word 表格中补充 Age 数据)\n');


%% 3. 绘制 Figure 4: RULA 与 舒适度分布图
figure('Color', 'w', 'Position', [100, 100, 900, 400]);


% --- 左图：RULA 分数分布 ---
subplot(1, 2, 1);
rula_counts = histcounts(data.RULA_Final, 1:8); % 统计 1-7 分的个数
b1 = bar(1.5:7.5, rula_counts, 0.6);
b1.FaceColor = [0.2 0.4 0.6]; % 深蓝色
b1.EdgeColor = 'none';


grid on; 
set(gca, 'Layer', 'top'); % 网格置顶


xlabel('RULA Final Score', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Frequency (Count)', 'FontSize', 11, 'FontWeight', 'bold');
title('(a) Distribution of Postural Risk (RULA)', 'FontSize', 12);
xticks(1:7);
ylim([0, max(rula_counts)*1.1]);


% 在柱子上标数值
text(1.5:7.5, rula_counts, string(rula_counts), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 10);


% --- 右图：舒适度评分分布 ---
subplot(1, 2, 2);
histogram(data.Comfort_Rating, 'BinEdges', 0.5:1:9.5, ...
    'FaceColor', [0.8 0.3 0.3], 'EdgeColor', 'w', 'FaceAlpha', 0.8);


grid on; 
set(gca, 'Layer', 'top'); % 网格置顶


xlabel('Subjective Comfort Rating', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Frequency (Count)', 'FontSize', 11, 'FontWeight', 'bold');
title('(b) Distribution of Comfort Rating', 'FontSize', 12);
xticks(1:9);
xlim([0.5, 9.5]);


fprintf('\n图表已生成，请截图或导出。\n');
