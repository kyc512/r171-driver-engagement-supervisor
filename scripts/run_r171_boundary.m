function T = run_r171_boundary(out_md)
%RUN_R171_BOUNDARY  R171 01 series 경계값 12케이스: M0가 규정대로 동작하는지 + M1~M3가 M0보다 늦지 않은지
%   T = run_r171_boundary                       % 표 출력 + docs/r171_boundary.md 생성
%   T = run_r171_boundary('')                   % 파일 생성 안 함
%
%   판정 규칙
%     'first' : 해당 단계에 처음 들어간 시각. M0 = 기대값, M1~M3 <= M0 (규정 상한보다 늦지 않음)
%     'none'  : M0에 경고가 없어야 함 (재관여 인정 / 5 s 미만). M1~M3는 더 엄격해도 되므로 값만 기록
%     'reeor' : 두 번째 이탈 뒤 처음 경고가 켜져 있는 시각. M0 = 기대값, M1~M3 <= M0
%   시각은 스텝 종료 시각 L.t (dt = 0.01 s). 시나리오는 모두 "주시로 시작"하지 않으면 t = 0부터 이탈.

here = fileparts(fileparts(mfilename('fullpath')));   % supervisor/ (scripts/의 한 단계 위)
addpath(fullfile(here, 'src'));
if nargin < 1, out_md = fullfile(here, 'docs', 'r171_boundary.md'); end
dt = 0.01; K = @(s) round(s / dt);
ON = @(s) true(K(s), 1); OFF = @(s) false(K(s), 1);

% {조항, 입력 설명, 요구, 종류, 단계, g, valid, 기대(M0), 기준 시각(reeor)}
C = {
 '5.5.4.2.6.2.1', '주시 2 s → 연속 이탈',                 '이탈 5 s까지 EOR',          'first', 1, [ON(2); OFF(10)], [], 7.00, 0
 '5.5.4.2.6.2.1', '이탈 4.99 s → 복귀',                    '5 s 미만이면 EOR 없음',      'none',  1, [OFF(4.99); ON(3)], [], NaN, 0
 '5.5.4.2.5.2.1', '이탈 3 s → 주시 0.19 s → 이탈',         '200 ms 미만은 재관여 아님',  'first', 1, [OFF(3); ON(0.19); OFF(5)], [], 5.19, 0
 '5.5.4.2.5.2.1', '이탈 3 s → 주시 0.20 s → 이탈 4.99 s',  '200 ms면 재관여 (리셋)',     'none',  1, [OFF(3); ON(0.20); OFF(4.99); ON(3)], [], NaN, 0
 '5.5.4.2.5.2.1', '이탈 3 s → 주시 0.20 s → 이탈 5 s',     '리셋 후 다시 5 s에 EOR',     'first', 1, [OFF(3); ON(0.20); OFF(5)], [], 8.20, 0
 '5.5.4.2.6.2.3', '처음부터 연속 이탈',                    '강화 EOR: EOR 후 3 s까지',   'first', 2, OFF(20), [], 8.00, 0
 '5.5.4.2.6.3.1', '처음부터 연속 이탈',                    'DCA: 강화 후 5 s까지',       'first', 3, OFF(20), [], 13.00, 0
 '5.5.4.2.6.4.1', '처음부터 연속 이탈',                    '운전불가: 강화 후 10 s까지', 'first', 4, OFF(20), [], 18.00, 0
 '5.5.4.2.6.2.2', '이탈 6 s → 주시 2.2 s → 이탈 1 s',      '재관여 후 2 s 안 이탈 1 s → EOR', 'reeor', 1, [OFF(6); ON(2.2); OFF(1.0); ON(3)], [], 9.20, 8.2
 '5.5.4.2.6.2.2', '이탈 6 s → 주시 2.21 s → 이탈 1.5 s',   '2 s 뒤 시작이면 해당 없음',  'reeor', 1, [OFF(6); ON(2.21); OFF(1.5); ON(3)], [], NaN, 8.21
 '5.5.4.2.5.2 (fail-safe)', '주시 2 s → 얼굴 미검출',      '미검출 = 이탈',              'first', 1, true(K(12), 1), [ON(2); OFF(10)], 7.00, 0
 '입력 단계 (fail-safe)', '프레임 2.0 s에서 끊김',          '0.2 s 넘게 없으면 이탈',     'first', 1, [], [], 7.21, 0
};

