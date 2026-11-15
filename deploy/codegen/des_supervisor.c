/*
 * des_supervisor.c
 *
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * Code generation for model "des_supervisor".
 *
 * Model version              : 1.1
 * Simulink Coder version : 26.2 (R2026b) 22-May-2026
 * C source code generated on : Thu Nov 12 12:41:44 2026
 *
 * Target selection: grt.tlc
 * Note: GRT includes extra infrastructure and instrumentation for prototyping
 * Embedded hardware selection: ARM Compatible->ARM 64-bit (LP64)
 * Code generation objectives: Unspecified
 * Validation result: Not run
 */

#include "des_supervisor.h"
#include "rtwtypes.h"
#include "des_supervisor_private.h"
#include <string.h>
#include <math.h>

/* Named constants for Chart: '<S1>/Escalation' */
#define des_supervisor_IN_DCA          ((uint8_T)1U)
#define des_supervisor_IN_ENGAGED      ((uint8_T)2U)
#define des_supervisor_IN_EOR          ((uint8_T)3U)
#define des_supervisor_IN_EOR_ENH      ((uint8_T)4U)
#define des_supervisor_IN_UNAVAILABLE  ((uint8_T)5U)

/* Block signals (default storage) */
B_des_supervisor_T des_supervisor_B;

/* Block states (default storage) */
DW_des_supervisor_T des_supervisor_DW;

/* External inputs (root inport signals with default storage) */
ExtU_des_supervisor_T des_supervisor_U;

/* External outputs (root outports fed by signals with default storage) */
ExtY_des_supervisor_T des_supervisor_Y;

/* Real-time model */
static RT_MODEL_des_supervisor_T des_supervisor_M_;
RT_MODEL_des_supervisor_T *const des_supervisor_M = &des_supervisor_M_;

/*
 * System initialize for atomic system:
 *    '<S1>/Escalation'
 *    '<S2>/Escalation'
 */
void des_supervisor_Escalation_Init(B_Escalation_des_supervisor_T *localB,
  DW_Escalation_des_supervisor_T *localDW)
{
  localDW->temporalCounter_i1 = 0U;

  /* Chart: '<S1>/Escalation' */
  localDW->is_c3_des_supervisor = des_supervisor_IN_ENGAGED;
  localB->esc = 0U;
}

/*
 * Output and update for atomic system:
 *    '<S1>/Escalation'
 *    '<S2>/Escalation'
 */
void des_supervisor_Escalation(boolean_T rtu_disengaged, boolean_T
  rtu_driver_action, boolean_T rtu_reset, B_Escalation_des_supervisor_T *localB,
  DW_Escalation_des_supervisor_T *localDW)
{
  if (localDW->temporalCounter_i1 < 511) {
    localDW->temporalCounter_i1++;
  }

  switch (localDW->is_c3_des_supervisor) {
   case des_supervisor_IN_DCA:
    localB->esc = 3U;
    if (rtu_reset || (!rtu_disengaged && rtu_driver_action)) {
      localDW->is_c3_des_supervisor = des_supervisor_IN_ENGAGED;
      localB->esc = 0U;
    } else if (localDW->temporalCounter_i1 >= 500) {
      localDW->is_c3_des_supervisor = des_supervisor_IN_UNAVAILABLE;
      localB->esc = 4U;
    }
    break;

   case des_supervisor_IN_ENGAGED:
    localB->esc = 0U;
    if (rtu_disengaged) {
      localDW->temporalCounter_i1 = 0U;
      localDW->is_c3_des_supervisor = des_supervisor_IN_EOR;
      localB->esc = 1U;
    }
    break;

   case des_supervisor_IN_EOR:
    localB->esc = 1U;
    if (rtu_reset || !rtu_disengaged) {
      localDW->is_c3_des_supervisor = des_supervisor_IN_ENGAGED;
      localB->esc = 0U;
    } else if (localDW->temporalCounter_i1 >= 300) {
      localDW->temporalCounter_i1 = 0U;
      localDW->is_c3_des_supervisor = des_supervisor_IN_EOR_ENH;
      localB->esc = 2U;
    }
    break;

   case des_supervisor_IN_EOR_ENH:
    localB->esc = 2U;
    if (rtu_reset || !rtu_disengaged) {
      localDW->is_c3_des_supervisor = des_supervisor_IN_ENGAGED;
      localB->esc = 0U;
    } else if (localDW->temporalCounter_i1 >= 500) {
      localDW->temporalCounter_i1 = 0U;
      localDW->is_c3_des_supervisor = des_supervisor_IN_DCA;
      localB->esc = 3U;
    }
    break;

   default:
    /* case IN_UNAVAILABLE: */
    localB->esc = 4U;
    if (rtu_reset) {
      localDW->is_c3_des_supervisor = des_supervisor_IN_ENGAGED;
      localB->esc = 0U;
    }
    break;
  }
}

