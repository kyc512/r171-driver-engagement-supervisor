function mdl = build_model(sel_model)
%BUILD_MODEL  Supervisor Simulink/Stateflow 모델을 스크립트로 생성 -> model/des_supervisor.slx
%   build_model        % 선택 모델 = M3
%   build_model(2)     % 선택 모델 = M2
%
%   구조 (fixed-step discrete, Ts = 0.01 s)
%     valid, yaw, pitch ─► [InputStage] ─ gaze_on, frozen ─┬─► [Ch_M0] ─► esc_m0, dis_m0, metric_m0
%                                                         └─► [Ch_Mx] ─► esc_sel, dis_sel, metric_sel
%     채널 = [Detector: MATLAB Function, src/des_detect.m] ─ disengaged ─► [Escalation: Stateflow, 공통]
%
%   InputStage/Detector는 MATLAB 기준 코드(src/)를 그대로 호출하고,
%   Escalation은 Stateflow 차트로 따로 구현한다 -> run_b2b.m 으로 des_step.m과 매 스텝 대조.
%   .slx는 생성물이다. 손으로 고치지 말고 이 스크립트를 고친 뒤 다시 생성할 것.

if nargin < 1, sel_model = 3; end
assert(any(sel_model == 1:3), '선택 모델은 M1~M3');

here = fileparts(mfilename('fullpath'));
addpath(fullfile(fileparts(here), 'src'));
P0 = des_params(0);
dt = P0.dt;

mdl = 'des_supervisor';
if bdIsLoaded(mdl), close_system(mdl, 0); end
slx = fullfile(here, [mdl '.slx']);
if exist(slx, 'file'), delete(slx); end

new_system(mdl);
set_param(mdl, ...
    'SolverType', 'Fixed-step', 'Solver', 'FixedStepDiscrete', 'FixedStep', num2str(dt), ...
    'StopTime', 'inf', ...
    'SaveTime', 'on', 'SaveOutput', 'on', 'OutputSaveName', 'yout', 'SaveFormat', 'Dataset', ...
    'ReturnWorkspaceOutputs', 'on', ...
    'PreLoadFcn', 'addpath(fullfile(fileparts(fileparts(which(''des_supervisor''))), ''src''));');
set_param(mdl, 'Description', sprintf( ...
    'build_model.m 생성물 (선택 모델 M%d). 손으로 수정하지 말 것.', sel_model));
configure_codegen(mdl);

% ---------------- 최상위 입력 ----------------
in_names = {'valid', 'yaw', 'pitch', 'driver_action', 'reset'};
in_types = {'boolean', 'double', 'double', 'boolean', 'boolean'};
for k = 1:numel(in_names)
    add_block('simulink/Sources/In1', [mdl '/' in_names{k}], ...
        'Position', pos(30, 40 + 70*(k-1), 30, 14), ...
        'OutDataTypeStr', in_types{k}, 'SampleTime', num2str(dt), ...
        'PortDimensions', '1', 'Interpolate', 'off');
end

% ---------------- 입력 단계 ----------------
add_mfunc([mdl '/InputStage'], pos(180, 40, 150, 150), sprintf([ ...
    'function [gaze_on, frozen] = InputStage(valid, yaw, pitch, reset)\n' ...
    '%% 입력 단계: 주시 영역 판정 + 고정 탐지 (src/des_input_step.m)\n' ...
    'P = des_params(%d);\n' ...
    'persistent SI\n' ...
    'if isempty(SI)\n    SI = des_input_init(P);\nend\n' ...
    'if reset\n    SI = des_input_init(P);\nend\n' ...
    '[SI, gaze_on, frozen] = des_input_step(SI, valid, yaw, pitch, P);\n'], sel_model));
add_line(mdl, 'valid/1', 'InputStage/1', 'autorouting', 'on');
add_line(mdl, 'yaw/1',   'InputStage/2', 'autorouting', 'on');
add_line(mdl, 'pitch/1', 'InputStage/3', 'autorouting', 'on');
add_line(mdl, 'reset/1', 'InputStage/4', 'autorouting', 'on');

