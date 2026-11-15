function [ok, msg] = b2b_compare(Lg, Lx, tol)
%B2B_COMPARE  기준 로그 Lg와 대상 로그 Lx를 매 스텝 비교 (sim_system 형식)
%   [ok, msg] = b2b_compare(Lg, Lx)    tol: metric 허용 오차 (기본 1e-12)
%   msg에는 첫 불일치 스텝과 신호 이름이 들어간다.

if nargin < 3, tol = 1e-12; end
ok = true; msg = '일치';
if numel(Lg.t) ~= numel(Lx.t)
    ok = false; msg = sprintf('길이 다름 (%d vs %d)', numel(Lg.t), numel(Lx.t)); return
end
chk = {'esc', 'dis', 'gaze_on', 'frozen'};
first = inf; what = '';
for k = 1:numel(chk)
    d = find(any(Lg.(chk{k}) ~= Lx.(chk{k}), 2), 1);
    if ~isempty(d) && d < first, first = d; what = chk{k}; end
end
d = find(any(abs(Lg.metric - Lx.metric) > tol, 2), 1);
if ~isempty(d) && d < first, first = d; what = 'metric'; end
if isfinite(first)
    ok = false;
    msg = sprintf('불일치: 스텝 %d (t=%.2f s) %s  기준 esc=[%d %d] 대상 esc=[%d %d]', ...
        first, Lg.t(first), what, Lg.esc(first, :), Lx.esc(first, :));
end
end
