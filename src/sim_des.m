function L = sim_des(gaze_on, P, gaze_valid, driver_action)
%SIM_DES  시선 시퀀스를 supervisor에 통과시켜 로그 반환
%   L = sim_des(gaze_on, P)                 % gaze_valid = true, driver_action = false
%   L = sim_des(gaze_on, P, gaze_valid, driver_action)
%
%   gaze_on(i)는 구간 [(i-1)dt, i*dt) 의 판정. L.t(i) = i*dt (스텝 종료 시각)

n = numel(gaze_on);
if nargin < 3 || isempty(gaze_valid),    gaze_valid = true(n, 1);     end
if nargin < 4 || isempty(driver_action), driver_action = false(n, 1); end

S = des_init(P);
L.t          = (1:n)' * P.dt;
L.gaze_on    = logical(gaze_on(:));
L.esc        = zeros(n, 1, 'uint8');
L.disengaged = false(n, 1);
L.r171_off   = false(n, 1);
L.metric     = zeros(n, 1);

for i = 1:n
    [S, o] = des_step(S, gaze_on(i), gaze_valid(i), driver_action(i), false, P);
    L.esc(i)        = o.esc;
    L.disengaged(i) = o.disengaged;
    L.r171_off(i)   = o.r171_off;
    L.metric(i)     = o.metric;
end
L.P = P;
end
