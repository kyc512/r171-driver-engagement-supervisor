function R = run_random_check(N, T, seed)
%RUN_RANDOM_CHECK  무작위 시퀀스 검증 (중간발표 피드백 ②): 어떤 입력에서도 M1~M3가 M0(R171)보다 늦게 경고하지 않는가
%   R = run_random_check            % 2000개 x 60 s
%   R = run_random_check(N, T, seed)
%
%   입력: 이탈/주시 구간을 번갈아 무작위로 만든다. 경계(5 s 이탈, 0.2 s 주시, 재EOR 2 s/1 s) 근처 길이를
%         일부러 많이 섞고, 미검출(valid=0)과 운전자 응답(driver_action) 펄스도 넣는다.
%   매 스텝 확인 (m = 1~3):
%     (a) 이탈 판정 포함:  disengaged_M0 => disengaged_Mm
%     (b) 경고 단계:       esc_Mm >= esc_M0
%     (c) 경고 시점:       M0가 EOR에 들어가는 모든 순간에 Mm도 EOR 이상
%   (c)가 피드백 ②의 직접적인 답이고, (a)(b)는 그보다 강한 조건이다.

if nargin < 1, N = 2000; end
if nargin < 2, T = 60; end
if nargin < 3, seed = 1; end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'src'));

rng(seed);
P = arrayfun(@(m) des_params(m), 0:3);
dt = P(1).dt; n = round(T / dt);
viol = zeros(3, 3);                % 모델 x (a, b, c) 위반한 시퀀스 수
n_m0_eor = 0; n_steps = 0;
first = cell(3, 3);                % 첫 위반 예 (seed 재현용 index)

tic;
for k = 1:N
    [g, v, a] = random_seq(n, dt);
    L0 = sim_des(g, P(1), v, a);
    on0 = [L0.esc(1) >= 1; diff(double(L0.esc)) > 0 & L0.esc(2:end) == 1];
    n_m0_eor = n_m0_eor + nnz(on0);
    n_steps = n_steps + n;
    for m = 1:3
        Lm = sim_des(g, P(m + 1), v, a);
        bad = [any(L0.disengaged & ~Lm.disengaged), ...
               any(Lm.esc < L0.esc), ...
               any(on0 & Lm.esc < 1)];
        for c = find(bad)
            viol(m, c) = viol(m, c) + 1;
            if isempty(first{m, c}), first{m, c} = k; end
        end
    end
end
el = toc;

fprintf('\n무작위 시퀀스 %d개 x %g s (seed %d), 총 %d 스텝/모델, M0 EOR %d회, %.0f s\n', ...
        N, T, seed, n_steps, n_m0_eor, el);
fprintf('%-4s | %-22s | %-18s | %-24s\n', '모델', '(a) 이탈 판정 포함', '(b) 단계 >= M0', '(c) M0 EOR 순간에 EOR 이상');
for m = 1:3
    fprintf('M%-3d | %22s | %18s | %24s\n', m, cnt(viol(m, 1), first{m, 1}), ...
            cnt(viol(m, 2), first{m, 2}), cnt(viol(m, 3), first{m, 3}));
end
R = struct('N', N, 'T', T, 'seed', seed, 'viol', viol, 'n_m0_eor', n_m0_eor, 'first', {first});
end

function s = cnt(x, k)
if x == 0, s = '위반 0'; else, s = sprintf('위반 %d (첫 #%d)', x, k); end
end

function [g, v, a] = random_seq(n, dt)
% 이탈/주시 구간 교대. 길이 [s]는 경계 근처를 많이 섞은 혼합 분포
g = false(n, 1); v = true(n, 1); a = false(n, 1);
i = 1; on = rand < 0.5;
while i <= n
    if on
        r = rand;
        if r < 0.35,     d = 0.01 + 0.39 * rand;      % 0.2 s 리셋 경계 근처
        elseif r < 0.65, d = 0.4 + 1.6 * rand;        % 1.0 s (M1·M2·M3 해제) 근처
        elseif r < 0.85, d = 1.8 + 0.6 * rand;        % 재EOR 창 2 s 근처 (재관여 0.2 s 포함)
        else,            d = 2.4 + 4 * rand;
        end
    else
        r = rand;
        if r < 0.30,     d = 0.01 + 1.5 * rand;
        elseif r < 0.50, d = 0.8 + 0.4 * rand;        % 재EOR 1 s 근처
        elseif r < 0.80, d = 4.5 + 1.0 * rand;        % 5 s EOR 경계 근처
        else,            d = 1.5 + 12 * rand;         % 단계 진행까지
        end
    end
    k = max(1, round(d / dt));
    j = min(n, i + k - 1);
    g(i:j) = on;
    if ~on && rand < 0.15, v(i:j) = false; end        % 이탈 대신 미검출
    if on && rand < 0.10                               % 주시 중 짧은 미검출 튐
        b = i + floor(rand * (j - i + 1)); v(b:min(j, b + randi(3) - 1)) = false;
    end
    if on && rand < 0.3, a(i + floor(rand * (j - i + 1))) = true; end   % 운전자 응답 펄스
    i = j + 1; on = ~on;
end
end
