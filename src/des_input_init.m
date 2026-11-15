function SI = des_input_init(P) %#codegen
%DES_INPUT_INIT  입력 단계 상태 초기화 (고정 탐지용 원형 버퍼)

SI.yb  = zeros(P.FZ_MAX_N, 1);   % 최근 yaw [deg]
SI.pb  = zeros(P.FZ_MAX_N, 1);   % 최근 pitch [deg]
SI.idx = 1;                      % 다음에 쓸 위치
SI.cnt = 0;                      % 연속 valid 샘플 수 (창 길이에서 포화)
end
