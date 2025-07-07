#!/usr/bin/env bash

soc="lan966x"
BINARIES_DIR=$(pwd)

# Remove the first argument which is the path to the +images+ output directory
shift

# The rest of the arguments comes from +BR2_ROOTFS_POST_SCRIPT_ARGS+
# Add the types to generate in +BR2_ROOTFS_POST_SCRIPT_ARGS+ separated by space

# all tergets are by default if +BR2_ROOTFS_POST_SCRIPT_ARGS+ is empty
if [[ $# -eq 0 ]]; then
    types="itb-rootfs"
else
    types="$@"
fi

for type in $types
do
    case $type in
	"itb-rootfs")
	    echo "Generate fit.itb..."
		export
	    ./imggen.rb \
		-s $soc \
		-t $type \
		-k /home/albrecht/src/openwrt/build_dir/target-arm_cortex-a8+vfpv3_musl_eabi/linux-lan966x_generic/mchp_lan966x-pcb8290-kernel.bin \
		-d /home/albrecht/src/openwrt/build_dir/target-arm_cortex-a8+vfpv3_musl_eabi/linux-lan966x_generic/image-lan966x-pcb8290.dtb,lan9668_ung8290_0_at_lan966x \
		-r /home/albrecht/src/openwrt/bin/targets/lan966x/generic/openwrt-lan966x-generic-default-rootfs.tar.gz \
		-o $BINARIES_DIR \
		-n fit
	    ;;
	"itb-initramfs")
	    echo "error: Generate $type not supported!" 1>&2
	    ;;
	"itb-bare")
	    echo "Generate itb-bare..."
	    ./imggen.rb \
		-s $soc \
		-t $type \
		-k $BINARIES_DIR/mscc-linux-kernel.bin \
		-d $BINARIES_DIR/lan966x-pcb8291.dtb,lan9662_ung8291_0_at_lan966x \
		-d $BINARIES_DIR/lan966x-pcb8290.dtb,lan9668_ung8290_0_at_lan966x \
		-d $BINARIES_DIR/lan966x-pcb8281.dtb,lan9668_ung8281_0_at_lan966x \
		-d $BINARIES_DIR/lan966x-pcb8281-rgmii.dtb,lan9668_ung8281_rgmii_0_at_lan966x \
		-d $BINARIES_DIR/lan966x-pcb8309.dtb,lan9662_ung8309_0_at_lan966x \
		-d $BINARIES_DIR/lan966x-pcb8385.dtb,lan9668_ung8385_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_int_lan8804.dtbo,lan9668_ung8385_int_lan8804_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_lan8814.dtbo,lan9668_ung8385_sa_lan8814_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_lan8814_ext_clk.dtbo,lan9668_ung8385_sa_lan8814_ext_clk_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_lan8818.dtbo,lan9668_ung8385_sa_lan8818_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_lan8814.dtbo,lan9668_ung8385_sb_lan8814_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_lan8814_ext_clk.dtbo,lan9668_ung8385_sb_lan8814_ext_clk_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_lan8818.dtbo,lan9668_ung8385_sb_lan8818_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_lan8840.dtbo,lan9668_ung8385_sa_lan8840_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_lan8840.dtbo,lan9668_ung8385_sb_lan8840_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_lan8842.dtbo,lan9668_ung8385_sa_lan8842_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_lan8842.dtbo,lan9668_ung8385_sb_lan8842_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_ksz9131.dtbo,lan9668_ung8385_sa_ksz9131_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_ksz9131.dtbo,lan9668_ung8385_sb_ksz9131_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_vsc8574.dtbo,lan9668_ung8385_sa_vsc8574_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_vsc8574.dtbo,lan9668_ung8385_sb_vsc8574_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8290_fc0_i2c.dtbo,lan9668_ung8290_fc0_i2c_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8290_fc1_i2c.dtbo,lan9668_ung8290_fc1_i2c_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8309_qspi_rte.dtbo,lan9662_ung8309_qspi_rte_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8291_fc2_spi.dtbo,lan966x_pcb8291_fc2_spi_0_at_lan966x \
		-o $BINARIES_DIR
	    ;;
	"ext4-itb-bare")
	    echo "Generate ext4-itb-bare..."
	    ./imggen.rb \
		-s $soc \
		-t $type \
		-k $BINARIES_DIR/mscc-linux-kernel.bin \
		-d $BINARIES_DIR/lan966x-pcb8291.dtb,lan9662_ung8291_0_at_lan966x \
		-d $BINARIES_DIR/lan966x-pcb8290.dtb,lan9668_ung8290_0_at_lan966x \
		-d $BINARIES_DIR/lan966x-pcb8281.dtb,lan9668_ung8281_0_at_lan966x \
		-d $BINARIES_DIR/lan966x-pcb8281-rgmii.dtb,lan9668_ung8281_rgmii_0_at_lan966x \
		-d $BINARIES_DIR/lan966x-pcb8309.dtb,lan9662_ung8309_0_at_lan966x \
		-d $BINARIES_DIR/lan966x-pcb8385.dtb,lan9668_ung8385_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_int_lan8804.dtbo,lan9668_ung8385_int_lan8804_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_lan8814.dtbo,lan9668_ung8385_sa_lan8814_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_lan8814_ext_clk.dtbo,lan9668_ung8385_sa_lan8814_ext_clk_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_lan8818.dtbo,lan9668_ung8385_sa_lan8818_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_lan8814.dtbo,lan9668_ung8385_sb_lan8814_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_lan8814_ext_clk.dtbo,lan9668_ung8385_sb_lan8814_ext_clk_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_lan8818.dtbo,lan9668_ung8385_sb_lan8818_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_lan8840.dtbo,lan9668_ung8385_sa_lan8840_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_lan8840.dtbo,lan9668_ung8385_sb_lan8840_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_lan8842.dtbo,lan9668_ung8385_sa_lan8842_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_lan8842.dtbo,lan9668_ung8385_sb_lan8842_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_lan8941.dtbo,lan9668_ung8385_sa_lan8941_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_lan8941.dtbo,lan9668_ung8385_sb_lan8941_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_ksz9131.dtbo,lan9668_ung8385_sa_ksz9131_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_ksz9131.dtbo,lan9668_ung8385_sb_ksz9131_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_vsc8574.dtbo,lan9668_ung8385_sa_vsc8574_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_vsc8574.dtbo,lan9668_ung8385_sb_vsc8574_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8290_fc0_i2c.dtbo,lan9668_ung8290_fc0_i2c_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8290_fc1_i2c.dtbo,lan9668_ung8290_fc1_i2c_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8309_qspi_rte.dtbo,lan9662_ung8309_qspi_rte_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8291_fc2_spi.dtbo,lan966x_pcb8291_fc2_spi_0_at_lan966x \
		-r $BINARIES_DIR/rootfs.tar \
		-o $BINARIES_DIR \
		-z \
		-n brsdk_standalone_arm
	    ;;
	"ext4-itb-initramfs")
	    echo "error: Generate $type not supported!" 1>&2
	    ;;
	"ext4-bare")
	    echo "Generate ext4-bare..."
	    ./imggen.rb \
		-s $soc \
		-t $type \
		-r $BINARIES_DIR/rootfs.tar \
		-o $BINARIES_DIR
	    ;;
	"ubifs-itb-bare")
	    echo "Generate ubifs-itb-bare..."
	    ./imggen.rb \
		-s $soc \
		-t $type \
		-k $BINARIES_DIR/mscc-linux-kernel.bin.gz \
		-d $BINARIES_DIR/lan966x-pcb8291.dtb,lan9662_ung8291_0_at_lan966x \
		-d $BINARIES_DIR/lan966x-pcb8290.dtb,lan9668_ung8290_0_at_lan966x \
		-d $BINARIES_DIR/lan966x-pcb8281.dtb,lan9668_ung8281_0_at_lan966x \
		-d $BINARIES_DIR/lan966x-pcb8281-rgmii.dtb,lan9668_ung8281_rgmii_0_at_lan966x \
		-d $BINARIES_DIR/lan966x-pcb8309.dtb,lan9662_ung8309_0_at_lan966x \
		-d $BINARIES_DIR/lan966x-pcb8385.dtb,lan9668_ung8385_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_int_lan8804.dtbo,lan9668_ung8385_int_lan8804_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_lan8814.dtbo,lan9668_ung8385_sa_lan8814_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_lan8814_ext_clk.dtbo,lan9668_ung8385_sa_lan8814_ext_clk_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_lan8818.dtbo,lan9668_ung8385_sa_lan8818_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_lan8814.dtbo,lan9668_ung8385_sb_lan8814_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_lan8814_ext_clk.dtbo,lan9668_ung8385_sb_lan8814_ext_clk_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_lan8818.dtbo,lan9668_ung8385_sb_lan8818_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_lan8840.dtbo,lan9668_ung8385_sa_lan8840_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_lan8840.dtbo,lan9668_ung8385_sb_lan8840_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_lan8842.dtbo,lan9668_ung8385_sa_lan8842_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_lan8842.dtbo,lan9668_ung8385_sb_lan8842_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_lan8941.dtbo,lan9668_ung8385_sa_lan8941_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_lan8941.dtbo,lan9668_ung8385_sb_lan8941_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_ksz9131.dtbo,lan9668_ung8385_sa_ksz9131_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_ksz9131.dtbo,lan9668_ung8385_sb_ksz9131_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sa_vsc8574.dtbo,lan9668_ung8385_sa_vsc8574_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8385_sb_vsc8574.dtbo,lan9668_ung8385_sb_vsc8574_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8290_fc0_i2c.dtbo,lan9668_ung8290_fc0_i2c_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8290_fc1_i2c.dtbo,lan9668_ung8290_fc1_i2c_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8309_qspi_rte.dtbo,lan9662_ung8309_qspi_rte_0_at_lan966x \
		-a $BINARIES_DIR/overlays/lan966x_pcb8291_fc2_spi.dtbo,lan966x_pcb8291_fc2_spi_0_at_lan966x \
		-r $BINARIES_DIR/rootfs.tar \
		-o $BINARIES_DIR
	    ;;
	*)
	    echo "error: Invalid type: $type!" 1>&2
	    ;;
    esac
done
