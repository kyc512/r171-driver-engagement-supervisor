function S = des_init(P) %#codegen
%DES_INIT  Supervisor 내부 상태 초기화 (시스템 활성화 시점 = 관여 상태로 시작)

% R171 기본 타이머 (모든 모델 공통)
S.on_k  = 0;            % 연속 주시 tick
S.dis_k = 0;            % 이탈 타이머 tick (재관여 시 0으로 리셋)
S.rw_k   = -1;          % 재EOR 감시: 재관여 후 경과 tick (-1 = 감시 안 함)
S.rw_hit = false;       % 재EOR 감시: 창 안에서 시작된 이탈이 진행 중
S.dis_prev = false;     % 직전 스텝 disengaged (해제 순간 = 재관여 감지용)

% 모델별 감지 상태
S.latched  = false;     % M2/M3 이탈 판정 래치
S.hist     = false(P.M2_MAX_N, 1);  % M2 원형 버퍼 (true = 이탈)
S.hist_idx = 1;
S.cum_k    = 0;         % M2 윈도우 내 누적 이탈 tick
S.buf      = P.m3_B_max;% M3 주의 버퍼 [s]

% 공통 Escalation
S.esc   = uint8(0);     % 0 ENGAGED, 1 EOR, 2 EOR_ENH, 3 DCA, 4 UNAVAILABLE
S.esc_k = 0;            % 현재 단계 체류 tick
end
