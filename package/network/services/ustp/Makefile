#
# Copyright (C) 2021 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=ustp
PKG_RELEASE:=1

PKG_SOURCE_URL:=https://github.com/AlbrechtL/openwrt-ustp.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_DATE:=2026-04-21
PKG_SOURCE_VERSION:=f122c96e7db666ccd3dd62ee5f2bb435ff941db2
PKG_MIRROR_HASH:=skip

PKG_MAINTAINER:=Felix Fietkau <nbd@nbd.name>
PKG_LICENSE:=GPL-2.0

PKG_BUILD_FLAGS:=lto

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/ustp
  SECTION:=net
  CATEGORY:=Network
  TITLE:=OpenWrt STP/RSTP daemon
  DEPENDS:=+libubox +libubus
endef

TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include

define Package/ustp/install
	$(INSTALL_DIR) $(1)/sbin $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ipkg-install/sbin/* $(1)/sbin/
	$(INSTALL_BIN) ./files/ustpd.init $(1)/etc/init.d/ustpd
endef

$(eval $(call BuildPackage,ustp))
