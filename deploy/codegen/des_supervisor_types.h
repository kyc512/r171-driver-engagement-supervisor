/*
 * des_supervisor_types.h
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

#ifndef des_supervisor_types_h_
#define des_supervisor_types_h_
#include "rtwtypes.h"

/* Custom Type definition for MATLAB Function: '<S2>/Detector' */
#ifndef struct_tag_sy1lTioUZJo0M6YAm8GF4aH
#define struct_tag_sy1lTioUZJo0M6YAm8GF4aH

struct tag_sy1lTioUZJo0M6YAm8GF4aH
{
  real_T on_k;
  real_T dis_k;
  real_T rw_k;
  boolean_T rw_hit;
  boolean_T dis_prev;
  boolean_T latched;
  boolean_T hist[6000];
  real_T hist_idx;
  real_T cum_k;
  real_T buf;
  uint8_T esc;
  real_T esc_k;
};

#endif                                 /* struct_tag_sy1lTioUZJo0M6YAm8GF4aH */

#ifndef typedef_sy1lTioUZJo0M6YAm8GF4aH_des_s_T
#define typedef_sy1lTioUZJo0M6YAm8GF4aH_des_s_T

typedef struct tag_sy1lTioUZJo0M6YAm8GF4aH sy1lTioUZJo0M6YAm8GF4aH_des_s_T;

#endif                             /* typedef_sy1lTioUZJo0M6YAm8GF4aH_des_s_T */

/* Custom Type definition for MATLAB Function: '<Root>/InputStage' */
#ifndef struct_tag_sV1yTgjbMsFW1fpNwstqLxB
#define struct_tag_sV1yTgjbMsFW1fpNwstqLxB

struct tag_sV1yTgjbMsFW1fpNwstqLxB
{
  real_T yb[3000];
  real_T pb[3000];
  real_T idx;
  real_T cnt;
};

#endif                                 /* struct_tag_sV1yTgjbMsFW1fpNwstqLxB */

#ifndef typedef_sV1yTgjbMsFW1fpNwstqLxB_des_s_T
#define typedef_sV1yTgjbMsFW1fpNwstqLxB_des_s_T

typedef struct tag_sV1yTgjbMsFW1fpNwstqLxB sV1yTgjbMsFW1fpNwstqLxB_des_s_T;

#endif                             /* typedef_sV1yTgjbMsFW1fpNwstqLxB_des_s_T */

/* Forward declaration for rtModel */
typedef struct tag_RTM_des_supervisor_T RT_MODEL_des_supervisor_T;

#endif                                 /* des_supervisor_types_h_ */
