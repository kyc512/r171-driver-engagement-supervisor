function A = run_adaptive_limit(T)
%RUN_ADAPTIVE_LIMIT  적응형 회피 한계: 모델을 아는 운전자가 경고 없이 얼마나 안 볼 수 있는가
%   A = run_adaptive_limit          % 120 s
%   A = run_adaptive_limit(T)
%   run_adaptive_limit('plot')      % build/adaptive_limit.mat 로 그림만 다시
%
%   이탈 0.5~6 s x 주시 0.1~3 s 주기 패턴(2 s 정상 주시 후 시작)을 T초 동안 넣고,
%   EOR이 한 번도 나지 않은 패턴 중 이탈 비율 = 이탈 / (이탈 + 주시) 의 최대값을 모델별로 구한다.
%   이 값이 낮을수록, 모델의 기준을 정확히 알고 맞춰 움직이는 운전자도 오래 안 볼 수 없다.
%   결과: build/adaptive_limit.mat, figures/fig4_adaptive_limit.png, 표 출력

here = fileparts(fileparts(mfilename('fullpath')));   % supervisor/ (scripts/의 한 단계 위)
addpath(fullfile(here, 'src'));
if nargin < 1, T = 120; end
if ischar(T)                                   % run_adaptive_limit('plot'): 저장된 결과로 그림만 다시
    S = load(fullfile(here, 'build', 'adaptive_limit.mat')); A = S.A;
    plot_limit(A, here); return
end
dt = 0.01;
off_list = 0.5:0.25:6.0;
on_list  = 0.1:0.1:3.0;

quiet = false(numel(off_list), numel(on_list), 4);
for m = 0:3
    P = des_params(m);
    for i = 1:numel(off_list)
        for j = 1:numel(on_list)
            g = gaze_pattern(off_list(i), on_list(j), T, dt, 2.0);
            quiet(i, j, m + 1) = isnan(des_metrics(sim_des(g, P)).t_first_eor);
        end
    end
end
ratio = 100 * off_list(:) ./ (off_list(:) + on_list);      % 이탈 비율 [%]

A = struct('T', T, 'off_list', off_list, 'on_list', on_list, 'quiet', quiet, 'ratio', ratio, ...
           'max_ratio', zeros(1, 4), 'at_off', zeros(1, 4), 'at_on', zeros(1, 4));
fprintf('\n| 모델 | 경고 없이 가능한 최대 이탈 비율 | 그때의 패턴 (이탈 / 주시) |\n|---|---|---|\n');
for m = 1:4
    r = ratio; r(~quiet(:, :, m)) = -1;
    [A.max_ratio(m), k] = max(r(:));
    [i, j] = ind2sub(size(r), k);
    A.at_off(m) = off_list(i); A.at_on(m) = on_list(j);
    fprintf('| M%d | %.1f%% | %.2f s / %.1f s |\n', m - 1, A.max_ratio(m), off_list(i), on_list(j));
end
if ~exist(fullfile(here, 'build'), 'dir'), mkdir(fullfile(here, 'build')); end
save(fullfile(here, 'build', 'adaptive_limit.mat'), 'A');
plot_limit(A, here);
end

% =====================================================================
function plot_limit(A, here)
T = A.T; off_list = A.off_list; on_list = A.on_list; quiet = A.quiet; ratio = A.ratio;
fn = 'Malgun Gothic';
names  = {'M0  R171 최소 구현', 'M1  재관여 강화 (1.0 s)', 'M2  최근 30 s 누적 이탈', 'M3  주의 버퍼'};
colors = [0.165 0.471 0.839; 0.922 0.408 0.204; 0.106 0.686 0.478; 0.929 0.631 0];
cmap = [linspace(0.99, 0.80, 64)' linspace(0.93, 0.20, 64)' linspace(0.85, 0.15, 64)'];
f = figure('Color', 'w', 'Position', [100 100 1500 760], 'Visible', 'off');
tl = tiledlayout(f, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
pos = [1 2 4 5];
for m = 1:4
    ax = nexttile(tl, pos(m));
    r = ratio; r(~quiet(:, :, m)) = NaN;
    h = imagesc(ax, on_list, off_list, r, [0 100]);
    set(h, 'AlphaData', ~isnan(r));
    set(ax, 'YDir', 'normal', 'Color', [0.93 0.93 0.92], 'FontName', fn);
    colormap(ax, cmap); hold(ax, 'on');
    plot(ax, A.at_on(m), A.at_off(m), 'ko', 'MarkerSize', 9, 'LineWidth', 2);
    title(ax, sprintf('%s  —  최대 %.1f%% (%.2f / %.1f s)', names{m}, A.max_ratio(m), ...
          A.at_off(m), A.at_on(m)), 'FontWeight', 'normal', 'FontName', fn);
    xlabel(ax, '1회 전방 주시 시간 [s]'); ylabel(ax, '1회 이탈 시간 [s]');
end
cb = colorbar(ax); cb.Label.String = sprintf('경고 없는 패턴의 이탈 비율 [%%]  (회색 = %d s 안에 경고)', T);
cb.Label.FontName = fn;

ax = nexttile(tl, 3, [2 1]); hold(ax, 'on');
for m = 1:4
    bar(ax, m, A.max_ratio(m), 0.6, 'FaceColor', colors(m, :), 'EdgeColor', 'none');
    text(ax, m, A.max_ratio(m) + 2, sprintf('%.0f%%', A.max_ratio(m)), 'HorizontalAlignment', 'center', ...
         'FontName', fn, 'FontSize', 12);
end
% 실촬영 정상 주행 s1_1_2, s1_2_1, s1_2_2 의 이탈 비율 (보정 5초 제외, docs/real_vs_synth.md)
patch(ax, [0.4 4.6 4.6 0.4], [33 33 38 38], [0.3 0.3 0.3], 'FaceAlpha', 0.18, 'EdgeColor', 'none');
text(ax, 0.5, 40.5, '실촬영 정상 주행의 이탈 비율 33~38%', 'FontName', fn, 'FontSize', 10, 'Color', [0.25 0.25 0.25]);
set(ax, 'XTick', 1:4, 'XTickLabel', {'M0', 'M1', 'M2', 'M3'}, 'FontName', fn, 'YGrid', 'on');
ylim(ax, [0 105]); xlim(ax, [0.4 4.6]);
ylabel(ax, '경고 없이 가능한 최대 이탈 비율 [%]');
title(ax, '적응형 회피 한계', 'FontWeight', 'normal', 'FontName', fn);

if ~exist(fullfile(here, 'figures'), 'dir'), mkdir(fullfile(here, 'figures')); end
exportgraphics(f, fullfile(here, 'figures', 'fig4_adaptive_limit.png'), 'Resolution', 200);
close(f);
end
