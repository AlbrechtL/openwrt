# Special device RTL8380MI test

Here we are working with a special device that uses an RTL8380MI SoC. You need to have serial access to the device.

1. Fix U-Boot environment
Originally, the U-Boot environment is broken (CRC error). Fix it with:

```
RTL838x# saveenv
```

2. Check the original partition layout. OpenWrt will overwrite it, but you will not see it here.

```
RTL838x# flshow
=============== FLASH Partition Layout ===============
Index  Name       Size       Address
------------------------------------------------------
 0     LOADER     0xe0000    0xb4000000-0xb40dffff
 1     BDINFO     0x10000    0xb40e0000-0xb40effff
 2     SYSINFO    0x10000    0xb40f0000-0xb40fffff
 3     JFFS2_CFG  0x100000   0xb4100000-0xb41fffff
 4     JFFS2_LOG  0x100000   0xb4200000-0xb42fffff
 5     RUNTIME1   0x680000   0xb4300000-0xb497ffff
 6     RUNTIME2   0x680000   0xb4980000-0xb4ffffff
======================================================
```

3. Get the initramfs image via TFTP and boot
```
RTL838x# tftpboot 0x8f000000 192.168.1.12:openwrt.bin
Using rtl8380#0 device
TFTP from server 192.168.1.12; our IP address is 192.168.1.1
Filename 'openwrt.bin'.
Load address: 0x8f000000
Loading: #################################################################
	 #################################################################
	 #################################################################
	 #################################################################
	 #################################################################
	 ########################
done
Bytes transferred = 5111943 (4e0087 hex)

RTL838x# bootm
## Booting kernel from Legacy Image at 8f000000 ...
   Image Name:   MIPS OpenWrt Linux-6.18.21
   Created:      2026-06-10  21:16:55 UTC
   Image Type:   MIPS Linux Kernel Image (uncompressed)
   Data Size:    5111879 Bytes = 4.9 MB
   Load Address: 80100000
   Entry Point:  80100000
   Verifying Checksum ... OK
   Loading Kernel Image ... OK
OK

Starting kernel ...
[...]
```

4. OpenWrt now runs from RAM

5. Copy the `squashfs-sysupgrade.bin` image to the OpenWrt device

```
scp -O openwrt-realtek-rtl838x-albrecht_rtl8382mi-test-squashfs-sysupgrade.bin root@192.168.1.1:/tmp
```

6. Flash it

```
root@OpenWrt:~# sysupgrade -v /tmp/openwrt-realtek-rtl838x-albrecht_rtl8382mi-test-squashfs-sysupgrade.bin
```

7. OpenWrt should reboot automatically, and OpenWrt is now installed on the device.

## Ethernet port LEDs

```
ls /sys/kernel/debug/rtl838x/led
led0_sw_p_en_ctrl  led_sw_p_ctrl.01   led_sw_p_ctrl.10   led_sw_p_ctrl.19
led1_sw_p_en_ctrl  led_sw_p_ctrl.02   led_sw_p_ctrl.11   led_sw_p_ctrl.20
led2_sw_p_en_ctrl  led_sw_p_ctrl.03   led_sw_p_ctrl.12   led_sw_p_ctrl.21
led_glb_ctrl       led_sw_p_ctrl.04   led_sw_p_ctrl.13   led_sw_p_ctrl.22
led_mode_ctrl      led_sw_p_ctrl.05   led_sw_p_ctrl.14   led_sw_p_ctrl.23
led_mode_sel       led_sw_p_ctrl.06   led_sw_p_ctrl.15   led_sw_p_ctrl.24
led_p_en_ctrl      led_sw_p_ctrl.07   led_sw_p_ctrl.16   led_sw_p_ctrl.25
led_sw_ctrl        led_sw_p_ctrl.08   led_sw_p_ctrl.17   led_sw_p_ctrl.26
led_sw_p_ctrl.00   led_sw_p_ctrl.09   led_sw_p_ctrl.18   led_sw_p_ctrl.27
```

