CROSS_COMPILE ?= arm-linux-gnueabihf-
ARCH ?= arm
KERNEL_DIR = $(shell pwd)/../../linux-fslc
obj-m := drv_led.o
CURRENT_PATH = $(shell pwd)

build:
	$(MAKE) -C $(KERNEL_DIR) M=$(CURRENT_PATH) modules ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE)

clean:
	$(MAKE) -C $(KERNEL_DIR) M=$(CURRENT_PATH) clean
