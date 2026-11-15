function R = run_operating_point(m, vals, seeds)
%RUN_OPERATING_POINT  탐지율-오경보 트레이드오프: 모델별 핵심 파라미터를 훑어 동작점 후보를 만든다
%   R = run_operating_point(m)              % m = 0~3, 기본 파라미터 범위, seed 1~10
%   R = run_operating_point(m, vals, seeds)
%   run_operating_point('plot')             % build/op_M*.mat -> figures/operating_point.png + 표
%
%   훑는 파라미터 (나머지는 des_params 기본값)
%     M0: 없음 (기준점 1개)
%     M1: m1_T_reengage  재관여 인정 시간 [s]
%     M2: m2_T_cum       30 s 창 안의 누적 이탈 기준 [s] (Euro NCAP VATS = 10)
%     M3: m3_B_max       주의 버퍼 상한 [s] (AttenD = 2, R171 하한 보장 위해 <= 5)
%   탐지: 이탈 1~6 s x 주시 0.1~2 s 격자 220칸(각 90 s)에서 EOR이 한 번이라도 난 칸의 비율, 4.8/0.3 첫 EOR
%   오경보: supervisor_b 정상 운전 생성기 (highway / urban / infotainment) 1시간 x seed, 시간당 EOR 진입 횟수
%           운전자는 DCA에 응답(driver_action = 1)한다고 둔다. 응답이 없으면 운전불가에서 멈춰 EOR이 덜 세어진다.

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'src'), fullfile(fileparts(here), 'supervisor_b'));
if ischar(m) && strcmp(m, 'plot'), R = plot_all(here); return, end
if nargin < 2 || isempty(vals)
    vals = {NaN, [0.2 0.4 0.6 0.8 1.0 1.2 1.5 2.0], [8 10 12 14 16 18 20], [2 2.5 3 3.5 4 4.5 5]};
    vals = vals{m + 1};
end
if nargin < 3, seeds = 1:10; end
pname = {'', 'm1_T_reengage', 'm2_T_cum', 'm3_B_max'};

dt = 0.01;
off_list = 1.0:0.5:6.0; on_list = 0.1:0.1:2.0;
sc = {'highway', 'urban', 'infotainment'};
G = cell(numel(sc), numel(seeds));
for i = 1:numel(sc)
    for s = 1:numel(seeds), G{i, s} = normal_pattern(sc{i}, 3600, dt, seeds(s)); end
end

R = struct('model', m, 'param', pname{m + 1}, 'vals', vals, 'seeds', seeds, 'scen', {sc}, ...
           'det', nan(size(vals)), 'ev48', nan(size(vals)), 'fa', nan(numel(vals), numel(sc)), ...
           'warn', nan(numel(vals), numel(sc)));
for v = 1:numel(vals)
    P = des_params(m);
    if m > 0, P.(pname{m + 1}) = vals(v); end
    det = 0;
    for a = off_list
        for b = on_list
            det = det + ~isnan(des_metrics(sim_des(gaze_pattern(a, b, 90, dt, 2.0), P)).t_first_eor);
        end
    end
    R.det(v)  = det / (numel(off_list) * numel(on_list));
    R.ev48(v) = des_metrics(sim_des(gaze_pattern(4.8, 0.3, 60, dt, 2.0), P)).t_first_eor;
    for i = 1:numel(sc)
        n = 0; w = 0;
        for s = 1:numel(seeds)
            g = G{i, s};
            L = sim_des(g, P, [], true(size(g)));
            n = n + des_metrics(L).n_eor;
            w = w + mean(L.esc >= 1);
        end
        R.fa(v, i)   = n / numel(seeds);
        R.warn(v, i) = 100 * w / numel(seeds);   % 경고(EOR 이상)가 켜져 있던 시간 비율 [%]
    end
    fprintf('M%d %s = %g: 격자 %.1f%%, 4.8/0.3 %.2f s, EOR/h %s, 경고 시간%% %s\n', m, pname{m + 1}, vals(v), ...
            100 * R.det(v), R.ev48(v), sprintf('%.2f ', R.fa(v, :)), sprintf('%.2f ', R.warn(v, :)));
end
save(fullfile(here, 'build', sprintf('op_M%d.mat', m)), 'R');
end

% =====================================================================
function A = plot_all(here)
A = cell(1, 4);
for m = 0:3
    f = fullfile(here, 'build', sprintf('op_M%d.mat', m));
    if exist(f, 'file'), S = load(f); A{m + 1} = S.R; end
end
col = [0.4 0.4 0.4; 0.85 0.33 0.1; 0.0 0.45 0.74; 0.47 0.67 0.19];
lab = {'M0 (R171 기준선)', 'M1 재관여 시간', 'M2 누적 기준 (30 s 창)', 'M3 버퍼 상한'};
unit = {'', 's', 's', 's'};
f = figure('Color', 'w', 'Position', [100 100 1150 900], 'Visible', 'off');
tl = tiledlayout(f, 2, 2, 'TileSpacing', 'compact');
ttl = {'urban', 'infotainment'};
for q = 1:4
    k = mod(q - 1, 2) + 1; use_warn = q > 2;
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
    for m = 0:3
        R = A{m + 1}; if isempty(R), continue, end
        if use_warn, x = R.warn(:, k + 1); else, x = R.fa(:, k + 1); end
        y = 100 * R.det(:);
        plot(ax, x, y, '-o', 'Color', col(m + 1, :), 'MarkerFaceColor', col(m + 1, :), 'LineWidth', 1.5, ...
             'DisplayName', lab{m + 1});
        if m > 0
            for v = 1:numel(R.vals)
                text(ax, x(v), y(v), sprintf('  %g%s', R.vals(v), unit{m + 1}), 'FontSize', 8, ...
                     'Color', col(m + 1, :), 'FontName', 'Malgun Gothic');
            end
        end
    end
    if use_warn, xl = '정상 운전 중 경고가 켜져 있던 시간 [%]'; else, xl = '정상 운전 오경보 [EOR 진입/시간]'; end
    xlabel(ax, xl, 'FontName', 'Malgun Gothic');
    ylabel(ax, '회피 격자 탐지율 [%]', 'FontName', 'Malgun Gothic');
    title(ax, sprintf('%s (생성기 1시간 x %d seed)', ttl{k}, numel(A{2}.seeds)), 'FontName', 'Malgun Gothic');
    set(ax, 'FontName', 'Malgun Gothic');
    if q == 1, legend(ax, 'Location', 'southeast'); end
end
if ~exist(fullfile(here, 'figures'), 'dir'), mkdir(fullfile(here, 'figures')); end
exportgraphics(f, fullfile(here, 'figures', 'operating_point.png'), 'Resolution', 150);
close(f);

fprintf('\n| 모델 | 파라미터 | 값 | 격자 탐지 | 4.8/0.3 첫 EOR | EOR/h highway | urban | infotainment | 경고 시간%% urban | infotainment |\n|---|---|---|---|---|---|---|---|---|---|\n');
for m = 0:3
    R = A{m + 1}; if isempty(R), continue, end
    for v = 1:numel(R.vals)
        fprintf('| M%d | %s | %g | %.1f%% | %s | %.2f | %.2f | %.2f | %.2f | %.2f |\n', m, strrep(R.param, '_', '\_'), R.vals(v), ...
                100 * R.det(v), num2s(R.ev48(v)), R.fa(v, :), R.warn(v, 2:3));
    end
end
end

function s = num2s(x)
if isnan(x), s = '없음'; else, s = sprintf('%.2f s', x); end
end
