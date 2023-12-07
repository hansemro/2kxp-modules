obj-m = hello.o

KERNEL_SOURCE ?= linux

.PHONY: all
all: hello.ko

hello.ko:
	rm -f $(KERNEL_SOURCE)/Module.symvers Module.symvers
	cp Module.symvers.scope $(KERNEL_SOURCE)/Module.symvers
	cp Module.symvers.scope ./Module.symvers
	make -C $(KERNEL_SOURCE)/ M=$(PWD) modules
	modprobe --dump-modversions hello.ko

.PHONY: clean
clean:
	make -C $(KERNEL_SOURCE)/ M=$(PWD) clean