/* Model step function */
void des_supervisor_step(void)
{
  real_T SI_yb;
  real_T b_ex;
  real_T ex;
  int32_T i;
  boolean_T a__1;
  boolean_T on;
  boolean_T rtb_frozen;
  boolean_T rtb_gaze_on;

  /* MATLAB Function: '<Root>/InputStage' incorporates:
   *  Inport: '<Root>/pitch'
   *  Inport: '<Root>/reset'
   *  Inport: '<Root>/valid'
   *  Inport: '<Root>/yaw'
   */
  if (des_supervisor_U.reset) {
    memset(&des_supervisor_DW.SI.yb[0], 0, 3000U * sizeof(real_T));
    memset(&des_supervisor_DW.SI.pb[0], 0, 3000U * sizeof(real_T));
    des_supervisor_DW.SI.idx = 1.0;
    des_supervisor_DW.SI.cnt = 0.0;
  }

  if (des_supervisor_U.valid) {
    if ((fabs(des_supervisor_U.yaw) <= 11.0) && (fabs(des_supervisor_U.pitch) <=
         13.0)) {
      rtb_gaze_on = true;
    } else {
      rtb_gaze_on = false;
    }

    des_supervisor_DW.SI.yb[(int32_T)des_supervisor_DW.SI.idx - 1] =
      des_supervisor_U.yaw;
    des_supervisor_DW.SI.pb[(int32_T)des_supervisor_DW.SI.idx - 1] =
      des_supervisor_U.pitch;
    des_supervisor_DW.SI.idx++;
    if (des_supervisor_DW.SI.idx > 1000.0) {
      des_supervisor_DW.SI.idx = 1.0;
    }

    des_supervisor_DW.SI.cnt = fmin(des_supervisor_DW.SI.cnt + 1.0, 1000.0);
    rtb_frozen = false;
    if (des_supervisor_DW.SI.cnt >= 1000.0) {
      ex = des_supervisor_DW.SI.yb[0];
      b_ex = des_supervisor_DW.SI.yb[0];
      for (i = 0; i < 999; i++) {
        SI_yb = des_supervisor_DW.SI.yb[i + 1];
        if (ex < SI_yb) {
          ex = SI_yb;
        }

        if (b_ex > SI_yb) {
          b_ex = SI_yb;
        }
      }

      if (ex - b_ex < 1.0) {
        ex = des_supervisor_DW.SI.pb[0];
        b_ex = des_supervisor_DW.SI.pb[0];
        for (i = 0; i < 999; i++) {
          SI_yb = des_supervisor_DW.SI.pb[i + 1];
          if (ex < SI_yb) {
            ex = SI_yb;
          }

          if (b_ex > SI_yb) {
            b_ex = SI_yb;
          }
        }

        if (ex - b_ex < 1.0) {
          rtb_frozen = true;
        }
      }
    }
  } else {
    rtb_gaze_on = false;
    rtb_frozen = false;
    des_supervisor_DW.SI.cnt = 0.0;
  }

  /* End of MATLAB Function: '<Root>/InputStage' */

  /* MATLAB Function: '<S1>/Detector' incorporates:
   *  Inport: '<Root>/reset'
   *  Inport: '<Root>/valid'
   */
  if (des_supervisor_U.reset) {
    des_supervisor_DW.S.on_k = 0.0;
    des_supervisor_DW.S.dis_k = 0.0;
    des_supervisor_DW.S.rw_k = -1.0;
    des_supervisor_DW.S.rw_hit = false;
    des_supervisor_DW.S.dis_prev = false;
    des_supervisor_DW.S.latched = false;
    memset(&des_supervisor_DW.S.hist[0], 0, 6000U * sizeof(boolean_T));
    des_supervisor_DW.S.hist_idx = 1.0;
    des_supervisor_DW.S.cum_k = 0.0;
    des_supervisor_DW.S.buf = 5.0;
    des_supervisor_DW.S.esc = 0U;
    des_supervisor_DW.S.esc_k = 0.0;
  }

  if (rtb_gaze_on && des_supervisor_U.valid) {
    des_supervisor_DW.S.on_k++;
    if (des_supervisor_DW.S.on_k >= 20.0) {
      des_supervisor_DW.S.dis_k = 0.0;
    }
  } else {
    des_supervisor_DW.S.on_k = 0.0;
    des_supervisor_DW.S.dis_k++;
  }

  if (des_supervisor_DW.S.rw_k >= 0.0) {
    if ((des_supervisor_DW.S.dis_k == 1.0) && (des_supervisor_DW.S.rw_k <= 200.0))
    {
      des_supervisor_DW.S.rw_hit = true;
    }

    if (des_supervisor_DW.S.rw_hit && (des_supervisor_DW.S.dis_k >= 100.0)) {
      des_supervisor_DW.S.dis_k = fmax(des_supervisor_DW.S.dis_k, 500.0);
      des_supervisor_DW.S.rw_k = -1.0;
      des_supervisor_DW.S.rw_hit = false;
    } else {
      if (des_supervisor_DW.S.dis_k == 0.0) {
        des_supervisor_DW.S.rw_hit = false;
      }

      des_supervisor_DW.S.rw_k++;
      if (!des_supervisor_DW.S.rw_hit && (des_supervisor_DW.S.rw_k > 200.0)) {
        des_supervisor_DW.S.rw_k = -1.0;
      }
    }
  }

  a__1 = (des_supervisor_DW.S.dis_k >= 500.0);
  if (des_supervisor_DW.S.dis_prev && !a__1) {
    des_supervisor_DW.S.rw_k = 0.0;
    des_supervisor_DW.S.rw_hit = false;
  }

  des_supervisor_DW.S.dis_prev = a__1;

  /* Outport: '<Root>/dis_m0' incorporates:
   *  MATLAB Function: '<S1>/Detector'
   */
  des_supervisor_Y.dis_m0 = a__1;

  /* Chart: '<S1>/Escalation' incorporates:
   *  Inport: '<Root>/driver_action'
   *  Inport: '<Root>/reset'
   *  Outport: '<Root>/dis_m0'
   */
  des_supervisor_Escalation(des_supervisor_Y.dis_m0,
    des_supervisor_U.driver_action, des_supervisor_U.reset,
    &des_supervisor_B.sf_Escalation, &des_supervisor_DW.sf_Escalation);

  /* Outport: '<Root>/esc_m0' */
  des_supervisor_Y.esc_m0 = des_supervisor_B.sf_Escalation.esc;

  /* Outport: '<Root>/metric_m0' incorporates:
   *  MATLAB Function: '<S1>/Detector'
   */
  des_supervisor_Y.metric_m0 = des_supervisor_DW.S.dis_k * 0.01;

  /* MATLAB Function: '<S2>/Detector' incorporates:
   *  Inport: '<Root>/reset'
   *  Inport: '<Root>/valid'
   */
  if (des_supervisor_U.reset) {
    des_supervisor_DW.S_g.on_k = 0.0;
    des_supervisor_DW.S_g.dis_k = 0.0;
    des_supervisor_DW.S_g.rw_k = -1.0;
    des_supervisor_DW.S_g.rw_hit = false;
    des_supervisor_DW.S_g.dis_prev = false;
    des_supervisor_DW.S_g.latched = false;
    memset(&des_supervisor_DW.S_g.hist[0], 0, 6000U * sizeof(boolean_T));
    des_supervisor_DW.S_g.hist_idx = 1.0;
    des_supervisor_DW.S_g.cum_k = 0.0;
    des_supervisor_DW.S_g.buf = 5.0;
    des_supervisor_DW.S_g.esc = 0U;
    des_supervisor_DW.S_g.esc_k = 0.0;
  }

  if (des_supervisor_U.valid && !rtb_frozen) {
    a__1 = true;
  } else {
    a__1 = false;
  }

  on = (rtb_gaze_on && a__1);
  if (on) {
    des_supervisor_DW.S_g.on_k++;
    if (des_supervisor_DW.S_g.on_k >= 20.0) {
      des_supervisor_DW.S_g.dis_k = 0.0;
    }
  } else {
    des_supervisor_DW.S_g.on_k = 0.0;
    des_supervisor_DW.S_g.dis_k++;
  }

  if (des_supervisor_DW.S_g.rw_k >= 0.0) {
    if ((des_supervisor_DW.S_g.dis_k == 1.0) && (des_supervisor_DW.S_g.rw_k <=
         200.0)) {
      des_supervisor_DW.S_g.rw_hit = true;
    }

    if (des_supervisor_DW.S_g.rw_hit && (des_supervisor_DW.S_g.dis_k >= 100.0))
    {
      des_supervisor_DW.S_g.dis_k = fmax(des_supervisor_DW.S_g.dis_k, 500.0);
      des_supervisor_DW.S_g.rw_k = -1.0;
      des_supervisor_DW.S_g.rw_hit = false;
    } else {
      if (des_supervisor_DW.S_g.dis_k == 0.0) {
        des_supervisor_DW.S_g.rw_hit = false;
      }

      des_supervisor_DW.S_g.rw_k++;
      if (!des_supervisor_DW.S_g.rw_hit && (des_supervisor_DW.S_g.rw_k > 200.0))
      {
        des_supervisor_DW.S_g.rw_k = -1.0;
      }
    }
  }

  a__1 = (des_supervisor_DW.S_g.dis_k >= 500.0);
  if (on) {
    if (des_supervisor_DW.S_g.on_k > 10.0) {
      des_supervisor_DW.S_g.buf = fmin(5.0, des_supervisor_DW.S_g.buf + 0.01);
    }
  } else {
    des_supervisor_DW.S_g.buf = fmax(0.0, des_supervisor_DW.S_g.buf - 0.01);
  }

  if (a__1 || (des_supervisor_DW.S_g.buf <= 1.0E-9)) {
    des_supervisor_DW.S_g.latched = true;
  }

  if (des_supervisor_DW.S_g.latched && !a__1 && (des_supervisor_DW.S_g.buf >=
       0.999999999) && (des_supervisor_DW.S_g.on_k >= 20.0)) {
    des_supervisor_DW.S_g.latched = false;
  }

  if (des_supervisor_DW.S_g.dis_prev && !des_supervisor_DW.S_g.latched) {
    des_supervisor_DW.S_g.rw_k = 0.0;
    des_supervisor_DW.S_g.rw_hit = false;
  }

  des_supervisor_DW.S_g.dis_prev = des_supervisor_DW.S_g.latched;

  /* Outport: '<Root>/dis_sel' incorporates:
   *  MATLAB Function: '<S2>/Detector'
   */
  des_supervisor_Y.dis_sel = des_supervisor_DW.S_g.latched;

  /* Chart: '<S2>/Escalation' incorporates:
   *  Inport: '<Root>/driver_action'
   *  Inport: '<Root>/reset'
   *  Outport: '<Root>/dis_sel'
   */
  des_supervisor_Escalation(des_supervisor_Y.dis_sel,
    des_supervisor_U.driver_action, des_supervisor_U.reset,
    &des_supervisor_B.sf_Escalation_d, &des_supervisor_DW.sf_Escalation_d);

  /* Outport: '<Root>/esc_sel' */
  des_supervisor_Y.esc_sel = des_supervisor_B.sf_Escalation_d.esc;

  /* Outport: '<Root>/metric_sel' incorporates:
   *  MATLAB Function: '<S2>/Detector'
   */
  des_supervisor_Y.metric_sel = des_supervisor_DW.S_g.buf;

  /* Outport: '<Root>/gaze_on' */
  des_supervisor_Y.gaze_on = rtb_gaze_on;

  /* Outport: '<Root>/frozen' */
  des_supervisor_Y.frozen = rtb_frozen;
}

