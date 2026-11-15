function [S, out] = des_step(S, gaze_on, gaze_valid, driver_action, reset, P) %#codegen
%DES_STEP  Driver Engagement Supervisor 1 스텝 (dt = P.dt)
%
%   입력
%     gaze_on       : DMS 프레임 판정 gaze_in_relevant_area
%     gaze_valid    : 얼굴/시선 검출 유효 여부 (무효면 이탈로 간주)
%     driver_action : DCA 응답 (예: 버튼/조향 입력)
%     reset         : 시스템 (재)활성화
%   출력 out
%     esc        : 0 ENGAGED | 1 EOR | 2 EOR_ENH | 3 DCA | 4 UNAVAILABLE
%     disengaged : 감지 계층 판정 (escalation 입력)
%     r171_off   : R171 기본 타이머 판정 (모든 모델 공통 하한)
%     metric     : 모델별 내부량 (M0/M1 이탈타이머[s], M2 누적이탈[s], M3 버퍼[s])
%
%   구조:  [감지 계층: 모델별] --disengaged--> [Escalation: 공통]
%   시간은 모두 정수 tick으로 세어 경계값(5.00 s, 0.20 s) 판정이 부동소수 오차에 흔들리지 않게 함.

ST_ENGAGED = uint8(0); ST_EOR = uint8(1); ST_EOR_ENH = uint8(2);
ST_DCA = uint8(3);     ST_UNAVAIL = uint8(4);

if reset
    S = des_init(P);
end

% 1)~2) 감지 계층 (des_detect.m)
[S, disengaged, r171_off, metric] = des_detect(S, gaze_on, gaze_valid, P);

% =====================================================================
% 3) 공통 Escalation:  ENGAGED -> EOR -> EOR_ENH -> DCA -> UNAVAILABLE
% =====================================================================
S.esc_k = S.esc_k + 1;
switch S.esc
    case ST_ENGAGED
        if disengaged
            S.esc = ST_EOR; S.esc_k = 0;
        end
    case ST_EOR
        if ~disengaged
            S.esc = ST_ENGAGED; S.esc_k = 0;
        elseif S.esc_k >= tk(P.T_eor_enh, P.dt)
            S.esc = ST_EOR_ENH; S.esc_k = 0;
        end
    case ST_EOR_ENH
        if ~disengaged
            S.esc = ST_ENGAGED; S.esc_k = 0;
        elseif S.esc_k >= tk(P.T_dca, P.dt)
            S.esc = ST_DCA; S.esc_k = 0;
        end
    case ST_DCA
        if ~disengaged && (driver_action || ~P.dca_requires_action)
            S.esc = ST_ENGAGED; S.esc_k = 0;
        elseif S.esc_k >= tk(P.T_unavail, P.dt)
            S.esc = ST_UNAVAIL; S.esc_k = 0;
        end
    otherwise
        % ST_UNAVAIL: reset 전까지 래치
end

out.esc        = S.esc;
out.disengaged = disengaged;
out.r171_off   = r171_off;
out.metric     = metric;
end

function k = tk(x, dt)
k = round(x / dt);
end
