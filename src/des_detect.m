function [S, disengaged, r171_off, metric] = des_detect(S, gaze_on, gaze_valid, P) %#codegen
%DES_DETECT  감지 계층 1 스텝: R171 기본 타이머 + 모델별 판정 -> disengaged
%   des_step에서 분리. Simulink 모델의 감지 블록(MATLAB Function)도 이 함수를 그대로 호출하고,
%   Escalation은 Stateflow 차트로 따로 구현해 back-to-back으로 대조한다.
%   S의 감지 관련 필드(on_k, dis_k, rw_k, rw_hit, dis_prev, latched, hist, hist_idx, cum_k, buf)만 갱신한다.

EPS = 1e-9;

on = gaze_on && gaze_valid;

% =====================================================================
% 1) R171 기본 타이머 (모든 모델 공통)
%    - 이탈 중 증가, T_re 이상 연속 주시하면 리셋
%    - T_re 미만의 짧은 주시 동안: P.count_glance_time 에 따라
%        false(기본) 타이머 정지 -> 이탈 '시간'만 셈. 4.9 s 이탈 후 복귀 시 가짜 EOR 없음
%        true        타이머 계속 -> "짧은 주시는 재관여가 아니다"의 가장 보수적 해석
%    - M1만 T_re를 늘림. M2/M3는 R171 값(0.2 s)을 그대로 써서 하한 보장용으로 사용
% =====================================================================
if P.model == 1
    k_re = tk(P.m1_T_reengage, P.dt);
else
    k_re = tk(P.T_reengage, P.dt);
end

if on
    S.on_k = S.on_k + 1;
    if S.on_k >= k_re
        S.dis_k = 0;
    elseif S.dis_k > 0 && P.count_glance_time
        S.dis_k = S.dis_k + 1;
    end
else
    S.on_k  = 0;
    S.dis_k = S.dis_k + 1;
end

% 1b) 재EOR (R171 01 series 5.5.4.2.6.2.2)
%    disengaged가 해제된 순간(재관여)부터 rw_k를 센다. rw_k <= T_win 인 스텝에 이탈이 시작되고
%    (dis_k 0 -> 1) 그 이탈이 T_off에 도달하면 이탈 타이머를 T_eor로 올려 즉시 EOR.
%    이후 래치·해제는 기존 경로 그대로라 모든 모델이 같은 방식으로 반응한다.
if P.reeor_enable && S.rw_k >= 0
    if S.dis_k == 1 && S.rw_k <= tk(P.reeor_T_win, P.dt)
        S.rw_hit = true;
    end
    if S.rw_hit && S.dis_k >= tk(P.reeor_T_off, P.dt)
        S.dis_k  = max(S.dis_k, tk(P.T_eor, P.dt));
        S.rw_k   = -1;
        S.rw_hit = false;
    else
        if S.dis_k == 0
            S.rw_hit = false;               % T_off 전에 다시 재관여: 그 이탈은 해당 없음
        end
        S.rw_k = S.rw_k + 1;
        if ~S.rw_hit && S.rw_k > tk(P.reeor_T_win, P.dt)
            S.rw_k = -1;                    % 창 종료
        end
    end
end
r171_off = S.dis_k >= tk(P.T_eor, P.dt);

% =====================================================================
% 2) 감지 계층 (모델별)
% =====================================================================
switch P.model
    case {0, 1}
        % M0: R171 시간 조항만 (타이머 기준선) / M1: 재관여 인정 시간만 강화
        disengaged = r171_off;
        metric = S.dis_k * P.dt;

    case 2
        % M2: 최근 W초 누적 이탈 시간
        N = tk(P.m2_W, P.dt);
        old = S.hist(S.hist_idx);
        S.cum_k = S.cum_k - double(old) + double(~on);
        S.hist(S.hist_idx) = ~on;
        S.hist_idx = S.hist_idx + 1;
        if S.hist_idx > N
            S.hist_idx = 1;
        end

        if r171_off || S.cum_k >= tk(P.m2_T_cum, P.dt)
            S.latched = true;
        end
        % 해제: 충분히 길게 연속 주시 -> 윈도우 초기화
        % (윈도우가 자연히 빠지기를 기다리면 전방을 보는 중에도 escalation이 진행될 수 있음)
        if S.latched && ~r171_off && S.on_k >= tk(P.m2_T_clear, P.dt)
            S.latched  = false;
            S.hist(:)  = false;
            S.hist_idx = 1;
            S.cum_k    = 0;
        end
        disengaged = S.latched;
        metric = S.cum_k * P.dt;

    otherwise
        % M3: 주의 버퍼 (AttenD형) - 이탈 시 소모, 주시 시 (지연 후) 회복
        if on
            if S.on_k > tk(P.m3_T_latency, P.dt)
                S.buf = min(P.m3_B_max, S.buf + P.m3_r_rec * P.dt);
            end
        else
            S.buf = max(0, S.buf - P.m3_r_dec * P.dt);
        end

        if r171_off || S.buf <= EPS
            S.latched = true;
        end
        if S.latched && ~r171_off && S.buf >= P.m3_B_clear - EPS ...
                && S.on_k >= tk(P.T_reengage, P.dt)
            S.latched = false;
        end
        disengaged = S.latched;
        metric = S.buf;
end

% 재관여 순간(이번 스텝에 disengaged 해제)이면 재EOR 감시 시작
if S.dis_prev && ~disengaged
    S.rw_k   = 0;
    S.rw_hit = false;
end
S.dis_prev = disengaged;

end

function k = tk(x, dt)
k = round(x / dt);
end
