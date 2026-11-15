function tests = test_des_basic
%TEST_DES_BASIC  모델 동작 스모크 테스트 (R171 경계값 12케이스는 별도 확장)
%   실행: runtests('tests/test_des_basic.m')
tests = functiontests(localfunctions);
end

function setupOnce(tc)
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'src'));
tc.TestData.dt = 0.01;
end

function test_continuous_off_eor_at_5s_all_models(tc)
% 제약: 연속 이탈 시 모든 모델이 5.00 s 이내에 EOR
g = [true(200, 1); false(1000, 1)];          % 2 s 주시 후 10 s 이탈
for m = 0:3
    M = des_metrics(sim_des(g, des_params(m)));
    tc.verifyLessThanOrEqual(M.t_first_eor - 2.0, 5.0 + 1e-9, sprintf('M%d', m));
end
end

function test_m0_eor_exactly_5s(tc)
g = [true(200, 1); false(1000, 1)];
M = des_metrics(sim_des(g, des_params(0)));
tc.verifyEqual(M.t_first_eor, 7.0, 'AbsTol', 1e-9);
end

function test_m0_glance_190ms_does_not_reset(tc)
% 3 s 이탈 -> 0.19 s 주시 -> 이탈: 타이머 리셋 안 됨
g = [false(300, 1); true(19, 1); false(500, 1)];
P = des_params(0);
M = des_metrics(sim_des(g, P));
tc.verifyEqual(M.t_first_eor, 5.19, 'AbsTol', 1e-9);   % 정지: 이탈시간 합 5.00 s
P.count_glance_time = true;
M = des_metrics(sim_des(g, P));
tc.verifyEqual(M.t_first_eor, 5.0, 'AbsTol', 1e-9);    % 계속: 경과시간 5.00 s
end

function test_m0_no_false_eor_on_return_at_4_9s(tc)
% 4.9 s 이탈 후 복귀: 재관여 확인(200 ms) 중에 가짜 EOR이 뜨면 안 됨
g = [false(490, 1); true(300, 1)];
tc.verifyEqual(des_metrics(sim_des(g, des_params(0))).n_eor, 0);
end

function test_m0_glance_200ms_resets(tc)
% 3 s 이탈 -> 0.20 s 주시 -> 4.9 s 이탈: 경고 없음
g = [false(300, 1); true(20, 1); false(490, 1); true(100, 1)];
M = des_metrics(sim_des(g, des_params(0)));
tc.verifyEqual(M.n_eor, 0);
end

function test_evasion_48_03(tc)
% 4.8 s / 0.3 s 반복: M0 미탐지, M1~M3 탐지
g = gaze_pattern(4.8, 0.3, 60, tc.TestData.dt, 2.0);
tc.verifyEqual(des_metrics(sim_des(g, des_params(0))).n_eor, 0, 'M0');
for m = 1:3
    tc.verifyGreaterThan(des_metrics(sim_des(g, des_params(m))).n_eor, 0, sprintf('M%d', m));
end
end

function test_normal_like_pattern_no_alarm(tc)
% 1.5 s 이탈 / 4 s 주시 (정상 운전 근사): 어떤 모델도 경고 없음
g = gaze_pattern(1.5, 4.0, 120, tc.TestData.dt, 2.0);
for m = 0:3
    tc.verifyEqual(des_metrics(sim_des(g, des_params(m))).n_eor, 0, sprintf('M%d', m));
end
end

function test_escalation_chain(tc)
% 계속 이탈: EOR(5) -> 강화(8) -> DCA(13) -> UNAVAIL(18)  (R171 01 series 상한)
g = false(2000, 1);
for m = 0:3
    L = sim_des(g, des_params(m));
    first = @(s) L.t(find(L.esc == s, 1));
    tc.verifyEqual([first(1) first(2) first(3) first(4)], [5 8 13 18], 'AbsTol', 1e-9, sprintf('M%d', m));
end
end

