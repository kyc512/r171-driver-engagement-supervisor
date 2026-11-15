# RPi5 빌드:  make            (터미널 출력만)
#             make GPIO=1     (LED/부저, libgpiod v2 필요: sudo apt install libgpiod-dev)
# 생성 코드 위치는 ../codegen (MATLAB에서 build_system.m 실행 결과)

CODEGEN ?= ../codegen
include $(CODEGEN)/des_build.mk

CC      ?= gcc
CFLAGS  ?= -O2 -Wall -std=gnu11
CPPFLAGS += -I. -I$(CODEGEN) $(DES_GEN_DEFS)
LDLIBS  += -lm

ifeq ($(GPIO),1)
CPPFLAGS += -DUSE_GPIOD
LDLIBS   += -lgpiod
endif

SRCS = des_main.c des_app.c $(addprefix $(CODEGEN)/,$(DES_GEN_SRCS))

des_main: $(SRCS) des_app.h $(CODEGEN)/des_config.h $(CODEGEN)/des_build.mk
	$(CC) $(CPPFLAGS) $(CFLAGS) -o $@ $(SRCS) $(LDLIBS)

clean:
	rm -f des_main

.PHONY: clean