% ---------------- 채널: M0(기준선) + 선택 모델 ----------------
chans = {sprintf('Ch_M0'), sprintf('Ch_M%d', sel_model)};
ids   = [0 sel_model];
sfx   = {'m0', 'sel'};
for c = 1:2
    sys = [mdl '/' chans{c}];
    add_channel(sys, ids(c), pos(420, 40 + 260*(c-1), 160, 180));
    add_line(mdl, 'InputStage/1',    [chans{c} '/1'], 'autorouting', 'on');
    add_line(mdl, 'InputStage/2',    [chans{c} '/2'], 'autorouting', 'on');
    add_line(mdl, 'valid/1',         [chans{c} '/3'], 'autorouting', 'on');
    add_line(mdl, 'driver_action/1', [chans{c} '/4'], 'autorouting', 'on');
    add_line(mdl, 'reset/1',         [chans{c} '/5'], 'autorouting', 'on');
    outs = {'esc', 'dis', 'metric'};
    for k = 1:3
        name = [outs{k} '_' sfx{c}];
        add_block('simulink/Sinks/Out1', [mdl '/' name], ...
            'Position', pos(680, 60 + 260*(c-1) + 50*(k-1), 30, 14));
        add_line(mdl, sprintf('%s/%d', chans{c}, k), [name '/1'], 'autorouting', 'on');
    end
end
add_block('simulink/Sinks/Out1', [mdl '/gaze_on'], 'Position', pos(680, 560, 30, 14));
add_block('simulink/Sinks/Out1', [mdl '/frozen'],  'Position', pos(680, 610, 30, 14));
add_line(mdl, 'InputStage/1', 'gaze_on/1', 'autorouting', 'on');
add_line(mdl, 'InputStage/2', 'frozen/1',  'autorouting', 'on');

save_system(mdl, slx);
fprintf('생성: %s (Ch_M0 + Ch_M%d)\n', slx, sel_model);
end

% =====================================================================
function add_channel(sys, model_id, p)
%ADD_CHANNEL  감지 블록(모델별) + 공통 Escalation 차트
add_block('simulink/Ports & Subsystems/Subsystem', sys, 'Position', p);
delete_line(sys, 'In1/1', 'Out1/1');
delete_block([sys '/In1']); delete_block([sys '/Out1']);

ins = {'gaze_on', 'frozen', 'valid', 'driver_action', 'reset'};
for k = 1:numel(ins)
    add_block('simulink/Sources/In1', [sys '/' ins{k}], 'Position', pos(30, 40 + 60*(k-1), 30, 14));
end

add_mfunc([sys '/Detector'], pos(160, 30, 140, 130), sprintf([ ...
    'function [disengaged, metric] = Detector(gaze_on, frozen, valid, reset)\n' ...
    '%% 감지 계층 M%d (src/des_detect.m). R171 기본 타이머 OR 모델별 판정\n' ...
    'P = des_params(%d);\n' ...
    'persistent S\n' ...
    'if isempty(S)\n    S = des_init(P);\nend\n' ...
    'if reset\n    S = des_init(P);\nend\n' ...
    'v = valid && ~(P.fz_enable && frozen);   %% 고정(사진) 의심이면 미검출과 같게 처리\n' ...
    '[S, disengaged, ~, metric] = des_detect(S, gaze_on, v, P);\n'], model_id, model_id));
add_line(sys, 'gaze_on/1', 'Detector/1', 'autorouting', 'on');
add_line(sys, 'frozen/1',  'Detector/2', 'autorouting', 'on');
add_line(sys, 'valid/1',   'Detector/3', 'autorouting', 'on');
add_line(sys, 'reset/1',   'Detector/4', 'autorouting', 'on');

add_escalation_chart([sys '/Escalation'], pos(380, 60, 140, 130), des_params(model_id));
add_line(sys, 'Detector/1',      'Escalation/1', 'autorouting', 'on');
add_line(sys, 'driver_action/1', 'Escalation/2', 'autorouting', 'on');
add_line(sys, 'reset/1',         'Escalation/3', 'autorouting', 'on');

outs = {'esc', 'disengaged', 'metric'};
src  = {'Escalation/1', 'Detector/1', 'Detector/2'};
for k = 1:3
    add_block('simulink/Sinks/Out1', [sys '/' outs{k}], 'Position', pos(600, 60 + 60*(k-1), 30, 14));
    add_line(sys, src{k}, [outs{k} '/1'], 'autorouting', 'on');
