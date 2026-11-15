/* des_app.c  생성 코드(des_supervisor.c) 호출부. 자세한 설명은 des_app.h */
#include "des_app.h"
#include "des_config.h"
#include "des_supervisor.h"

const char *const des_state_name[5] = {"ENGAGED", "EOR", "EOR_ENH", "DCA", "UNAVAILABLE"};

void des_app_init(void) { des_supervisor_initialize(); }
void des_app_term(void) { des_supervisor_terminate(); }

void des_app_step(const des_input_t *in, des_output_t *out)
{
    des_supervisor_U.valid         = in->valid;
    des_supervisor_U.yaw           = in->yaw;
    des_supervisor_U.pitch         = in->pitch;
    des_supervisor_U.driver_action = in->action;
    des_supervisor_U.reset         = in->reset;

    des_supervisor_step();

    out->esc[0]    = des_supervisor_Y.esc_m0;
    out->dis[0]    = des_supervisor_Y.dis_m0;
    out->metric[0] = des_supervisor_Y.metric_m0;
    out->esc[1]    = des_supervisor_Y.esc_sel;
    out->dis[1]    = des_supervisor_Y.dis_sel;
    out->metric[1] = des_supervisor_Y.metric_sel;
    out->gaze_on   = des_supervisor_Y.gaze_on;
    out->frozen    = des_supervisor_Y.frozen;
}

void des_zoh(const des_frame_t *last, double t_s, des_input_t *in)
{
    in->valid = false; in->yaw = 0.0; in->pitch = 0.0;
    in->action = false; in->reset = false;
    if (last == 0) return;                       /* 아직 프레임 없음 */
    if (last->valid && (t_s - last->ts) <= DES_IN_STALE + DES_TOL) {
        in->valid = true;
        in->yaw   = last->yaw;
        in->pitch = last->pitch;
    }
    in->action = last->action;
    in->reset  = last->reset;
}
