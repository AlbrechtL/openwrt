#
# Copyright (C) 2026
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=p-net
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/rtlabs-com/p-net.git
PKG_SOURCE_DATE:=2026-03-05
PKG_SOURCE_VERSION:=459e043a44ffc97d25065434cc5b28c330142be9
PKG_MIRROR_HASH:=skip

PKG_MAINTAINER:=
PKG_LICENSE:=GPL-3.0-only
PKG_LICENSE_FILES:=LICENSE.md

CMAKE_INSTALL:=1
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/libpnet
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=PROFINET device stack library (rt-labs p-net)
  URL:=https://github.com/rtlabs-com/p-net
  DEPENDS:=+libpthread +libpcap +libnetsnmp
endef

define Package/libpnet/description
 p-net is a PROFINET device stack for embedded systems.
 This package ships the runtime library.
 Note: Upstream is dual-licensed (GPLv3/commercial).
endef

define Package/pnet-sample
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Sample application for p-net
  URL:=https://github.com/rtlabs-com/p-net
  DEPENDS:=+libpnet +libpcap +libnetsnmp
endef

define Package/pnet-sample/description
 Sample application binary from the p-net upstream project.
endef

# Keep the build minimal for OpenWrt targets.
CMAKE_OPTIONS += \
	-DBUILD_TESTING=OFF \
	-DBUILD_TESTS=OFF \
	-DBUILD_DOCS=OFF

define Build/Compile
	if [ -d "$(PKG_BUILD_DIR)/_deps/osal-src" ] && [ ! -f "$(PKG_BUILD_DIR)/.osal_musl_patch_applied" ]; then \
		(cd "$(PKG_BUILD_DIR)/_deps/osal-src" && patch -p1 < "$(CURDIR)/files/osal-musl-compat.patch"); \
		touch "$(PKG_BUILD_DIR)/.osal_musl_patch_applied"; \
	fi
	$(call Build/Compile/Default)
endef

define Build/InstallDev
	$(call Build/InstallDev/cmake,$(1))
	$(INSTALL_DIR) $(1)/usr/include
	if [ -d "$(PKG_INSTALL_DIR)/usr/include" ]; then \
		$(CP) $(PKG_INSTALL_DIR)/usr/include/* $(1)/usr/include/; \
	fi
	$(INSTALL_DIR) $(1)/usr/lib/pkgconfig
	if [ -d "$(PKG_INSTALL_DIR)/usr/lib/pkgconfig" ]; then \
		$(CP) $(PKG_INSTALL_DIR)/usr/lib/pkgconfig/* $(1)/usr/lib/pkgconfig/; \
	fi
endef

define Package/libpnet/install
	$(INSTALL_DIR) $(1)/usr/lib
	if ls $(PKG_INSTALL_DIR)/usr/lib/libpnet.so* >/dev/null 2>&1; then \
		$(CP) $(PKG_INSTALL_DIR)/usr/lib/libpnet.so* $(1)/usr/lib/; \
	elif [ -f "$(PKG_INSTALL_DIR)/usr/lib/libprofinet.a" ]; then \
		$(CP) $(PKG_INSTALL_DIR)/usr/lib/libprofinet.a $(1)/usr/lib/; \
	fi
endef

define Package/pnet-sample/install
	$(INSTALL_DIR) $(1)/usr/bin
	if [ -x "$(PKG_INSTALL_DIR)/usr/bin/pnet_sample" ]; then \
		$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/pnet_sample $(1)/usr/bin/; \
	elif [ -x "$(PKG_INSTALL_DIR)/usr/bin/clean_no_alarm.sh" ]; then \
		$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/clean_no_alarm.sh $(1)/usr/bin/; \
		ln -sf clean_no_alarm.sh $(1)/usr/bin/pnet_sample; \
	fi
endef

$(eval $(call BuildPackage,libpnet))
$(eval $(call BuildPackage,pnet-sample))
