%RUN_B2B  back-to-back 검증: MATLAB 기준(sim_system) vs Simulink/Stateflow 모델, 매 스텝 비교
%   비교 대상: 두 채널(M0, 선택 모델)의 esc, disengaged, metric + 입력 단계의 gaze_on, frozen
%   esc/disengaged/gaze_on/frozen은 완전 일치, metric(M3 버퍼, double)은 1e-12 이내.
%   C 코드(RPi5 실행 프로그램)와의 대조는 run_b2b_c.m.

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'src'), fullfile(here, 'model'));
sel = 3;

if ~exist(fullfile(here, 'model', 'des_supervisor.slx'), 'file')
    build_model(sel);
end
load_system('des_supervisor');

[Us, names] = b2b_scenarios();
Lm = sim_model(Us);
n_fail = 0; n_steps = 0;
fprintf('%-22s %7s  %s\n', '시나리오', '스텝', '결과');
for s = 1:numel(Us)
    Lg = sim_system(Us{s}, sel);
    [ok, msg] = b2b_compare(Lg, Lm{s});
    n_steps = n_steps + numel(Lg.t);
    n_fail = n_fail + ~ok;
    fprintf('%-22s %7d  %s\n', names{s}, numel(Lg.t), msg);
end
fprintf('\n%d개 시나리오, %d 스텝: %s\n', numel(Us), n_steps, ...
    ternary(n_fail == 0, '모두 일치', sprintf('%d개 불일치', n_fail)));

function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end
