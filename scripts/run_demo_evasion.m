%RUN_DEMO_EVASION  "4.8 s 딴짓 -> 0.3 s 전방" 반복을 M0~M3에 넣어 비교

here = fileparts(fileparts(mfilename('fullpath')));   % supervisor/ (scripts/의 한 단계 위)
addpath(fullfile(here, 'src'));

dt = 0.01; T = 60;
g = gaze_pattern(4.8, 0.3, T, dt, 2.0);     % 2 s 정상 주시 후 시작

names  = {'M0 R171 최소', 'M1 재관여 강화', 'M2 누적 이탈', 'M3 주의 버퍼'};
colors = [0.165 0.471 0.839; 0.922 0.408 0.204; 0.106 0.686 0.478; 0.929 0.631 0];
stages = {'ENGAGED', 'EOR', 'EOR 강화', 'DCA', 'UNAVAIL'};

fprintf('%-16s %6s %10s %8s %16s\n', 'model', 'n_EOR', 't_first', 'max', '경고없이 안 본 비율');
L = cell(1, 4);
for m = 0:3
    L{m+1} = sim_des(g, des_params(m));
    M = des_metrics(L{m+1});
    fprintf('%-16s %6d %10.2f %8s %15.1f%%\n', names{m+1}, M.n_eor, M.t_first_eor, ...
            stages{M.max_esc + 1}, 100 * M.off_frac_quiet);
end

figure('Name', 'Evasion 4.8/0.3', 'Color', 'w');
t = L{1}.t;
subplot(5, 1, 1);
stairs(t, double(g), 'Color', [0.32 0.32 0.31], 'LineWidth', 1);
ylim([-0.2 1.2]); yticks([0 1]); yticklabels({'이탈', '주시'});
title('입력: gaze\_in\_relevant\_area (4.8 s 이탈 / 0.3 s 주시)');
for m = 0:3
    subplot(5, 1, m + 2);
    stairs(t, double(L{m+1}.esc), 'Color', colors(m+1, :), 'LineWidth', 2);
    ylim([-0.3 4.3]); yticks(0:4); yticklabels(stages); grid on;
    title(names{m+1});
end
xlabel('time [s]');