**u-boot correct values**
```sh
led_glb_ctrl         0x2f396a3f
led_mode_sel         0x00000000
led_mode_ctrl        0x00001d00
led_p_en_ctrl        0x0500ffff
led_sw_ctrl          0x00000000
led0_sw_p_en_ctrl    0x00000000
led1_sw_p_en_ctrl    0x00000000
led2_sw_p_en_ctrl    0x00000000
```

**enable LEDs in Linux (workaround)**
```sh
echo 0x2f396a3f > /sys/kernel/debug/rtl838x/led/led_glb_ctrl
echo 0x00001d00 > /sys/kernel/debug/rtl838x/led/led_mode_ctrl
echo 0x0500ffff > /sys/kernel/debug/rtl838x/led/led_p_en_ctrl
```

**Enable manual LED control**
```sh
echo 0x0500ffff > /sys/kernel/debug/rtl838x/led/led0_sw_p_en_ctrl
echo 0x0500ffff > /sys/kernel/debug/rtl838x/led/led1_sw_p_en_ctrl
echo 0x1 > /sys/kernel/debug/rtl838x/led/led_sw_p_ctrl.05
echo 0xFF > /sys/kernel/debug/rtl838x/led/led_sw_p_ctrl.05
```

**Disable manual LED control**
```sh
echo 0x00000000 > /sys/kernel/debug/rtl838x/led/led0_sw_p_en_ctrl
echo 0x00000000 > /sys/kernel/debug/rtl838x/led/led1_sw_p_en_ctrl
```

## DIP switches
```sh
root@OpenWrt:~# ls /sys/firmware/devicetree/base/keys
```

On this board, DIP switches are exposed as button events (`BTN_0` to `BTN_4`).
`dip-switch-5` is mapped to `KEY_RESTART`, so OpenWrt handles it via `/etc/rc.button/reset`.

Button scripts are installed at:
```sh
/etc/rc.button/BTN_0
/etc/rc.button/BTN_1
/etc/rc.button/BTN_2
/etc/rc.button/BTN_3
/etc/rc.button/BTN_4
```

Verify events while toggling DIP switches:
```sh
logread -f | grep BTN_
```

### BTN_5 reset/factory-reset behavior

`dip-switch-5` uses the default reset handler:
```sh
/etc/rc.button/reset
```

Behavior on release:
* short switch cycle (`SEEN < 1`): reboot
* long switch cycle (`SEEN >= 5`): factory reset and reboot

## Manual DHCP config

```sh
uci set network.lan.proto="dhcp"
uci commit network
service network restart
```

## Known bugs
* MAC addresses are not set correctly
* Ethernet port LEDs are too late initilized in u-boot and no RTL838x serial shift register driver implemented in Linux driver. Workaround implemented in /etc/init.d/rtl838x_leds

## Event LED flashing behavior
For this board, ethernet port LEDs are flashed continuously during:
* reboot
* factory reset reboot
* sysupgrade

The hardware blinking is triggered by the sequence below from:
* `/etc/init.d/rtl838x_leds` stop() during shutdown
* `platform_pre_upgrade()` in `target/linux/realtek/base-files/lib/upgrade/platform.sh`

```sh
echo 0x0500ffff > /sys/kernel/debug/rtl838x/led/led0_sw_p_en_ctrl
echo 0x0500ffff > /sys/kernel/debug/rtl838x/led/led1_sw_p_en_ctrl
for p in $(seq 1 16); do
   echo 0x9 > /sys/kernel/debug/rtl838x/led/led_sw_p_ctrl.$(printf '%02d' "$p")
done
```

To verify after boot:
```sh
cat /sys/kernel/debug/rtl838x/led/led0_sw_p_en_ctrl
cat /sys/kernel/debug/rtl838x/led/led1_sw_p_en_ctrl
cat /sys/kernel/debug/rtl838x/led/led_sw_p_ctrl.01
cat /sys/kernel/debug/rtl838x/led/led_sw_p_ctrl.16
```