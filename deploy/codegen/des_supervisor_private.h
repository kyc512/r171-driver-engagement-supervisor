/*
 * des_supervisor_private.h
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

#ifndef des_supervisor_private_h_
#define des_supervisor_private_h_
#include "rtwtypes.h"
#include "multiword_types.h"
#include "des_supervisor.h"
#include "des_supervisor_types.h"

extern void des_supervisor_Escalation_Init(B_Escalation_des_supervisor_T *localB,
  DW_Escalation_des_supervisor_T *localDW);
extern void des_supervisor_Escalation(boolean_T rtu_disengaged, boolean_T
  rtu_driver_action, boolean_T rtu_reset, B_Escalation_des_supervisor_T *localB,
  DW_Escalation_des_supervisor_T *localDW);

#endif                                 /* des_supervisor_private_h_ */
