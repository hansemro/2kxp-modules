obj-m = mii.o
obj-m += usbnet.o
obj-m += ax88179_178a.o

# Path to kernel source tree
KERNEL_SOURCE ?= $(PWD)/../linux
# Path to recovered Modules.symvers file
MODULE_SYMVERS ?= $(PWD)/../Module.symvers.scope

.PHONY: all
all:
	test -e $(MODULE_SYMVERS)
	rm -f $(KERNEL_SOURCE)/Module.symvers
	cp $(MODULE_SYMVERS) $(KERNEL_SOURCE)/Module.symvers
	make -C $(KERNEL_SOURCE)/ M=$(PWD) modules
	modprobe --dump-modversions *.ko

.PHONY: clean
clean:
	make -C $(KERNEL_SOURCE)/ M=$(PWD) clean
