function P = des_params(model)
%DES_PARAMS  Driver Engagement Supervisor 파라미터 (시간 단위: 초)
%   P = des_params(model)   model = 0(M0) | 1(M1) | 2(M2) | 3(M3)
%
%   모든 모델 공통: R171 기본 타이머(연속 이탈 T_eor, 재관여 T_reengage)는
%   항상 같이 돌아가며, 모델별 감지 결과와 OR 된다.
%   -> 연속 이탈에 대해 어떤 모델도 R171보다 늦게 경고하지 않음 (구조적 보장)

if nargin < 1, model = 0; end
P.model = model;
P.dt    = 0.01;            % 스텝 주기 [s] (100 Hz). DMS 프레임은 ZOH로 들어온다고 가정

% ---- R171 공통 ----
P.T_eor      = 5.0;        % 연속 이탈 -> EOR
P.T_reengage = 0.2;        % 이 시간 이상 연속 주시 -> 재관여
P.count_glance_time = false;  % T_reengage 미만 짧은 주시 동안 이탈 타이머를 계속 셀지
                              % (false: 정지 / true: 계속 = 최보수 해석). 경계값 테스트에서 확정

% ---- R171 01 series 5.5.4.2.6.2.2: EOR 이후 재관여 -> 곧 다시 이탈하면 즉시 EOR ----
% 해석 (2026-11-12 팀 결정): 재관여 후 reeor_T_win 안에 이탈이 '시작'되고
% 그 이탈이 reeor_T_off 지속되면 그 시점에 EOR (EOR 단계부터 새로 시작).
% 재관여 = 해당 모델의 disengaged 해제. 구현은 R171 공통 타이머라 모든 모델에 적용된다.
P.reeor_enable = true;
P.reeor_T_win  = 2.0;      % 재관여 후 이 시간 안(경계 포함)에 이탈이 시작되면
P.reeor_T_off  = 1.0;      % 그 이탈이 이 시간 지속되면 즉시 EOR

% ---- 공통 Escalation: 각 단계 '체류' 시간 (R171 01 series 상한, 이탈 시작부터 5/8/13/18 s) ----
P.T_eor_enh  = 3.0;        % EOR      -> 강화 EOR  (5.5.4.2.6.2.3: 첫 EOR 후 3 s 이내)
P.T_dca      = 5.0;        % 강화 EOR -> DCA       (5.5.4.2.6.3.1: 강화 EOR 후 5 s 이내)
P.T_unavail  = 5.0;        % DCA      -> 운전불가  (5.5.4.2.6.4.1: 첫 강화 요청 후 10 s 이내
                           %                         -> T_dca + T_unavail <= 10 을 지킬 것)
P.dca_requires_action = true;  % DCA 해제에 driver_action 입력 필요 여부

% ---- M1: 재관여 인정 시간 강화 ----
P.m1_T_reengage = 1.0;     % 200ms 대신 이 시간 연속 주시해야 타이머 리셋

% ---- M2: 최근 W초 누적 이탈 (Euro NCAP Driver Engagement v1.2 §1.2.2 VATS: 30초 중 누적 10초) ----
% 11/12 변경: 이전 값은 20 s / 12 s (임의 설정)
P.m2_W       = 30.0;       % 슬라이딩 윈도우 길이
P.m2_T_cum   = 10.0;       % 윈도우 내 누적 이탈 >= 이 값 -> 이탈 판정 (33%)
P.m2_T_clear = 1.0;        % 경고 해제: 이 시간 연속 주시 (해제 시 윈도우 초기화)

% ---- M3: 주의 버퍼 (AttenD형) ----
P.m3_B_max     = 5.0;      % 버퍼 최대 [s]. <= T_eor 이면 연속 이탈 시 5초 안에 0 도달
P.m3_r_dec     = 1.0;      % 이탈 중 소모율 [s/s]
P.m3_r_rec     = 1.0;      % 주시 중 회복율 [s/s]
P.m3_T_latency = 0.1;      % 주시 시작 후 회복 시작까지 지연
P.m3_B_clear   = 1.0;      % 경고 해제: 버퍼가 이 값 이상 회복

% ---- 입력 단계: DMS 각도 -> gaze_on, 고정(freeze) 탐지 ----
% aoi_*: 팀 확정값 (2026-11-12). 처음 5초 0점 보정 후 정면 범위. fz_* 는 아직 임시값.
P.aoi_yaw   = 11.0;        % 주시 영역 |yaw| <= 이 값 [deg] (보정 후 각도 기준)
P.aoi_pitch = 13.0;        % 주시 영역 |pitch| <= 이 값 [deg]
P.in_stale  = 0.2;         % DMS 프레임이 이보다 오래되면 valid = 0 [s] (통신 끊김 = 이탈)
P.fz_enable = model ~= 0;  % M0(R171 타이머 기준선)는 고정 탐지 없음
P.fz_W      = 10.0;        % 고정 판정 창 [s]: 이 시간 연속 valid 동안
P.fz_range  = 1.0;         %   yaw, pitch 모두 (최대-최소) < 이 값 [deg] 이면 고정 -> valid = 0

% ---- 내부 상수 (codegen 고정 크기) ----
P.M2_MAX_N = 6000;         % 윈도우 최대 샘플 수 (= 60 s @ 100 Hz)
P.FZ_MAX_N = 3000;         % 고정 판정 창 최대 샘플 수 (= 30 s @ 100 Hz)
end
