function R = run_dms_results(folder, calib_s, c_log_dir)
%RUN_DMS_RESULTS  DMS 팀 실촬영 CSV를 Supervisor 전체(입력 단계 + M0~M3)에 넣어 결과 표 출력
%   R = run_dms_results                    ../dms_results/*.csv, 처음 5초로 0점 보정
%   R = run_dms_results(folder, calib_s)
%   R = run_dms_results([], 5, 'build/dms_c')   RPi5 프로그램 로그(같은 파일명)와 매 스텝 비교(M3)
%       Pi(또는 WSL)에서: ./des_main --csv IMG_xxxx.csv --fast --quiet --calib 5 --log IMG_xxxx.csv
%
%   촬영 프로토콜의 "세션 시작 5초 정면 주시" 규칙을 0점 보정에 쓴다.
%   열: 길이, valid 비율, 보정값, 가장 긴 비주시 구간, 고정 판정 시간, 모델별 첫 EOR / 최고 단계

here = fileparts(fileparts(mfilename('fullpath')));   % supervisor/ (scripts/의 한 단계 위)
addpath(fullfile(here, 'src'));
if nargin < 1 || isempty(folder), folder = fullfile(fileparts(here), 'dms_results'); end
if nargin < 2, calib_s = 5; end
if nargin < 3, c_log_dir = ''; end

files = dir(fullfile(folder, '*.csv'));
files = files(~strcmpi({files.name}, 'scenario_map.csv'));   % DMS 출력 CSV만
P = des_params(3);
stage = {'정상', 'EOR', '강화EOR', 'DCA', '운전불가'};
R = struct([]);

fprintf('\n%-10s %5s %5s %6s %6s %6s %5s |', '파일', '길이', 'valid', 'yaw0', 'pitch0', '최장이탈', '고정');
for m = 0:3, fprintf(' %-15s', sprintf('M%d 첫EOR/최고', m)); end
fprintf('\n');

for k = 1:numel(files)
    f = fullfile(files(k).folder, files(k).name);
    D = dms_load_csv(f, calib_s);
    U = des_resample(D.ts, D.valid, D.yaw, D.pitch, P);

    r.file   = erase(files(k).name, '.csv');
    r.dur    = D.ts(end);
    r.valid  = mean(D.valid);
    r.yaw0   = D.yaw0;
    r.pitch0 = D.pitch0;
    r.first_eor = nan(1, 4);
    r.max_esc   = zeros(1, 4);
    for m = 1:3
        L = sim_system(U, m);
        if m == 1
            r.longest_off = longest_run(~L.gaze_on) * P.dt;
            r.frozen_s    = nnz(L.frozen) * P.dt;
            [r.first_eor(1), r.max_esc(1)] = summarize(L, 1);
        end
        [r.first_eor(m + 1), r.max_esc(m + 1)] = summarize(L, 2);
    end
    r.c_match = '';                                % 마지막 L = sim_system(U, 3): Pi 빌드와 같은 구성
    if ~isempty(c_log_dir)
        cf = fullfile(c_log_dir, files(k).name);
        if exist(cf, 'file')
            [ok, msg] = b2b_compare(L, read_c_log(cf));
            r.c_match = msg;
            if ~ok, r.c_match = ['C 불일치: ' msg]; end
        else
            r.c_match = 'C 로그 없음';
        end
    end
    R = [R; r]; %#ok<AGROW>

    fprintf('%-10s %5.1f %5.2f %6.1f %6.1f %6.2f %5.1f |', r.file, r.dur, r.valid, ...
            r.yaw0, r.pitch0, r.longest_off, r.frozen_s);
    for m = 1:4
        if isnan(r.first_eor(m))
            s = '-';
        else
            s = sprintf('%.2f/%s', r.first_eor(m), stage{r.max_esc(m) + 1});
        end
        fprintf(' %-15s', s);
    end
    fprintf(' %s\n', r.c_match);
end
end

function L = read_c_log(f)
M = readmatrix(f, 'NumHeaderLines', 1);
L.t       = M(:, 1) * 0.01;
L.gaze_on = M(:, 8) > 0.5;
L.frozen  = M(:, 9) > 0.5;
L.esc     = uint8(M(:, [10 13]));
L.dis     = M(:, [11 14]) > 0.5;
L.metric  = M(:, [12 15]);
end

function [t, mx] = summarize(L, c)
i = find(L.esc(:, c) >= 1, 1);
if isempty(i), t = NaN; else, t = L.t(i); end
mx = double(max(L.esc(:, c)));
end

function n = longest_run(x)
d = diff([0; x(:); 0]);
s = find(d == 1); e = find(d == -1);
if isempty(s), n = 0; else, n = max(e - s); end
end
