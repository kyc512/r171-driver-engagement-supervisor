function run_b2b_c(mode)
%RUN_B2B_C  back-to-back 검증: MATLAB 기준(sim_system) vs 생성 C 코드 실행 프로그램(des_main)
%   run_b2b_c          % 입력 CSV 생성 -> 노트북(MSVC)에서 des_main 빌드·실행 -> 비교
%   run_b2b_c('pi')    % build/b2b/pi/out_*.csv (RPi5에서 돌린 로그)를 비교
%
%   RPi5 절차 (deploy/README.md):
%     1) run_b2b_c 를 한 번 실행해 build/b2b/in_*.csv 생성
%     2) in_*.csv와 deploy/rpi/b2b_pi.sh 를 Pi로 복사해 실행 -> out_*.csv
%     3) out_*.csv를 build/b2b/pi/ 로 가져와 run_b2b_c('pi')
%
%   C 프로그램은 CSV를 직접 읽어 100 Hz로 리샘플(ZOH)하므로, 리샘플 규칙(des_resample.m)까지 대조된다.

if nargin < 1, mode = 'host'; end
here = fileparts(fileparts(mfilename('fullpath')));   % supervisor/ (scripts/의 한 단계 위)
addpath(fullfile(here, 'src'));
sel = 3;
dir_b2b = fullfile(here, 'build', 'b2b');
if ~exist(dir_b2b, 'dir'), mkdir(dir_b2b); end

% ---------------- 시나리오 -> 입력 CSV + 기준 결과 ----------------
[Us, names] = b2b_scenarios();
P = des_params(sel);
G = cell(1, numel(Us) + 1);
for s = 1:numel(Us)
    U = Us{s};
    n = numel(U.valid);
    write_dms_csv(fullfile(dir_b2b, sprintf('in_%02d.csv', s)), (0:n-1)' * P.dt, ...
        U.valid, U.yaw, U.pitch, U.action, U.reset);
    G{s} = sim_system(U, sel);
end
% 실제 DMS처럼 불규칙한 30 fps + 프레임 끊김 -> C의 리샘플까지 검증
[ts, v, yaw, pitch] = raw_dms_like(P);
s = numel(Us) + 1;
names{s} = 'raw 30fps + gaps';
write_dms_csv(fullfile(dir_b2b, sprintf('in_%02d.csv', s)), ts, v, yaw, pitch, false(size(ts)), []);
G{s} = sim_system(des_resample(ts, v, yaw, pitch, P), sel);

% ---------------- 실행 ----------------
switch mode
    case 'host'
        exe = build_host(here, dir_b2b);
        out_dir = dir_b2b;
        for s = 1:numel(G)
            cmd = sprintf('"%s" --csv "%s" --fast --log "%s"', exe, ...
                fullfile(dir_b2b, sprintf('in_%02d.csv', s)), fullfile(out_dir, sprintf('out_%02d.csv', s)));
            [st, txt] = system(cmd);
            if st ~= 0, error('des_main 실행 실패 (%s):\n%s', names{s}, txt); end
        end
    case 'pi'
        out_dir = fullfile(dir_b2b, 'pi');
    otherwise
        error('mode: host | pi');
end

% ---------------- 비교 ----------------
n_fail = 0; n_steps = 0;
fprintf('\n[%s] %-22s %7s  %s\n', mode, '시나리오', '스텝', '결과');
for s = 1:numel(G)
    f = fullfile(out_dir, sprintf('out_%02d.csv', s));
    if ~exist(f, 'file')
        fprintf('       %-22s %7s  로그 없음 (%s)\n', names{s}, '-', f); n_fail = n_fail + 1; continue
    end
    Lc = read_log(f);
    [ok, msg] = b2b_compare(G{s}, Lc);
    n_fail = n_fail + ~ok; n_steps = n_steps + numel(G{s}.t);
    fprintf('       %-22s %7d  %s\n', names{s}, numel(G{s}.t), msg);
end
if n_fail == 0
    fprintf('\n%d개 시나리오, %d 스텝: 모두 일치\n', numel(G), n_steps);
else
    fprintf('\n%d개 시나리오 중 %d개 불일치\n', numel(G), n_fail);
