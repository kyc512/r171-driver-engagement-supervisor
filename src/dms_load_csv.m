function D = dms_load_csv(path, calib_s)
%DMS_LOAD_CSV  DMS CSV 읽기 + 0점 보정 (RPi5 des_main --csv --calib과 같은 규칙)
%   D = dms_load_csv(path)            보정 없음
%   D = dms_load_csv(path, calib_s)   처음 calib_s초 동안 valid 프레임의 평균을 0점으로
%
%   읽는 형식 (열 이름으로 찾음):
%     timestamp,valid,yaw,pitch                (인터페이스 문서 형식, valid = 1/0)
%     timestamp,face_detected,yaw,pitch        (DMS 모듈 demo_video.py 출력, True/False, 빈 칸)
%   얼굴이 검출됐어도 각도가 비어 있으면 valid = false.
%
%   D: ts, valid, yaw, pitch (보정 후), yaw0, pitch0, n_calib

if nargin < 2, calib_s = 0; end

opts = detectImportOptions(path, 'Delimiter', ',');
opts = setvartype(opts, 'char');                 % True/False와 빈 칸을 직접 해석
T = readtable(path, opts);
names = T.Properties.VariableNames;
if ismember('valid', names)
    vcol = T.valid;
elseif ismember('face_detected', names)
    vcol = T.face_detected;
else
    error('dms_load_csv:format', '%s: valid 또는 face_detected 열이 필요합니다', path);
end

D.ts    = str2double(T.timestamp);
flag    = strcmpi(vcol, 'true') | (str2double(vcol) > 0.5);
yaw     = str2double(T.yaw);                     % 빈 칸 -> NaN
pitch   = str2double(T.pitch);
D.valid = flag & isfinite(yaw) & isfinite(pitch);
D.yaw   = yaw;   D.yaw(~D.valid) = 0;
D.pitch = pitch; D.pitch(~D.valid) = 0;

D.yaw0 = 0; D.pitch0 = 0; D.n_calib = 0;
if calib_s > 0
    k = D.valid & D.ts < calib_s;
    D.n_calib = nnz(k);
    if D.n_calib > 0
        D.yaw0   = mean(D.yaw(k));
        D.pitch0 = mean(D.pitch(k));
        D.yaw(D.valid)   = D.yaw(D.valid)   - D.yaw0;
        D.pitch(D.valid) = D.pitch(D.valid) - D.pitch0;
    else
        warning('dms_load_csv:calib', '%s: 처음 %.1f초에 valid 프레임이 없어 보정하지 않습니다', path, calib_s);
    end
end
end
