function tests = test_input_stage
%TEST_INPUT_STAGE  입력 단계(주시 영역, 고정 탐지, 리샘플)와 시스템 조립(sim_system) 테스트
tests = functiontests(localfunctions);
end

function setupOnce(tc)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'src'));
tc.TestData.P = des_params(3);
end

function test_aoi(tc)
P = tc.TestData.P; SI = des_input_init(P);
[SI, g] = des_input_step(SI, true, P.aoi_yaw, 0, P);         tc.verifyTrue(g);    % 경계 포함
[SI, g] = des_input_step(SI, true, P.aoi_yaw + 0.01, 0, P);  tc.verifyFalse(g);
[SI, g] = des_input_step(SI, true, 0, -P.aoi_pitch - 0.01, P); tc.verifyFalse(g);
[~,  g] = des_input_step(SI, false, 0, 0, P);                tc.verifyFalse(g);   % 미검출
end

function test_freeze_after_window(tc)
P = tc.TestData.P; SI = des_input_init(P);
N = round(P.fz_W / P.dt);
f = false(N, 1);
for i = 1:N
    [SI, ~, f(i)] = des_input_step(SI, true, 0.1 * sin(i), 0, P);
end
tc.verifyFalse(any(f(1:N-1)), '창이 다 차기 전에는 고정 판정 없음');
tc.verifyTrue(f(N));
end

function test_no_freeze_when_moving(tc)
P = tc.TestData.P; SI = des_input_init(P);
rng(1); f = false;
for i = 1:3 * round(P.fz_W / P.dt)
    [SI, ~, fi] = des_input_step(SI, true, 3 * randn, 2 * randn, P); f = f || fi;
end
tc.verifyFalse(f);
end

function test_freeze_reset_by_invalid(tc)
P = tc.TestData.P; SI = des_input_init(P);
N = round(P.fz_W / P.dt); f = false;
for i = 1:2 * N
    v = i ~= N;                                   % 창이 거의 찼을 때 한 프레임 미검출
    [SI, ~, fi] = des_input_step(SI, v, 0, 0, P);
    if i < 2 * N, f = f || fi; end
end
tc.verifyFalse(f, '미검출 이후 창을 처음부터 다시 채워야 함');
tc.verifyTrue(fi);
end

function test_resample_zoh_and_stale(tc)
P = tc.TestData.P;
ts = [0.05; 0.10; 0.50];                          % 0.10 이후 0.4 s 끊김
U = des_resample(ts, true(3, 1), [1; 2; 3], [0; 0; 0], P);
tc.verifyEqual(numel(U.valid), 51);
tc.verifyFalse(any(U.valid(1:5)), '첫 프레임 전');
tc.verifyEqual(U.yaw(6), 1);                      % t_s = 0.05
tc.verifyEqual(U.yaw(11), 2);                     % t_s = 0.10
k_last_ok = 11 + round(P.in_stale / P.dt);
tc.verifyTrue(U.valid(k_last_ok));                % 0.20 s 지난 프레임까지는 유효
tc.verifyFalse(U.valid(k_last_ok + 1));           % 그 이후는 통신 끊김 = 이탈
tc.verifyTrue(U.valid(51));
end

function test_photo_m0_silent_selected_alarms(tc)
% 사진(고정): M0는 R171 그대로라 속고, 선택 모델은 고정 탐지로 경고
n = 4000;
U.valid = true(n, 1); U.yaw = 0.1 * sin((1:n)' * 0.05); U.pitch = zeros(n, 1);
U.action = false(n, 1); U.reset = false(n, 1);
L = sim_system(U, 3);
tc.verifyEqual(max(L.esc(:, 1)), uint8(0));
tc.verifyGreaterThan(max(L.esc(:, 2)), uint8(0));
end

function test_system_m0_matches_r171_core(tc)
% sim_system의 M0 채널은 고정 탐지가 없으므로 sim_des(M0)과 같아야 함
P = des_params(0);
g = gaze_pattern(4.8, 0.3, 60, P.dt, 2.0);
n = numel(g);
U.valid = true(n, 1); U.yaw = 40 * double(~g); U.pitch = zeros(n, 1);
U.action = false(n, 1); U.reset = false(n, 1);
L = sim_system(U, 3);
L0 = sim_des(g, P);
tc.verifyEqual(L.esc(:, 1), L0.esc);
end
