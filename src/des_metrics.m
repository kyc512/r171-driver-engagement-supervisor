function M = des_metrics(L)
%DES_METRICS  시뮬레이션 로그 요약
%   n_eor          : EOR 진입 횟수 (ENGAGED -> EOR 전이)
%   t_first_eor    : 첫 EOR 시각 [s] (없으면 NaN)
%   max_esc        : 도달한 최고 단계 (0~4)
%   off_frac       : 전체 시간 중 이탈 비율
%   off_frac_quiet : 경고가 없던(ENGAGED) 시간 중 이탈 비율 = "경고 없이 안 본 비율"

esc = double(L.esc);
enter = [esc(1) == 1; diff(esc) > 0 & esc(2:end) == 1];

M.n_eor       = sum(enter);
M.t_first_eor = NaN;
if any(enter), M.t_first_eor = L.t(find(enter, 1)); end
M.max_esc     = max(esc);
M.off_frac    = mean(~L.gaze_on);
quiet         = esc == 0;
M.off_frac_quiet = sum(~L.gaze_on & quiet) / numel(esc);
end
