function [Us, names] = b2b_scenarios(seed)
%B2B_SCENARIOS  back-to-back 검증용 100 Hz 입력 시나리오 (valid, yaw, pitch, action, reset)
%   경계값·경고 단계·리셋·DCA 응답·고정(사진)·미검출 + 무작위 시퀀스
%   [Us, names] = b2b_scenarios(seed)

if nargin < 1, seed = 171; end
rng(seed);
dt = 0.01;
Us = {}; names = {};

    function add(name, on, valid, action, reset, fixed_gaze)
        n = numel(on);
        if nargin < 3 || isempty(valid),  valid  = true(n, 1);  end
        if nargin < 4 || isempty(action), action = false(n, 1); end
        if nargin < 5 || isempty(reset),  reset  = false(n, 1); end
        if nargin < 6, fixed_gaze = false; end
        U.valid  = logical(valid(:));
        if fixed_gaze
            U.yaw   = 0.1 * sin((1:n)' * 0.05);            % 거의 안 움직이는 시선 (사진)
            U.pitch = 0.1 * cos((1:n)' * 0.05);
        else
            U.yaw   = 3 * randn(n, 1);                      % 전방 주시: 영역 안에서 흔들림
            U.pitch = 2 * randn(n, 1);
            off = ~on(:);
            U.yaw(off)   = 35 + 10 * rand(nnz(off), 1);     % 이탈: 영역 밖 (휴대폰·옆 창)
            U.pitch(off) = -25 + 5 * randn(nnz(off), 1);
        end
        U.yaw(~U.valid) = 0; U.pitch(~U.valid) = 0;
        U.action = logical(action(:));
        U.reset  = logical(reset(:));
        Us{end+1} = U; names{end+1} = name;
    end

T = @(s) round(s / dt);

% 회피 패턴, 연속 이탈 (경고 단계 끝까지)
add('evasion 4.8/0.3', gaze_pattern(4.8, 0.3, 60, dt, 2.0));
add('continuous off 30s', [true(T(2), 1); false(T(30), 1)]);

% 경계값: 0.19 s / 0.20 s 주시, 4.99 / 5.00 s 이탈, 4.9 s 후 복귀
add('glance 0.19', [false(T(3), 1); true(19, 1); false(T(5), 1); true(T(2), 1)]);
add('glance 0.20', [false(T(3), 1); true(20, 1); false(T(4.9), 1); true(T(2), 1)]);
add('off 4.99',    [true(T(1), 1); false(499, 1); true(T(3), 1)]);
add('off 5.00',    [true(T(1), 1); false(500, 1); true(T(3), 1)]);
add('return 4.9',  [false(T(4.9), 1); true(T(3), 1)]);

% 단계별 해제: EOR / 강화 EOR 중 복귀, DCA는 운전자 응답이 있어야 해제
% 이탈 시작부터 EOR 5 / 강화 8 / DCA 13 / 운전불가 18 s (R171 01 series 상한)
add('release in EOR',     [false(T(6), 1); true(T(3), 1)]);
add('release in EOR_ENH', [false(T(10), 1); true(T(3), 1)]);
on = [false(T(14), 1); true(T(4), 1)]; act = false(size(on)); act(T(16):T(16)+10) = true;
add('DCA + action', on, [], act);
add('DCA no action', [false(T(14), 1); true(T(8), 1)]);

% 재EOR (5.5.4.2.6.2.2): EOR 후 재관여, 2 s 안에 다시 이탈 시작, 1 s 지속 -> 즉시 EOR
% M0 재관여 = 주시 0.20 s. 주시 2.20 s = 재관여 후 2.00 s에 이탈 시작(포함), 2.21 s = 2.01 s(제외)
for on_s = [0.5 2.2 2.21]
    for off_s = [0.99 1.0]
        add(sprintf('reeor on %.2f off %.2f', on_s, off_s), ...
            [false(T(6), 1); true(T(on_s), 1); false(T(off_s), 1); true(T(3), 1)]);
    end
end
% 재EOR 반복 (EOR 뒤 0.5 s 주시 / 3 s 이탈 반복) + 재EOR 후 끝까지 단계 진행
add('reeor repeat', [false(T(6), 1); repmat([true(T(0.5), 1); false(T(3), 1)], 6, 1)]);
add('reeor then escalate', [false(T(6), 1); true(T(0.5), 1); false(T(20), 1)]);

% 운전불가 래치 -> reset
on = [false(T(20), 1); true(T(5), 1)]; rst = false(size(on)); rst(T(22)) = true;
add('unavailable + reset', on, [], [], rst);

% 미검출, 고정(사진)
v = true(T(30), 1); v(T(5):T(12)) = false;
add('invalid 7s', true(T(30), 1), v);
add('frozen photo 40s', true(T(40), 1), [], [], [], true);

% 전이 우선순위: "해제"와 "다음 단계 시간 경과"가 같은 스텝에 겹치는 경계를 1 tick 단위로 훑기
% (이탈 L tick 후 주시, 구간마다 reset으로 독립). EOR->강화 EOR, 강화 EOR->DCA 경계 각각.
on = false(0, 1); rst = false(0, 1);
for L = [T(6.9):T(8.0), T(11.9):T(13.0)]
    seg = [false(L, 1); true(T(2.5), 1)];
    r = false(size(seg)); r(1) = true;
    on = [on; seg]; rst = [rst; r]; %#ok<AGROW>
end
add('tie sweep', on, [], [], rst);

% 무작위: 구간 길이·미검출·응답·리셋 모두 무작위
for r = 1:10
    n = T(90);
    on = false(n, 1); i = 1; state = rand > 0.5;
    while i <= n
        if state, L = T(0.05 + 3 * rand); else, L = T(0.05 + 6.5 * rand); end
        on(i:min(n, i + L - 1)) = state; i = i + L; state = ~state;
    end
    v = rand(n, 1) > 0.02;                        % 프레임 2% 미검출
    act = false(n, 1); act(randi(n, 5, 1)) = true;
    rst = false(n, 1); rst(randi(n, 1, 1)) = true;
    add(sprintf('random %d', r), on, v, act, rst);
end
end
