function L = sim_system(U, sel_model)
%SIM_SYSTEM  시스템 전체의 MATLAB 기준 동작 (golden): 입력 단계 -> [M0 채널, 선택 모델 채널]
%   L = sim_system(U, sel_model)
%   U: 100 Hz 스텝 입력 (des_resample 출력 형식: valid, yaw, pitch, action, reset)
%
%   Simulink 모델(model/des_supervisor.slx)과 RPi5 실행 프로그램이 매 스텝 이 결과와 같아야 한다.
%   채널마다 P.fz_enable이면 고정 탐지 결과를 valid에 반영 (M0는 R171 타이머 기준선이라 미적용).

if nargin < 2, sel_model = 3; end
n  = numel(U.valid);
Pi = des_params(sel_model);              % 입력 단계 파라미터 (모델 공통)
Pc = {des_params(0), des_params(sel_model)};

SI = des_input_init(Pi);
S  = {des_init(Pc{1}), des_init(Pc{2})};

L.t       = (1:n)' * Pi.dt;
L.gaze_on = false(n, 1);
L.frozen  = false(n, 1);
L.esc     = zeros(n, 2, 'uint8');
L.dis     = false(n, 2);
L.metric  = zeros(n, 2);

for i = 1:n
    if U.reset(i)
        SI = des_input_init(Pi);
    end
    [SI, g, f] = des_input_step(SI, U.valid(i), U.yaw(i), U.pitch(i), Pi);
    L.gaze_on(i) = g;
    L.frozen(i)  = f;
    for c = 1:2
        v = U.valid(i) && ~(Pc{c}.fz_enable && f);
        [S{c}, o] = des_step(S{c}, g, v, U.action(i), U.reset(i), Pc{c});
        L.esc(i, c)    = o.esc;
        L.dis(i, c)    = o.disengaged;
        L.metric(i, c) = o.metric;
    end
end
L.sel_model = sel_model;
end
