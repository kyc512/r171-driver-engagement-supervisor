function L = sim_model(Us)
%SIM_MODEL  Simulink 모델(des_supervisor)에 100 Hz 입력을 넣고 sim_system과 같은 형식으로 로그 반환
%   L = sim_model(U)        % U: 구조체 하나 또는 구조체 cell 배열 (시나리오 여러 개를 한 번에)
%   L은 U와 같은 형태 (cell이면 cell)

mdl = 'des_supervisor';
if ~bdIsLoaded(mdl), load_system(mdl); end
single_in = ~iscell(Us);
if single_in, Us = {Us}; end

dt = str2double(get_param(mdl, 'FixedStep'));
in_names = {'valid', 'yaw', 'pitch', 'driver_action', 'reset'};
fields   = {'valid', 'yaw', 'pitch', 'action', 'reset'};

simIn = Simulink.SimulationInput.empty;
for s = 1:numel(Us)
    U = Us{s};
    n = numel(U.valid);
    time = (0:n-1)' * dt;
    ds = Simulink.SimulationData.Dataset;
    for k = 1:numel(in_names)
        ts = timeseries(U.(fields{k})(:), time);
        ts.Name = in_names{k};
        ds = ds.addElement(ts, in_names{k});
    end
    simIn(s) = Simulink.SimulationInput(mdl);
    simIn(s) = simIn(s).setExternalInput(ds);
    simIn(s) = simIn(s).setModelParameter('StopTime', sprintf('%.17g', (n-1) * dt));
end
out = sim(simIn, 'ShowProgress', 'off');

Ls = cell(size(Us));
for s = 1:numel(Us)
    y = out(s).yout;
    vals = containers.Map;                % Outport 블록 이름 -> 데이터
    for k = 1:y.numElements
        e = y.getElement(k);
        [~, bname] = fileparts(e.BlockPath.getBlock(1));
        vals(bname) = e.Values.Data(:);
    end
    g = @(name) vals(name);
    n = numel(Us{s}.valid);
    L.t       = (1:n)' * dt;
    L.gaze_on = logical(g('gaze_on'));
    L.frozen  = logical(g('frozen'));
    L.esc     = uint8([g('esc_m0') g('esc_sel')]);
    L.dis     = logical([g('dis_m0') g('dis_sel')]);
    L.metric  = double([g('metric_m0') g('metric_sel')]);
    Ls{s} = L;
end
if single_in, L = Ls{1}; else, L = Ls; end
end
