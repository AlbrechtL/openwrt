# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2012-2014 OpenWrt.org

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

define Build/gen-image
#	rm -f $@.boot
	./post-image.sh
#	rm -f $@.boot
endef

define Device/Default
  PROFILES := Default
  KERNEL_NAME := zImage
  KERNEL := kernel-bin
  DTS_DIR := $(DTS_DIR)/microchip
  DEVICE_DTS = $(lastword $(subst _, ,$(1)))
  IMAGES := sdcard.img
  IMAGE/sdcard.img := gen-image | append-metadata
endef

define Device/mchp_lan966x-pcb8290
  DEVICE_VENDOR := Microchip
  DEVICE_MODEL := LAN9668 EVB
endef

TARGET_DEVICES += mchp_lan966x-pcb8290

$(eval $(call BuildImage))
