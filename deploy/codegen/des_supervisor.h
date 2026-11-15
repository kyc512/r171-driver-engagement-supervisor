/*
 * des_supervisor.h
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

#ifndef des_supervisor_h_
#define des_supervisor_h_
#ifndef des_supervisor_COMMON_INCLUDES_
#define des_supervisor_COMMON_INCLUDES_
#include "rtwtypes.h"
#include "rtw_continuous.h"
#include "rtw_solver.h"
#endif                                 /* des_supervisor_COMMON_INCLUDES_ */

#include "des_supervisor_types.h"
#include <stddef.h>
#include <string.h>

/* Macros for accessing real-time model data structure */
#ifndef rtmGetErrorStatus
#define rtmGetErrorStatus(rtm)         ((rtm)->errorStatus)
#endif

#ifndef rtmSetErrorStatus
#define rtmSetErrorStatus(rtm, val)    ((rtm)->errorStatus = (val))
#endif

/* Block signals for system '<S1>/Escalation' */
typedef struct {
  uint8_T esc;                         /* '<S1>/Escalation' */
} B_Escalation_des_supervisor_T;

/* Block states (default storage) for system '<S1>/Escalation' */
typedef struct {
  uint16_T temporalCounter_i1;         /* '<S1>/Escalation' */
  uint8_T is_c3_des_supervisor;        /* '<S1>/Escalation' */
} DW_Escalation_des_supervisor_T;

/* Block signals (default storage) */
typedef struct {
  B_Escalation_des_supervisor_T sf_Escalation_d;/* '<S2>/Escalation' */
  B_Escalation_des_supervisor_T sf_Escalation;/* '<S1>/Escalation' */
} B_des_supervisor_T;

/* Block states (default storage) for system '<Root>' */
typedef struct {
  sV1yTgjbMsFW1fpNwstqLxB_des_s_T SI;  /* '<Root>/InputStage' */
  sy1lTioUZJo0M6YAm8GF4aH_des_s_T S;   /* '<S1>/Detector' */
  sy1lTioUZJo0M6YAm8GF4aH_des_s_T S_g; /* '<S2>/Detector' */
  DW_Escalation_des_supervisor_T sf_Escalation_d;/* '<S2>/Escalation' */
  DW_Escalation_des_supervisor_T sf_Escalation;/* '<S1>/Escalation' */
} DW_des_supervisor_T;

/* External inputs (root inport signals with default storage) */
typedef struct {
  boolean_T valid;                     /* '<Root>/valid' */
  real_T yaw;                          /* '<Root>/yaw' */
  real_T pitch;                        /* '<Root>/pitch' */
  boolean_T driver_action;             /* '<Root>/driver_action' */
  boolean_T reset;                     /* '<Root>/reset' */
} ExtU_des_supervisor_T;

/* External outputs (root outports fed by signals with default storage) */
typedef struct {
  uint8_T esc_m0;                      /* '<Root>/esc_m0' */
  boolean_T dis_m0;                    /* '<Root>/dis_m0' */
  real_T metric_m0;                    /* '<Root>/metric_m0' */
  uint8_T esc_sel;                     /* '<Root>/esc_sel' */
  boolean_T dis_sel;                   /* '<Root>/dis_sel' */
  real_T metric_sel;                   /* '<Root>/metric_sel' */
  boolean_T gaze_on;                   /* '<Root>/gaze_on' */
  boolean_T frozen;                    /* '<Root>/frozen' */
} ExtY_des_supervisor_T;

/* Real-time Model Data Structure */
struct tag_RTM_des_supervisor_T {
  const char_T *errorStatus;
};

/* Block signals (default storage) */
extern B_des_supervisor_T des_supervisor_B;

/* Block states (default storage) */
extern DW_des_supervisor_T des_supervisor_DW;

/* External inputs (root inport signals with default storage) */
extern ExtU_des_supervisor_T des_supervisor_U;

/* External outputs (root outports fed by signals with default storage) */
extern ExtY_des_supervisor_T des_supervisor_Y;

/* Model entry point functions */
extern void des_supervisor_initialize(void);
extern void des_supervisor_step(void);
extern void des_supervisor_terminate(void);

/* Real-time Model object */
extern RT_MODEL_des_supervisor_T *const des_supervisor_M;

/*-
 * The generated code includes comments that allow you to trace directly
 * back to the appropriate location in the model.  The basic format
 * is <system>/block_name, where system is the system number (uniquely
 * assigned by Simulink) and block_name is the name of the block.
 *
 * Use the MATLAB hilite_system command to trace the generated code back
 * to the model.  For example,
 *
 * hilite_system('<S3>')    - opens system 3
 * hilite_system('<S3>/Kp') - opens and selects block Kp which resides in S3
 *
 * Here is the system hierarchy for this model
 *
 * '<Root>' : 'des_supervisor'
 * '<S1>'   : 'des_supervisor/Ch_M0'
 * '<S2>'   : 'des_supervisor/Ch_M3'
 * '<S3>'   : 'des_supervisor/InputStage'
 * '<S4>'   : 'des_supervisor/Ch_M0/Detector'
 * '<S5>'   : 'des_supervisor/Ch_M0/Escalation'
 * '<S6>'   : 'des_supervisor/Ch_M3/Detector'
 * '<S7>'   : 'des_supervisor/Ch_M3/Escalation'
 */
#endif                                 /* des_supervisor_h_ */