end
end

% =====================================================================
function write_dms_csv(f, ts, valid, yaw, pitch, action, reset)
yaw = yaw(:); pitch = pitch(:);
yaw(~valid) = NaN; pitch(~valid) = NaN;          % 미검출 프레임은 nan (DMS 출력 형식)
fid = fopen(f, 'w');
if isempty(reset)
    fprintf(fid, 'timestamp,valid,yaw,pitch,driver_action\n');
    fprintf(fid, '%.17g,%d,%.17g,%.17g,%d\n', [ts(:) double(valid(:)) yaw pitch double(action(:))]');
else
    fprintf(fid, 'timestamp,valid,yaw,pitch,driver_action,reset\n');
    fprintf(fid, '%.17g,%d,%.17g,%.17g,%d,%d\n', ...
        [ts(:) double(valid(:)) yaw pitch double(action(:)) double(reset(:))]');
end
fclose(fid);
end

function L = read_log(f)
M = readmatrix(f, 'NumHeaderLines', 1);
L.t       = M(:, 1) * 0.01;
L.gaze_on = M(:, 8) > 0.5;
L.frozen  = M(:, 9) > 0.5;
L.esc     = uint8(M(:, [10 13]));
L.dis     = M(:, [11 14]) > 0.5;
L.metric  = M(:, [12 15]);
end

function [ts, v, yaw, pitch] = raw_dms_like(P)
rng(7);
T = 70;
ts = cumsum(1/30 + 0.004 * randn(round(T * 30), 1));
ts = ts(ts > 0);
ts(ts > 20 & ts < 20.5) = [];                    % 0.5 s 프레임 끊김 (통신·처리 지연)
ts(ts > 41 & ts < 41.15) = [];                   % 0.15 s 끊김 (stale 한계 안)
n = numel(ts);
off = mod(ts - 2, 5.1) < 4.8 & ts > 2;            % 4.8 s 이탈 / 0.3 s 주시 반복
yaw = 3 * randn(n, 1); pitch = 2 * randn(n, 1);
yaw(off) = 40 + 5 * randn(nnz(off), 1); pitch(off) = -20 + 3 * randn(nnz(off), 1);
v = rand(n, 1) > 0.03;
yaw(~v) = 0; pitch(~v) = 0;
assert(P.in_stale < 0.5 && P.in_stale > 0.15);
end

function exe = build_host(here, out_dir)
%BUILD_HOST  des_main을 MSVC로 빌드 (Windows 호스트 back-to-back 전용)
cg  = fullfile(here, 'deploy', 'codegen');
rpi = fullfile(here, 'deploy', 'rpi');
mk = fileread(fullfile(cg, 'des_build.mk'));
tok = regexp(mk, 'DES_GEN_SRCS = ([^\n]*)', 'tokens', 'once');
srcs = strsplit(strtrim(tok{1}));
tok = regexp(mk, 'DES_GEN_DEFS = ([^\n]*)', 'tokens', 'once');
defs = strtrim(tok{1});
cc = mex.getCompilerConfigurations('C', 'Selected');
vcvars = fullfile(cc.Location, 'VC', 'Auxiliary', 'Build', 'vcvars64.bat');
assert(exist(vcvars, 'file') == 2, 'vcvars64.bat 없음: %s', vcvars);
exe = fullfile(out_dir, 'des_main_host.exe');
files = [{fullfile(rpi, 'des_main.c'), fullfile(rpi, 'des_app.c')}, fullfile(cg, srcs)];
cmd = sprintf('"%s" >nul && cl /nologo /O2 /utf-8 /W3 %s /I"%s" /I"%s" %s /Fe"%s" /Fo"%s\\\\"', ...
    vcvars, defs, rpi, cg, strjoin(strcat('"', files, '"'), ' '), exe, out_dir);
[st, txt] = system(cmd);
if st ~= 0, error('호스트 빌드 실패:\n%s', txt); end
w = regexp(txt, '[^\n]*warning[^\n]*', 'match');
if ~isempty(w), fprintf('컴파일 경고:\n  %s\n', strjoin(w, '\n  ')); end
end
