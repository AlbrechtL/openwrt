# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2012-2014 OpenWrt.org

include $(TOPDIR)/rules.mk

ARCH:=arm
BOARD:=lan966x
BOARDNAME:=Microchip LAN9668 Development Board
FEATURES:=dt-overlay fpu squashfs targz rootfs-part
CPU_TYPE:=cortex-a8
CPU_SUBTYPE:=vfpv3
SUBTARGETS:=generic

KERNEL_PATCHVER:=6.12

KERNELNAME:=zImage dtbs

define Target/Description
	Microchip LAN9668 Development Board
endef

include $(INCLUDE_DIR)/target.mk

DEFAULT_PACKAGES += partx-utils mkf2fs e2fsprogs

$(eval $(call BuildTarget))
