function build_system(sel_model)
%BUILD_SYSTEM  모델 생성 -> Simulink Coder(grt)로 C 생성 -> deploy/codegen/ 에 모음
%   build_system        % 선택 모델 M3
%   build_system(2)
%
%   결과물 deploy/codegen/ 은 외부 의존성 없는 C 소스. RPi5에서 deploy/rpi/의 Makefile로 빌드한다.
%     des_build.mk : 생성 코드의 소스 목록과 컴파일 정의 (Makefile이 include)
%     des_config.h : 선택 모델 번호와 주요 파라미터 (실행 프로그램 화면 표시용)

if nargin < 1, sel_model = 3; end
here = fileparts(fileparts(mfilename('fullpath')));   % supervisor/ (scripts/의 한 단계 위)
addpath(fullfile(here, 'src'), fullfile(here, 'model'));

mdl = build_model(sel_model);
build_dir = fullfile(here, 'build');
if ~exist(build_dir, 'dir'), mkdir(build_dir); end
Simulink.fileGenControl('set', 'CacheFolder', build_dir, 'CodeGenFolder', build_dir, 'createDir', true);
c = onCleanup(@() Simulink.fileGenControl('reset'));

slbuild(mdl);

bi_file = fullfile(build_dir, [mdl '_grt_rtw'], 'buildInfo.mat');
S = load(bi_file);
zipf = fullfile(build_dir, [mdl '_src.zip']);
packNGo(S.buildInfo, 'packType', 'flat', 'fileName', zipf);

out = fullfile(here, 'deploy', 'codegen');
if exist(out, 'dir'), rmdir(out, 's'); end
mkdir(out);
unzip(zipf, out);

% 생성 코드 중 grt 기본 main과 MAT 로깅 소스는 제외 (deploy/rpi/des_main.c가 main)
files = dir(fullfile(out, '*.c'));
srcs = {files.name};
skip = contains(srcs, {'main', 'rt_logging'});
srcs = srcs(~skip);
defs = getDefines(S.buildInfo);

fid = fopen(fullfile(out, 'des_build.mk'), 'w');
fprintf(fid, '# build_system.m 생성물 (선택 모델 M%d)\n', sel_model);
fprintf(fid, 'DES_GEN_SRCS = %s\n', strjoin(srcs, ' '));
fprintf(fid, 'DES_GEN_DEFS = %s\n', strjoin(defs, ' '));
fclose(fid);

P = des_params(sel_model);
fid = fopen(fullfile(out, 'des_config.h'), 'w');
fprintf(fid, '/* build_system.m 생성물. 손으로 고치지 말 것. */\n');
fprintf(fid, '#ifndef DES_CONFIG_H\n#define DES_CONFIG_H\n');
fprintf(fid, '#define DES_SEL_MODEL   %d\n', sel_model);
fprintf(fid, '#define DES_DT          %.17g\n', P.dt);
fprintf(fid, '#define DES_IN_STALE    %.17g  /* s: 이보다 오래된 DMS 프레임 -> valid = 0 */\n', P.in_stale);
fprintf(fid, '#define DES_AOI_YAW     %.17g  /* deg */\n', P.aoi_yaw);
fprintf(fid, '#define DES_AOI_PITCH   %.17g  /* deg */\n', P.aoi_pitch);
fprintf(fid, '#define DES_FZ_W        %.17g  /* s */\n', P.fz_W);
fprintf(fid, '#define DES_FZ_RANGE    %.17g  /* deg */\n', P.fz_range);
fprintf(fid, '#endif\n');
fclose(fid);

fprintf('C 소스 -> %s\n  모델 소스: %s\n', out, strjoin(srcs, ', '));
end
