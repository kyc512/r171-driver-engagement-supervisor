function [SI, gaze_on, frozen] = des_input_step(SI, valid, yaw, pitch, P) %#codegen
%DES_INPUT_STEP  입력 단계 1 스텝 (dt = P.dt). DMS 각도 -> 감지 계층 입력
%
%   입력  valid      : 얼굴/시선 검출 성공 (리샘플·통신 끊김 처리 후)
%         yaw, pitch : 시선 각도 [deg], 보정(0점) 적용 후. valid = false면 무시
%   출력  gaze_on    : 프레임별 주시 영역 판정 (시간 판단 없음)
%         frozen     : 최근 fz_W초 동안 연속 valid이고 yaw, pitch 변화폭이 모두 fz_range 미만
%                      -> 사진·가짜 얼굴 의심. 사용 여부는 모델별 P.fz_enable (감지 블록에서 결정)

if valid
    gaze_on = abs(yaw) <= P.aoi_yaw && abs(pitch) <= P.aoi_pitch;

    SI.yb(SI.idx) = yaw;
    SI.pb(SI.idx) = pitch;
    N = min(round(P.fz_W / P.dt), P.FZ_MAX_N);
    SI.idx = SI.idx + 1;
    if SI.idx > N
        SI.idx = 1;
    end
    SI.cnt = min(SI.cnt + 1, N);

    frozen = false;
    if SI.cnt >= N
        frozen = (max(SI.yb(1:N)) - min(SI.yb(1:N))) < P.fz_range && ...
                 (max(SI.pb(1:N)) - min(SI.pb(1:N))) < P.fz_range;
    end
else
    gaze_on = false;
    frozen  = false;
    SI.cnt  = 0;     % 미검출이 끼면 창을 처음부터 다시 채움
end
end
