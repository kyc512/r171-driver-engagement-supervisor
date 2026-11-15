function make_dms_figures(folder, calib_s, outdir)
%MAKE_DMS_FIGURES  DMS 실촬영 CSV별 타임라인 그림 -> figures/dms/<파일명>.png
%   make_dms_figures                       % ../dms_results/*.csv, 처음 5초 0점 보정
%   make_dms_figures(folder, calib_s, outdir)
%
%   위에서부터: yaw, pitch (보정 후, 회색 띠 = 정면 범위), 입력 단계의 주시 판정,
%   M0~M3 경고 단계. 시스템 전체 기준 동작(sim_system)을 그대로 쓴다.

here = fileparts(fileparts(mfilename('fullpath')));   % supervisor/ (scripts/의 한 단계 위)
addpath(fullfile(here, 'src'));
if nargin < 1 || isempty(folder), folder = fullfile(fileparts(here), 'dms_results'); end
if nargin < 2 || isempty(calib_s), calib_s = 5; end
if nargin < 3 || isempty(outdir), outdir = fullfile(here, 'figures', 'dms'); end
if ~exist(outdir, 'dir'), mkdir(outdir); end

fn = 'Malgun Gothic';
names  = {'M0  R171 타이머 기준선', 'M1  재관여 강화', 'M2  30 s 누적 이탈', 'M3  주의 버퍼'};
colors = [0.165 0.471 0.839; 0.922 0.408 0.204; 0.106 0.686 0.478; 0.929 0.631 0];
stages = {'정상', 'EOR', '강화 EOR', 'DCA', '운전불가'};
band   = [0.88 0.88 0.86];
P = des_params(3);

files = dir(fullfile(folder, '*.csv'));
files = files(~strcmpi({files.name}, 'scenario_map.csv'));
for k = 1:numel(files)
    name = erase(files(k).name, '.csv');
    D = dms_load_csv(fullfile(files(k).folder, files(k).name), calib_s);
    U = des_resample(D.ts, D.valid, D.yaw, D.pitch, P);
    esc = zeros(numel(U.valid), 4);
    for m = 1:3
        L = sim_system(U, m);
        if m == 1, esc(:, 1) = L.esc(:, 1); gaze_on = L.gaze_on; frozen = L.frozen; end
        esc(:, m + 1) = L.esc(:, 2);
    end
    t = L.t; tmax = t(end);
    yaw = D.yaw; pitch = D.pitch; yaw(~D.valid) = NaN; pitch(~D.valid) = NaN;

    f = figure('Color', 'w', 'Position', [100 100 1100 900], 'Visible', 'off');
    tl = tiledlayout(f, 7, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('%s   (0점 보정: 처음 %g s, yaw %.1f°, pitch %.1f°)', strrep(name, '_', '\_'), ...
          calib_s, D.yaw0, D.pitch0), 'FontName', fn, 'FontSize', 12);

    ang = {yaw, pitch}; lim = [P.aoi_yaw, P.aoi_pitch]; lab = {'yaw [°]', 'pitch [°]'};
    for a = 1:2
        ax = nexttile(tl); hold(ax, 'on');
        patch(ax, [0 tmax tmax 0], lim(a) * [-1 -1 1 1], band, 'EdgeColor', 'none');
        plot(ax, D.ts, ang{a}, 'Color', [0.2 0.2 0.2], 'LineWidth', 1);
        xlim(ax, [0 tmax]); ylabel(ax, lab{a}); box(ax, 'off'); set(ax, 'FontName', fn, 'XTickLabel', []);
        if a == 1, title(ax, sprintf('DMS 각도 (회색 띠 = 정면 범위 ±%g° / ±%g°, 끊긴 곳 = 얼굴 미검출)', ...
                         P.aoi_yaw, P.aoi_pitch), 'FontWeight', 'normal', 'FontName', fn); end
    end

    ax = nexttile(tl); hold(ax, 'on');
    area(ax, t, double(gaze_on), 'FaceColor', [0.70 0.70 0.68], 'EdgeColor', 'none');
    if any(frozen), area(ax, t, 1.25 * double(frozen), 'FaceColor', [0.89 0.29 0.28], 'FaceAlpha', 0.35, 'EdgeColor', 'none'); end
    xlim(ax, [0 tmax]); ylim(ax, [0 1.3]); yticks(ax, [0 1]); yticklabels(ax, {'이탈', '주시'});
    box(ax, 'off'); set(ax, 'FontName', fn, 'XTickLabel', []);
    s = sprintf('주시 판정   |   이탈 비율 %.0f%%', 100 * mean(~gaze_on(t > calib_s)));
    if any(frozen), s = [s sprintf('   |   빨강 = 고정 판정 %.1f s', nnz(frozen) * P.dt)]; end
    title(ax, s, 'FontWeight', 'normal', 'FontName', fn);

    for m = 1:4
        ax = nexttile(tl);
        stairs(ax, t, esc(:, m), 'Color', colors(m, :), 'LineWidth', 2);
        xlim(ax, [0 tmax]); ylim(ax, [-0.3 4.4]); yticks(ax, 0:4); yticklabels(ax, stages);
        ax.YGrid = 'on'; ax.GridColor = [0.85 0.85 0.85]; box(ax, 'off'); set(ax, 'FontName', fn);
        i = find(esc(:, m) >= 1, 1);
        if isempty(i), s = '경고 없음'; else, s = sprintf('첫 EOR %.1f s → %s', t(i), stages{max(esc(:, m)) + 1}); end
        title(ax, sprintf('%s   |   %s', names{m}, s), 'FontWeight', 'normal', 'FontName', fn);
        if m < 4, set(ax, 'XTickLabel', []); end
    end
    xlabel(ax, '시간 [s]');
    exportgraphics(f, fullfile(outdir, [name '.png']), 'Resolution', 150);
    close(f);
    fprintf('%s.png\n', name);
end
fprintf('saved to %s\n', outdir);
end