% 통신 끊김: 10 Hz 프레임이 2.0 s까지 오고 끊김 -> 100 Hz 입력으로 변환 (des_resample, C와 같은 규칙)
P0 = des_params(0);
ts = (0:0.1:2.0)'; nf = numel(ts);
U = des_resample([ts; 12.0], [true(nf, 1); true], zeros(nf + 1, 1), zeros(nf + 1, 1), P0);
C{12, 6} = true(numel(U.valid), 1); C{12, 7} = U.valid;

nc = size(C, 1);
val = nan(nc, 4); pass = true(nc, 1); note = strings(nc, 1);
for c = 1:nc
    g = C{c, 6}; v = C{c, 7};
    for m = 0:3
        L = sim_des(g, des_params(m), v);
        e = double(L.esc(:));
        switch C{c, 4}
            case {'first', 'none'}
                i = find(e >= C{c, 5}, 1);
            case 'reeor'
                if m == 0      % M0: 두 번째 EOR 진입
                    on = find(diff([0; e >= 1]) == 1);
                    i = []; if numel(on) >= 2, i = on(2); end
                else           % M1~M3: 두 번째 이탈 시작 뒤 경고가 켜져 있는 첫 시각 (앞 경고가 이어지는 중이면 그 시각)
                    i = find(L.t > C{c, 9} + 1e-9 & e >= 1, 1);
                end
        end
        if ~isempty(i), val(c, m + 1) = L.t(i); end
    end
    ex = C{c, 8};
    ok0 = (isnan(ex) && isnan(val(c, 1))) || abs(val(c, 1) - ex) < 1e-9;
    if strcmp(C{c, 4}, 'none') || isnan(ex)
        okm = true;                                   % 더 엄격한 경고는 허용
        if any(~isnan(val(c, 2:4))), note(c) = "M1~M3 더 엄격(허용)"; end
    else
        okm = all(val(c, 2:4) <= val(c, 1) + 1e-9);
    end
    pass(c) = ok0 && okm;
end

fmt = @(x) iif(isnan(x), '없음', sprintf('%.2f', x));
lines = strings(0);
lines(end+1) = "| # | 조항 | 입력 | 요구 | M0 기대 | M0 | M1 | M2 | M3 | 판정 |";
lines(end+1) = "|---|---|---|---|---|---|---|---|---|---|";
for c = 1:nc
    lines(end+1) = sprintf("| %d | %s | %s | %s | %s | %s | %s | %s | %s | %s |", c, C{c, 1}, C{c, 2}, C{c, 3}, ...
        fmt(C{c, 8}), fmt(val(c, 1)), fmt(val(c, 2)), fmt(val(c, 3)), fmt(val(c, 4)), ...
        strtrim(iif(pass(c), "통과 ", "**실패** ") + note(c)));
end
fprintf('\n%s\n', strjoin(lines, newline));
fprintf('\n%d/%d 통과\n', nnz(pass), nc);

if ~isempty(out_md)
    fid = fopen(out_md, 'w', 'n', 'UTF-8');
    fprintf(fid, '# R171 01 series 경계값 12케이스\n\n');
    fprintf(fid, '`run_r171_boundary.m`이 생성한 파일이다. 손으로 고치지 말 것. 생성: %s\n\n', datestr(now, 'yyyy-mm-dd'));
    fprintf(fid, '- 시각은 경고가 켜지는 스텝의 종료 시각 [s] (dt = 0.01 s). 재EOR(#9, #10)은 두 번째 이탈 뒤 경고가 켜져 있는 첫 시각.\n');
    fprintf(fid, '- 판정: M0가 기대값과 같고, M1~M3가 M0보다 늦지 않으면 통과. "없음" 케이스에서 M1~M3가 경고하는 것은 더 엄격한 것이라 허용.\n');
    fprintf(fid, '- #12는 10 Hz 프레임이 2.0 s에서 끊긴 경우. 2.20 s까지는 마지막 프레임을 쓰고(ZOH, `in_stale` 0.2 s), 2.21 s부터 이탈로 센다.\n\n');
    fprintf(fid, '%s\n\n**%d/%d 통과**\n', strjoin(lines, newline), nnz(pass), nc);
    fclose(fid);
end
T = table((1:nc)', string(C(:, 1)), string(C(:, 2)), cell2mat(C(:, 8)), val, pass, ...
    'VariableNames', {'n', 'clause', 'input', 'expected_m0', 'value_m0_m3', 'pass'});
end

function r = iif(c, a, b)
if c, r = a; else, r = b; end
end
