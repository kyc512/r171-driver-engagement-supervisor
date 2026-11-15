function g = gaze_pattern(off_s, on_s, T_total, dt, t_lead)
%GAZE_PATTERN  주기적 이탈/복귀 패턴 (회피 격자용)
%   g = gaze_pattern(4.8, 0.3, 60, 0.01)       % 4.8 s 이탈 -> 0.3 s 전방 반복
%   g = gaze_pattern(off_s, on_s, T_total, dt, t_lead)
%       t_lead : 시작 전 전방 주시 구간 [s] (기본 0)
%   true = 전방(relevant area) 주시

if nargin < 5, t_lead = 0; end
n     = round(T_total / dt);
k_off = round(off_s / dt);
k_on  = round(on_s / dt);
k_ld  = round(t_lead / dt);

cyc = [false(k_off, 1); true(k_on, 1)];
g = [true(k_ld, 1); repmat(cyc, ceil(max(n - k_ld, 0) / numel(cyc)), 1)];
g = g(1:n);
end
