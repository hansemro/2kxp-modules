Building A Kernel Module for Siglent SDS2000X+
==============================================

This repo outlines steps to build, load/unload, and monitor kernel modules for SDS2000X+ scope
without access to the vendor kernel source tree. With some changes, one can build kernel modules
to add support for mounting EXT4 filesystems, bringing up USB Ethernet interfaces, and more.

We can build kernel modules by recovering Modules.symvers file (which contains a list of CRC values
of exported function symbols to prevent kernel ABI incompatibility) and placing it at the root of
the kernel source tree. This file can be recovered from the original kernel image and with a help
of a [script](https://github.com/bol-van/extract-symvers-ng).

## Build steps

1. Clone this repo with [linux-xlnx](https://github.com/Xilinx/linux-xlnx) submodule:

```
[PC] $ git clone [this_git_repo] 2kxp_test_module
[PC] $ cd 2kxp_test_module
[PC] $ git submodule update --init --recursive
```

2. Apply linux script patch (to fix multiple definitions of yylloc):

```
[PC] $ cd linux
[PC] $ patch -Nup1 -i ../Fix-multiple-yylloc-definition-error.patch
```

3. Get telnet shell access to scope (on 1.3.9R10/R12) if not already.

```
[PC] $ telnet <scope_address>
```

4. Get kernel image version:

```
[scope] # uname -r
3.19.0-01-svn186079
```

5. Copy kernel image (`/dev/mtd1`) and kernel config (`/proc/config.gz`):

```
[scope] # mount -o rw,remount /usr/bin/siglent/usr/mass_storage/U-disk0
[scope] # cp /dev/mtd1 /usr/bin/siglent/usr/mass_storage/U-disk0/mtd1.bin
[scope] # cp /proc/config.gz /usr/bin/siglent/usr/mass_storage/U-disk0/
```

6. Locate address of `_text` from /proc/kallsyms:

```
[scope] # grep _text /proc/kallsyms | head -n1
40008000 T _text
```

7. Use [extract-symvers](https://github.com/bol-van/extract-symvers-ng) to extract Module.symvers from kernel image and save it as `./Module.symvers.scope` under the root of this repo's directory:

```
[PC] $ python2 extract-symvers.py -b 32 -B 0x40008000 mtd1.bin > Module.symvers.scope
```

8. Source Xilinx SDK (2017.2) shell environment (provides arm toolchain), and set `ARCH` and `CROSS_COMPILE` environment variables:

```
[PC] $ source /opt/Xilinx/SDK/2017.2/settings64.sh
[PC] $ export CROSS_COMPILE=arm-xilinx-linux-gnueabi-
[PC] $ export ARCH=arm
```

9. Extract `config.gz` as .config under `./linux/` kernel source directory, and then prepare kernel headers and scripts:

```
[PC] $ cd ./linux
[PC] $ zcat config.gz > .config
[PC] $ make silentoldconfig prepare headers_install scripts
```

10. Navigate to the `hello` directory and run `make` to build the kernel module (`hello.ko`):

```
[PC] $ cd ../hello
[PC] $ make
```

## Loading the kernel module

After building the kernel module, we can copy the module to a drive, and use insmod to load it.

```
[scope] # insmod /usr/bin/siglent/usr/mass_storage/U-disk0/hello.ko
[scope] # lsmod
hello 701 0 - Live 0x3f0f3000 (O)
...
```

## Viewing kernel message logs

On SDS2000X+, `spidev` will endlessly spam kernel messages, making it hopeless to use `dmesg` to view logs. As a workaround, just filter spidev as we read from `/proc/kmsg`:

```
[scope] # grep -v spidev /proc/kmsg
```

After loading the kernel module in another telnet session, we should see live output:

```
<6>[9544.626284] Loading hello module...
<6>[9544.630104] Hello world
```

## Unloading the kernel module

On SDS2000X+, the base root filesystem is read-only including /lib/modules/, which prevents rmmod from working correctly.

```
[scope] # rmmod hello
rmmod: chdir(3.19.0-01-svn186079): No such file or directory
```

To work around this, we can mount a flash drive over /lib/modules, and recreate the directory structure and files needed:

```
[scope] # mount /usr/bin/siglent/usr/mass_storage/U-disk0
[scope] # mount -o rw /dev/sdb1 /lib/modules
[scope] # mkdir -p /lib/modules/`uname -r`
[scope] # touch /lib/modules/`uname -r`/modules.dep
[scope] # touch /lib/modules/`uname -r`/modules.dep.bb
```

After this, we can successfully load and unload kernel modules.

We can unload the module with:

```
[scope] # rmmod hello
```

This should also print the following kernel message:

```
<6>[9540.972893] Goodbye world
```

## Building kernel driver module for USB gigabit ethernet adapter support

This short guide demonstrates how to support [Amazon Basics USB 3.0 Gigabit Ethernet Adapter](https://www.amazon.com/AmazonBasics-1000-Gigabit-Ethernet-Adapter/dp/B00M77HMU0)
for the SDS2000X+ scope. This particular adapter uses AX88179 USB-Ethernet controller, which has
its own kernel driver `ax88179_178a`.

To build this module, let's copy hello directory as a template, and create a link to `ax88179_178a.c`:

```
[PC] $ make -C hello clean
[PC] $ cp -r hello usb_eth
[PC] $ cd usb_eth
[PC] $ ln -s ../linux/drivers/net/usb/ax88179_178a.c .
```

Then add/set `ax88179_178a.o` object entry as shown in the following Makefile diff:

```patch
  obj-m = hello.o
+ obj-m += ax88179_178a.o
```

Running make reveals some unhandled references to `usbnet.c` and `mii.c`, so add their links and Makefile entries.

```
[PC] $ ln -s ../linux/drivers/net/usb/usbnet.c .
[PC] $ ln -s ../linux/drivers/net/mii.c .
```

```patch
  obj-m = hello.o
+ obj-m += mii.o
+ obj-m += usbnet.o
  obj-m += ax88179_178a.o
```

Run `make`, copy the .ko files to the scope, and load them with insmod:

```
[scope] # insmod mii.ko
[scope] # insmod usbnet.ko
[scope] # insmod ax88179_178a.ko
```

Once loaded, the USB ethernet adapter can now be detected successfully as `eth1`:

```
[scope] # ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast qlen 1000
    link/ether 74:5b:c5:22:79:59 brd ff:ff:ff:ff:ff:ff
    inet 169.254.149.18/16 brd 169.254.255.255 scope global eth0
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast qlen 1000
    link/ether 00:50:b6:20:f5:5d brd ff:ff:ff:ff:ff:ff
```