end
end

% =====================================================================
function add_escalation_chart(path, p, P)
%ADD_ESCALATION_CHART  공통 Escalation: ENGAGED -> EOR -> EOR_ENH -> DCA -> UNAVAILABLE
%   des_step.m 3절과 1:1. 시간 조건은 after(N, tick), N = round(T/dt) -> 경계에서 결정적.
%   전이 우선순위: (1) reset/해제 -> ENGAGED, (2) 시간 경과 -> 다음 단계.
add_block('sflib/Chart', path, 'Position', p);
ch = find(sfroot, '-isa', 'Stateflow.Chart', 'Path', path);
ch.ActionLanguage = 'MATLAB';
ch.ChartUpdate = 'DISCRETE';
ch.SampleTime = num2str(P.dt);
ch.ExecuteAtInitialization = true;   % 초기화 시 ENGAGED 진입 -> 첫 스텝부터 전이 평가 (des_step과 동일)

add_data(ch, 'disengaged',    'Input',  'boolean');
add_data(ch, 'driver_action', 'Input',  'boolean');
add_data(ch, 'reset',         'Input',  'boolean');
add_data(ch, 'esc',           'Output', 'uint8');

names = {'ENGAGED', 'EOR', 'EOR_ENH', 'DCA', 'UNAVAILABLE'};
S = cell(1, 5);
for k = 1:5
    S{k} = Stateflow.State(ch);
    S{k}.LabelString = sprintf('%s\nentry: esc = uint8(%d);', names{k}, k - 1);
    S{k}.Position = [40 + 190*(k-1), 60, 140, 70];
end

t = Stateflow.Transition(ch);              % 기본 전이
t.Destination = S{1};
t.DestinationOClock = 0;
t.SourceEndpoint = t.DestinationEndpoint - [0 35];
t.MidPoint = t.DestinationEndpoint - [0 17];

tk = @(x) round(x / P.dt);
if P.dca_requires_action
    dca_release = '[reset || (~disengaged && driver_action)]';
else
    dca_release = '[reset || ~disengaged]';
end
release = {'', '[reset || ~disengaged]', '[reset || ~disengaged]', dca_release, '[reset]'};
advance = {'[disengaged]', ...
           sprintf('after(%d, tick)', tk(P.T_eor_enh)), ...
           sprintf('after(%d, tick)', tk(P.T_dca)), ...
           sprintf('after(%d, tick)', tk(P.T_unavail)), ''};

for k = 2:5                                % 해제/리셋 -> ENGAGED (1순위)
    t = Stateflow.Transition(ch);
    t.Source = S{k}; t.Destination = S{1};
    t.SourceOClock = 6; t.DestinationOClock = 6;
    t.MidPoint = [mean([S{k}.Position(1), S{1}.Position(1)]) + 70, 170 + 25*(k-2)];
    t.LabelString = release{k};
    t.ExecutionOrder = 1;
end
for k = 1:4                                % 다음 단계 (2순위)
    t = Stateflow.Transition(ch);
    t.Source = S{k}; t.Destination = S{k+1};
    t.SourceOClock = 3; t.DestinationOClock = 9;
    t.LabelString = advance{k};
    if k > 1, t.ExecutionOrder = 2; end
end
end

function add_data(ch, name, scope, type)
d = Stateflow.Data(ch);
d.Name = name; d.Scope = scope; d.DataType = type;
end

% =====================================================================
function add_mfunc(path, p, code)
add_block('simulink/User-Defined Functions/MATLAB Function', path, 'Position', p);
emc = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', path);
emc.Script = code;
end

function configure_codegen(mdl)
%CONFIGURE_CODEGEN  Simulink Coder (grt) 범용 C. RPi5에서 gcc로 빌드한다.
set_param(mdl, 'SystemTargetFile', 'grt.tlc');
set_param(mdl, 'TargetLang', 'C', 'GenCodeOnly', 'on', 'GenerateReport', 'off', ...
    'MatFileLogging', 'off', 'SupportNonFinite', 'off', 'RTWVerbose', 'off', ...
    'ProdHWDeviceType', 'ARM Compatible->ARM 64-bit (LP64)');
end

function p = pos(x, y, w, h)
p = [x, y, x + w, y + h];
end
