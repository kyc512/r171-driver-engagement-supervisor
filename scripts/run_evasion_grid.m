%RUN_EVASION_GRID  이탈/복귀 시간 격자에서 모델별 탐지 여부 (탐지 영역 지도 초안)
%   셀 값 = 첫 EOR까지 시간 [s]. 빈칸(NaN) = T 동안 경고 없음(회피 성공)
%   격자가 크면 느림 -> build_codegen.m 의 MEX 옵션 참고

here = fileparts(fileparts(mfilename('fullpath')));   % supervisor/ (scripts/의 한 단계 위)
addpath(fullfile(here, 'src'));

dt = 0.01; T = 90;
off_list = 1.0:0.5:6.0;          % 1회 이탈 시간 [s]
on_list  = 0.1:0.1:2.0;          % 1회 복귀 시간 [s]
names = {'M0', 'M1', 'M2', 'M3'};

R = nan(numel(off_list), numel(on_list), 4);
for m = 0:3
    P = des_params(m);
    for i = 1:numel(off_list)
        for j = 1:numel(on_list)
            g = gaze_pattern(off_list(i), on_list(j), T, dt, 2.0);
            R(i, j, m+1) = des_metrics(sim_des(g, P)).t_first_eor;
        end
    end
    fprintf('%s done\n', names{m+1});
end
save(fullfile(here, 'evasion_grid.mat'), 'R', 'off_list', 'on_list', 'T', 'names');

figure('Name', 'Detection map', 'Color', 'w');
for m = 1:4
    subplot(2, 2, m);
    h = imagesc(on_list, off_list, R(:, :, m), [0 T]);
    set(h, 'AlphaData', ~isnan(R(:, :, m)));   % 미탐지 = 배경색
    set(gca, 'YDir', 'normal', 'Color', [0.94 0.94 0.93]);
    % 단일 색상 순차 램프: 빨리 탐지할수록 진함
    cmap = [linspace(0.05, 0.80, 64)' linspace(0.21, 0.89, 64)' linspace(0.42, 0.98, 64)'];
    colormap(gca, cmap); colorbar;
    xlabel('복귀(주시) 시간 [s]'); ylabel('이탈 시간 [s]');
    title(sprintf('%s: 첫 EOR 시각 [s] (회색 = 미탐지)', names{m}));
end
