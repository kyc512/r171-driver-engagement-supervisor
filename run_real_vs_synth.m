function R = run_real_vs_synth(seeds)
%RUN_REAL_VS_SYNTH  실촬영 정상 주행과 합성 정상 운전 패턴의 시선 통계 비교 (중간발표 피드백 ①)
%   R = run_real_vs_synth           % 생성기 seed 1~10 x 1시간
%   결과: 표 출력 + docs/real_vs_synth.md
%
%   실촬영: ../dms_results 의 s1_1_*(표준 주행: 계기판·미러·숄더체크), s1_2_*(센터페시아 조작).
%           입력 단계(0점 보정 5초, 정면 범위)를 거친 주시 판정에서 보정 구간 5초를 빼고 센다.
%   합성:   supervisor_b/normal_pattern (highway / urban / infotainment).
%   두 쪽 모두 같은 함수로 주시 판정 시퀀스(100 Hz)에서 통계를 낸다.

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'src'), fullfile(fileparts(here), 'supervisor_b'));
if nargin < 1, seeds = 1:10; end
dt = 0.01; calib_s = 5;
P = des_params(3);

real_files = {'s1_1_1', 's1_1_2', 's1_2_1', 's1_2_2'};
real_desc  = {'표준 주행', '표준 주행', '센터페시아 조작', '센터페시아 조작'};
R = struct([]);
for k = 1:numel(real_files)
    D = dms_load_csv(fullfile(fileparts(here), 'dms_results', [real_files{k} '.csv']), calib_s);
    U = des_resample(D.ts, D.valid, D.yaw, D.pitch, P);
    L = sim_system(U, 3);
    g = L.gaze_on & U.valid;                    % 미검출은 이탈
    g = g(L.t > calib_s);
    r = stats_from_g(g, dt);
    r.name = sprintf('실촬영 %s (%s)', real_files{k}, real_desc{k});
    R = [R; r]; %#ok<AGROW>
end
sc = {'highway', 'urban', 'infotainment'};
for i = 1:numel(sc)
    S = cell(1, numel(seeds));
    for s = 1:numel(seeds), S{s} = stats_from_g(normal_pattern(sc{i}, 3600, dt, seeds(s)), dt); end
    S = [S{:}];
    r = S(1);
    for fld = {'dur', 'off_ratio', 'per_min', 'mean_off', 'med_off', 'over2', 'mean_on', 'max30'}
        r.(fld{1}) = mean([S.(fld{1})]);
    end
    r.dur = sum([S.dur]);
    r.max_off = max([S.max_off]);
    r.max30   = max([S.max30]);
    r.name = sprintf('합성 %s (1 h x %d)', sc{i}, numel(seeds));
    R = [R; r]; %#ok<AGROW>
end

hdr = ['| 데이터 | 길이 [s] | 이탈 비율 | 이탈 횟수/분 | 이탈 1회 평균 [s] | 중앙값 [s] | 최장 [s] | 2 s 초과 | ' ...
       '전방 주시 1회 평균 [s] | 30 s 창 누적 이탈 최대 [s] |' newline '|---|---|---|---|---|---|---|---|---|---|' newline];
body = '';
for k = 1:numel(R)
    r = R(k);
    if isnan(r.max30), m30 = '-'; else, m30 = sprintf('%.1f', r.max30); end
    body = [body sprintf('| %s | %.0f | %.0f%% | %.1f | %.2f | %.2f | %.2f | %.0f%% | %.2f | %s |\n', ...
            r.name, r.dur, r.off_ratio, r.per_min, r.mean_off, r.med_off, r.max_off, r.over2, r.mean_on, m30)]; %#ok<AGROW>
end
fprintf('\n%s%s', hdr, body);

fid = fopen(fullfile(here, 'docs', 'real_vs_synth.md'), 'w', 'n', 'UTF-8');
fprintf(fid, '# 실촬영 정상 주행과 합성 정상 운전 패턴 비교\n\n');
fprintf(fid, '`run_real_vs_synth.m`이 생성한 파일이다. 손으로 고치지 말 것. 생성: %s\n\n', char(datetime('today', 'Format', 'yyyy-MM-dd')));
fprintf(fid, '- 실촬영: DMS CSV(10 Hz)를 입력 단계(0점 보정 5초, 정면 범위 ±%g° / ±%g°)에 넣은 주시 판정. 보정 구간 5초는 뺀다. 얼굴 미검출은 이탈로 센다.\n', P.aoi_yaw, P.aoi_pitch);
fprintf(fid, '- 합성: `supervisor_b/normal_pattern` (미러 = 이탈). 평균은 seed 평균, 최장과 30 s 창 최대는 전체 seed의 최대.\n');
fprintf(fid, '- 실촬영은 촬영 프로토콜에 따라 시선 목표를 연달아 본 30~40초짜리 영상이다. 자연 주행보다 이탈이 촘촘하다는 점을 감안해서 읽는다.\n');
fprintf(fid, '- 이탈 비율과 30 s 창 누적은 주시 판정 그대로 센다. 횟수와 길이 통계는 0.2 s 미만 이탈(실촬영 10 Hz에서 1프레임짜리 각도 튐)을 빼고 센다. 합성에도 같은 규칙을 적용한다.\n\n');
fprintf(fid, '%s%s', hdr, body);
fclose(fid);
end

% =====================================================================
function r = stats_from_g(g, dt)
g = logical(g(:));
r.off_ratio = 100 * mean(~g);                    % 이탈 비율과 30 s 창은 원래 판정 그대로
n = round(30 / dt);
if numel(g) >= n
    c = cumsum([0; double(~g)]);
    r.max30 = max(c(n + 1:end) - c(1:end - n)) * dt;
else
    r.max30 = NaN;
end
% 횟수·길이 통계: 0.2 s 미만 이탈은 각도 튐으로 보고 주시로 메운다 (실촬영 10 Hz에서 1프레임)
d = diff([1; g; 1]);
s = find(d == -1); e = find(d == 1);
for k = find((e - s) * dt < 0.2 - 1e-9)', g(s(k):e(k) - 1) = true; end
d = diff([1; g; 1]);
s = find(d == -1); e = find(d == 1);
off = (e - s) * dt;                              % 이탈 구간 길이
d2 = diff([0; g; 0]);
on = (find(d2 == -1) - find(d2 == 1)) * dt;      % 전방 주시 구간 길이
r.name = '';
r.dur = numel(g) * dt;
r.per_min = numel(off) / (r.dur / 60);
r.mean_off = mean(off); r.med_off = median(off); r.max_off = max([off; 0]);
r.over2 = 100 * mean(off > 2.0);
r.mean_on = mean(on);
end
