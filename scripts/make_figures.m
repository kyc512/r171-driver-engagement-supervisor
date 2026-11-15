%MAKE_FIGURES  발표용 그림 생성 -> figures/*.png
%   fig1_timeline.png   : 4.8/0.3 회피 패턴에서 모델별 경고 단계
%   fig2_mechanism.png  : 모델별 내부량 (왜 M0만 못 잡는가)
%   fig3_detection_map.png : 이탈x복귀 격자 탐지 지도

here = fileparts(fileparts(mfilename('fullpath')));   % supervisor/ (scripts/의 한 단계 위)
addpath(fullfile(here, 'src'));
outdir = fullfile(here, 'figures');
if ~exist(outdir, 'dir'), mkdir(outdir); end
set(groot, 'defaultAxesFontName', 'Malgun Gothic', 'defaultTextFontName', 'Malgun Gothic', ...
           'defaultAxesFontSize', 11);

dt = 0.01;
names  = {'M0  R171 타이머 기준선', 'M1  재관여 강화 (1.0 s)', 'M2  최근 30 s 누적 이탈', 'M3  주의 버퍼'};
colors = [0.165 0.471 0.839; 0.922 0.408 0.204; 0.106 0.686 0.478; 0.929 0.631 0];
ink    = [0.32 0.32 0.31];
stages = {'정상', 'EOR', '강화 EOR', 'DCA', '운전불가'};

% ---------------- fig1: timeline ----------------
T = 40;
g = gaze_pattern(4.8, 0.3, T, dt, 2.0);
L = cell(1, 4);
for m = 0:3, L{m+1} = sim_des(g, des_params(m)); end
t = L{1}.t;

f = figure('Color', 'w', 'Position', [100 100 1100 780], 'Visible', 'off');
tl = tiledlayout(f, 5, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl);
area(ax, t, double(g), 'FaceColor', [0.70 0.70 0.68], 'EdgeColor', 'none');
ylim(ax, [0 1.3]); yticks(ax, [0 1]); yticklabels(ax, {'이탈', '주시'}); box(ax, 'off');
title(ax, '입력: 4.8 s 이탈 → 0.3 s 전방 주시 반복  (시간의 94% 이탈)', 'FontWeight', 'normal');
for m = 0:3
    ax = nexttile(tl);
    stairs(ax, t, double(L{m+1}.esc), 'Color', colors(m+1, :), 'LineWidth', 2);
    ylim(ax, [-0.3 4.4]); yticks(ax, 0:4); yticklabels(ax, stages);
    ax.YGrid = 'on'; ax.GridColor = [0.85 0.85 0.85]; box(ax, 'off');
    M = des_metrics(L{m+1});
    if isnan(M.t_first_eor)
        s = '경고 없음';
    else
        s = sprintf('첫 EOR %.1f s → %s', M.t_first_eor, stages{M.max_esc + 1});
    end
    title(ax, sprintf('%s   |   %s', names{m+1}, s), 'FontWeight', 'normal');
end
xlabel(ax, '시간 [s]');
exportgraphics(f, fullfile(outdir, 'fig1_timeline.png'), 'Resolution', 200);
close(f);

% ---------------- fig2: mechanism ----------------
T = 25;
g = gaze_pattern(4.8, 0.3, T, dt, 2.0);
f = figure('Color', 'w', 'Position', [100 100 1100 700], 'Visible', 'off');
tl = tiledlayout(f, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
spec = { ...
    0, '이탈 타이머 [s]',      5,  'M0: 0.3 s 주시마다 리셋 → 5 s 도달 못 함'; ...
    1, '이탈 타이머 [s]',      5,  'M1: 0.3 s로는 리셋 안 됨 (1.0 s 필요) → 누적되어 5 s 도달'; ...
    2, '최근 30 s 누적 이탈 [s]', 10, 'M2: 누적 이탈이 10 s 도달 → 경고'; ...
    3, '주의 버퍼 [s]',        0,  'M3: 이탈로 소모 > 주시로 회복 → 버퍼 0 → 경고'};
for r = 1:4
    m = spec{r, 1};
    Lm = sim_des(g, des_params(m));
    ax = nexttile(tl);
    hold(ax, 'on');
    on_mask = double(Lm.gaze_on);
    yl = [0 max([Lm.metric; spec{r, 3}]) * 1.15 + 0.5];
    area(ax, Lm.t, on_mask * yl(2), 'FaceColor', [0.90 0.90 0.88], 'EdgeColor', 'none');
    plot(ax, Lm.t, Lm.metric, 'Color', colors(m+1, :), 'LineWidth', 2);
    yline(ax, spec{r, 3}, '--', '경고 기준', 'Color', ink, 'LabelHorizontalAlignment', 'left');
    k = find(Lm.esc == 1, 1);
    if ~isempty(k)
        xline(ax, Lm.t(k), '-', sprintf('EOR %.1f s', Lm.t(k)), 'Color', [0.89 0.29 0.28], 'LineWidth', 1.2);
    end
    ylim(ax, yl); ylabel(ax, spec{r, 2}); box(ax, 'off');
    title(ax, spec{r, 4}, 'FontWeight', 'normal');
end
xlabel(ax, '시간 [s]   (회색 배경 = 전방 주시 구간)');
exportgraphics(f, fullfile(outdir, 'fig2_mechanism.png'), 'Resolution', 200);
close(f);

% ---------------- fig3: detection map ----------------
T = 90;
off_list = 1.0:0.5:6.0;
on_list  = 0.1:0.1:2.0;
R = nan(numel(off_list), numel(on_list), 4);
for m = 0:3
    P = des_params(m);
    for i = 1:numel(off_list)
        for j = 1:numel(on_list)
            gg = gaze_pattern(off_list(i), on_list(j), T, dt, 2.0);
            R(i, j, m+1) = des_metrics(sim_des(gg, P)).t_first_eor;
        end
    end
end
save(fullfile(outdir, 'evasion_grid.mat'), 'R', 'off_list', 'on_list', 'T');

cmap = [linspace(0.05, 0.80, 64)' linspace(0.21, 0.89, 64)' linspace(0.42, 0.98, 64)'];
f = figure('Color', 'w', 'Position', [100 100 1100 820], 'Visible', 'off');
tl = tiledlayout(f, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for m = 1:4
    ax = nexttile(tl);
    h = imagesc(ax, on_list, off_list, R(:, :, m), [0 40]);
    set(h, 'AlphaData', ~isnan(R(:, :, m)));
    set(ax, 'YDir', 'normal', 'Color', [0.93 0.93 0.92]);
    colormap(ax, cmap);
    n_det = sum(~isnan(R(:, :, m)), 'all');
    title(ax, sprintf('%s  —  %d / %d 탐지', names{m}, n_det, numel(R(:, :, m))), 'FontWeight', 'normal');
    xlabel(ax, '1회 전방 주시 시간 [s]'); ylabel(ax, '1회 이탈 시간 [s]');
    hold(ax, 'on');
    plot(ax, 0.3, 4.8, 'o', 'MarkerSize', 9, 'MarkerEdgeColor', [0.89 0.29 0.28], 'LineWidth', 2);
end
cb = colorbar(ax); cb.Layout.Tile = 'east'; cb.Label.String = '첫 EOR까지 시간 [s]  (회색 = 90 s 동안 경고 없음)';
exportgraphics(f, fullfile(outdir, 'fig3_detection_map.png'), 'Resolution', 200);
close(f);

fprintf('saved to %s\n', outdir);
