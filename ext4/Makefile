obj-m = ext4.o mbcache.o jbd2.o

ext4-y  := balloc.o bitmap.o dir.o file.o fsync.o ialloc.o inode.o page-io.o \
	ioctl.o namei.o super.o symlink.o hash.o resize.o extents.o \
	ext4_jbd2.o migrate.o mballoc.o block_validity.o move_extent.o \
	mmp.o indirect.o extents_status.o xattr.o xattr_user.o \
	xattr_trusted.o inline.o

jbd2-objs := transaction.o commit.o recovery.o checkpoint.o revoke.o journal.o

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
	#modprobe --dump-modversions *.ko

.PHONY: clean
clean:
	make -C $(KERNEL_SOURCE)/ M=$(PWD) clean
