CC = $(CROSS_COMPILE)gcc
CPPFLAGS += -Iinclude -Iapp
CFLAGS ?= -O2 -g
CFLAGS += -std=c11 -Wall -Wextra -Wpedantic -Werror
BUILD ?= build
.PHONY: all test
all: hcsr04-reader
$(BUILD):
	mkdir -p $@
$(BUILD)/hcsr04_driver.o: driver/hcsr04_driver.c include/hcsr04_driver.h | $(BUILD)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@
$(BUILD)/libhcsr04.a: $(BUILD)/hcsr04_driver.o
	$(AR) rcs $@ $<
hcsr04-reader: app/main.c app/distance.c app/distance.h include/hcsr04_driver.h $(BUILD)/libhcsr04.a
	$(CC) $(CPPFLAGS) $(CFLAGS) app/main.c app/distance.c $(BUILD)/libhcsr04.a $(LDFLAGS) -o $@
$(BUILD)/test-distance: tests/test_distance.c app/distance.c app/distance.h | $(BUILD)
	$(CC) $(CPPFLAGS) $(CFLAGS) tests/test_distance.c app/distance.c -lm -o $@
test: all $(BUILD)/test-distance
	./$(BUILD)/test-distance
	! ./hcsr04-reader --confirm-protected-wiring --samples=0 >/dev/null 2>&1
	! ./hcsr04-reader --samples=10 >/dev/null 2>&1
	! ./hcsr04-reader --confirm-protected-wiring --samples=1 --period-ms=60 >/dev/null 2>&1