% ---- 재EOR (5.5.4.2.6.2.2): 6 s 이탈(EOR) -> 주시 -> 다시 이탈 ----
% M0 재관여는 주시 0.20 s 시점. 주시 on_s초 뒤 이탈 시작 = 재관여 후 (on_s - 0.2) s
function L = reeor_run(tc, on_s, off2_s, P) %#ok<INUSL>
T = @(s) round(s / 0.01);
g = [false(T(6), 1); true(T(on_s), 1); false(T(off2_s), 1); true(T(3), 1)];
L = sim_des(g, P);
end

function n = n_eor_onsets(L)
n = nnz(diff([0; double(L.esc(:) >= 1)]) == 1);
end

function test_reeor_onset_at_2_00s(tc)
% 재관여 후 정확히 2.00 s에 이탈 시작, 1.00 s 지속 -> 즉시 EOR (6 + 2.2 + 1.0 = 9.2 s)
L = reeor_run(tc, 2.2, 1.0, des_params(0));
tc.verifyEqual(n_eor_onsets(L), 2);
i = find(diff([0; double(L.esc(:) >= 1)]) == 1);
tc.verifyEqual(L.t(i(2)), 9.2, 'AbsTol', 1e-9);
tc.verifyEqual(double(L.esc(i(2))), 1);                 % EOR 단계부터 새로 시작
end

function test_reeor_onset_at_2_01s_not_triggered(tc)
% 2.01 s에 시작하면 해당 없음 -> 1.5 s 이탈로는 EOR 없음
L = reeor_run(tc, 2.21, 1.5, des_params(0));
tc.verifyEqual(n_eor_onsets(L), 1);
end

function test_reeor_off_0_99s_not_triggered(tc)
L = reeor_run(tc, 1.0, 0.99, des_params(0));
tc.verifyEqual(n_eor_onsets(L), 1);
L = reeor_run(tc, 1.0, 1.00, des_params(0));
tc.verifyEqual(n_eor_onsets(L), 2);
end

function test_reeor_escalates_from_eor(tc)
% 재EOR 후 계속 이탈: EOR 3 s 뒤 강화 EOR
T = @(s) round(s / 0.01);
g = [false(T(6), 1); true(T(0.5), 1); false(T(10), 1)];
L = sim_des(g, des_params(0));
i = find(diff([0; double(L.esc(:) >= 1)]) == 1);
tc.verifyEqual(L.t(i(2)), 7.5, 'AbsTol', 1e-9);         % 6.5 s 이탈 시작 + 1.0 s
tc.verifyEqual(L.t(find(L.esc == 2, 1)), 10.5, 'AbsTol', 1e-9);
end

function test_reeor_disabled(tc)
P = des_params(0); P.reeor_enable = false;
L = reeor_run(tc, 1.0, 1.5, P);
tc.verifyEqual(n_eor_onsets(L), 1);
end

function test_reeor_all_models_not_later_than_m0(tc)
% 모든 모델이 재EOR 시점에 M0보다 늦지 않음
for on_s = [0.3 1.2 2.0 2.2]
    t0 = reeor_t2(reeor_run(tc, on_s, 1.5, des_params(0)), on_s);
    tc.verifyLessThan(t0, inf);
    for m = 1:3
        tm = reeor_t2(reeor_run(tc, on_s, 1.5, des_params(m)), on_s);
        tc.verifyLessThanOrEqual(tm, t0 + 1e-9, sprintf('M%d on %.1f', m, on_s));
    end
end
end

function t = reeor_t2(L, on_s)
% 두 번째 이탈 시작(6 + on_s) 이후 경고가 켜져 있는 첫 시각 (앞 경고가 이어지는 중이면 그 시각)
i = find(L.t > 6 + on_s + 1e-9 & L.esc(:) >= 1, 1);
if isempty(i), t = inf; else, t = L.t(i); end
end

function test_invalid_gaze_counts_as_off(tc)
g = true(700, 1); v = false(700, 1);
M = des_metrics(sim_des(g, des_params(0), v));
tc.verifyEqual(M.t_first_eor, 5.0, 'AbsTol', 1e-9);
end