/* Model initialize function */
void des_supervisor_initialize(void)
{
  /* Registration code */

  /* initialize error status */
  rtmSetErrorStatus(des_supervisor_M, (NULL));

  /* block I/O */
  (void) memset(((void *) &des_supervisor_B), 0,
                sizeof(B_des_supervisor_T));

  /* states (dwork) */
  (void) memset((void *)&des_supervisor_DW, 0,
                sizeof(DW_des_supervisor_T));

  /* external inputs */
  (void)memset(&des_supervisor_U, 0, sizeof(ExtU_des_supervisor_T));

  /* external outputs */
  (void)memset(&des_supervisor_Y, 0, sizeof(ExtY_des_supervisor_T));

  /* SystemInitialize for MATLAB Function: '<Root>/InputStage' */
  memset(&des_supervisor_DW.SI.yb[0], 0, 3000U * sizeof(real_T));
  memset(&des_supervisor_DW.SI.pb[0], 0, 3000U * sizeof(real_T));
  des_supervisor_DW.SI.idx = 1.0;
  des_supervisor_DW.SI.cnt = 0.0;

  /* SystemInitialize for MATLAB Function: '<S1>/Detector' */
  des_supervisor_DW.S.on_k = 0.0;
  des_supervisor_DW.S.dis_k = 0.0;
  des_supervisor_DW.S.rw_k = -1.0;
  des_supervisor_DW.S.rw_hit = false;
  des_supervisor_DW.S.dis_prev = false;
  des_supervisor_DW.S.latched = false;
  memset(&des_supervisor_DW.S.hist[0], 0, 6000U * sizeof(boolean_T));
  des_supervisor_DW.S.hist_idx = 1.0;
  des_supervisor_DW.S.cum_k = 0.0;
  des_supervisor_DW.S.buf = 5.0;
  des_supervisor_DW.S.esc = 0U;
  des_supervisor_DW.S.esc_k = 0.0;

  /* SystemInitialize for Chart: '<S1>/Escalation' */
  des_supervisor_Escalation_Init(&des_supervisor_B.sf_Escalation,
    &des_supervisor_DW.sf_Escalation);

  /* SystemInitialize for MATLAB Function: '<S2>/Detector' */
  des_supervisor_DW.S_g.on_k = 0.0;
  des_supervisor_DW.S_g.dis_k = 0.0;
  des_supervisor_DW.S_g.rw_k = -1.0;
  des_supervisor_DW.S_g.rw_hit = false;
  des_supervisor_DW.S_g.dis_prev = false;
  des_supervisor_DW.S_g.latched = false;
  memset(&des_supervisor_DW.S_g.hist[0], 0, 6000U * sizeof(boolean_T));
  des_supervisor_DW.S_g.hist_idx = 1.0;
  des_supervisor_DW.S_g.cum_k = 0.0;
  des_supervisor_DW.S_g.buf = 5.0;
  des_supervisor_DW.S_g.esc = 0U;
  des_supervisor_DW.S_g.esc_k = 0.0;

  /* SystemInitialize for Chart: '<S2>/Escalation' */
  des_supervisor_Escalation_Init(&des_supervisor_B.sf_Escalation_d,
    &des_supervisor_DW.sf_Escalation_d);
}

/* Model terminate function */
void des_supervisor_terminate(void)
{
  /* (no terminate code required) */
}
