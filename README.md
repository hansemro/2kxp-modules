Building A Kernel Module for Siglent SDS2000X+
==============================================

# Build steps

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

7. Use [extract-symvers](https://github.com/bol-van/extract-symvers-ng) to extract Module.symvers from kernel image and save it as `./Module.symvers.scope`:

```
[PC] $ python2 extract-symvers.py -b 32 -B 0x40008000 mtd1.bin > Module.symvers.scope
```

8. Source Xilinx SDK (2017.2) shell environment (provides arm toolchain) and set `ARCH` and `CROSS_COMPILE` environment variables:

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

10. Run `make` inside this repo directory to build the kernel module (`hello.ko`):

```
[PC] $ cd ..
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
