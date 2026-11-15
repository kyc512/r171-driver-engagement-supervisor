function U = des_resample(ts, valid, yaw, pitch, P, action)
%DES_RESAMPLE  DMS 프레임(불규칙 시각) -> 100 Hz 스텝 입력 (ZOH + 통신 끊김 처리)
%   U = des_resample(ts, valid, yaw, pitch, P)
%   U = des_resample(ts, valid, yaw, pitch, P, action)
%
%   스텝 i (구간 [(i-1)dt, i*dt))의 입력 = 시각 (i-1)dt 이전의 가장 최근 프레임.
%   그 프레임이 P.in_stale보다 오래됐거나 아직 프레임이 없으면 valid = 0.
%   RPi5 실행 프로그램(deploy/rpi/des_main.c)의 CSV 재생과 같은 규칙 -> back-to-back 대상.

ts = ts(:); valid = logical(valid(:)); yaw = yaw(:); pitch = pitch(:);
if nargin < 6 || isempty(action), action = false(size(ts)); end
action = logical(action(:));
TOL = 1e-9;
dt = P.dt;

n = floor(ts(end) / dt + TOL) + 1;
U.valid  = false(n, 1);
U.yaw    = zeros(n, 1);
U.pitch  = zeros(n, 1);
U.action = false(n, 1);
U.reset  = false(n, 1);

j = 0;
for i = 1:n
    t_s = (i - 1) * dt;
    while j < numel(ts) && ts(j + 1) <= t_s + TOL
        j = j + 1;
    end
    if j == 0
        continue
    end
    if valid(j) && (t_s - ts(j)) <= P.in_stale + TOL
        U.valid(i) = true;
        U.yaw(i)   = yaw(j);
        U.pitch(i) = pitch(j);
    end
    U.action(i) = action(j);
end
end
