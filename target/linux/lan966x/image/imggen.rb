#!/usr/bin/env ruby

# Copyright (c) 2004-2021 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require 'optparse'
require 'open3'
require 'tmpdir'
require 'pp'

$opt = {
    dtbs: [],
    overlays: [],
}

TYPES = {
    "itb-rootfs" => {
        :doc         => ["ITB with kernel, one or more device trees and full",
                         "SquashFS as rootfs.",
                         "Required options are -s, -o, -k, -d and -r.",
                         "Artifact name is 'itb-rootfs.itb' unless -n is given."],
    },
    "itb-initramfs" => {
        :doc         => ["ITB with kernel, one or more device trees and small",
                         "SquashFS as initramfs containing stage2-loader.",
                         "Required options are -s, -o, -k, -d and -i.",
                         "Artifact name is 'itb-initramfs.itb' unless -n is given."],
    },
    "itb-bare" => {
        :doc         => ["ITB with kernel, one or more device trees and no filesystem.",
                         "Required options are -s, -o, -k and -d.",
                         "Artifact name is 'itb-bare.itb' unless -n is given."],
    },
    "ext4-itb-bare" => {
        :doc         => ["EXT4 filesystem containing an itb-bare in the boot folder.",
                         "Required options are -s, -o, -k, -d and -r.",
                         "Artifact name is 'ext4-itb-bare.ext4' unless -n is given."],
    },
    "ext4-itb-initramfs" => {
        :doc         => ["EXT4 filesystem containing an itb-initramfs in the boot folder.",
                         "Required options are -s, -o, -k , -d, -r and -i.",
                         "Artifact name is 'ext4-itb-initramfs.ext4' unless -n is given."],
    },
    "ext4-bare" => {
        :doc         => ["EXT4 filesystem without anything in the boot folder.",
                         "Required options are -s, -o and -r.",
                         "Artifact name is 'ext4-bare.ext4' unless -n is given."],
    },
    "ubifs-itb-bare" => {
        :doc         => ["UBIFS filesystem containing an itb-bare in the root folder.",
                         "Required options are -s, -o, -k, -d and -r.",
                         "Artifact name is 'ubifs-itb-bare.ubifs' unless -n is given."],
    },
}

SOCS = {
    "lan966x" => {
        :doc         => ["Systems using the internal CPU in lan996x."],
        :arch        => "arm",
        :kerneladdr  => "<0x60208000>",
        :kernelentry => "<0x60208000>",
        :ramdiskaddr => "<0x68000000>",
        :dtbaddr     => "<0x67e00000>",
        :overlayaddr => "<0x67e80000>",
        :kcomp       => "none",
        :fw_env      => "/dev/mtd2 0x0000 0x40000 0x40000\n/dev/mtd3 0x0000 0x40000 0x40000\n",
    },
    "ls1046a" => {
        :doc         => ["Systems using ls1046a as external CPU."],
        :arch        => "arm64",
        :kerneladdr  => "<0x80080000>",
        :kernelentry => "<0x80080000>",
        :ramdiskaddr => "<0x88080000>",
        :dtbaddr     => "<0x90000000>",
        :kcomp       => "gzip",
    },
    "sparx5" => {
        :doc         => ["Systems using the internal CPU in sparx5."],
        :arch        => "arm64",
        :kerneladdr  => "/bits/ 64 <0x700080000> /* Change this to 0x60000000 for lan969x */",
        :kernelentry => "/bits/ 64 <0x700080000> /* Change this to 0x60000000 for lan969x */",
        :kcomp       => "gzip",
        :fw_env      => "/dev/mtd1 0x0000 0x2000 0x40000\n/dev/mtd2 0x0000 0x2000 0x40000\n",
    },
    "bbb" => {
        :doc         => ["Systems using BeagleBoneBlack as external CPU."],
        :arch        => "arm",
        :kerneladdr  => "<0x80080000>",
        :kernelentry => "<0x80080000>",
        :ramdiskaddr => "<0x88080000>",
        :kcomp       => "gzip",
        :fw_env      => "/dev/mmcblk1 0x260000 0x20000\n/dev/mmcblk1 0x280000 0x20000\n",
    },
    "rpi4cm" => {
        :doc         => ["Systems using Raspberry Pi 4 Compute Module as external CPU."],
        :arch        => "arm64",
        :kerneladdr  => "/bits/ 64 <0x00080000>",
        :kernelentry => "/bits/ 64 <0x00080000>",
        :ramdiskaddr => "/bits/ 64 <0xf000000>",
        :dtbaddr     => "/bits/ 64 <0xe000000>",
        :kcomp       => "gzip",
    },
}

KEXT = {
    ".gz" => {
        :doc => ["gzip compressed kernel. This format is used directly."],
    },
    ".xz" => {
        :doc => ["XZ compressed kernel. Converted to gzip (.gz) before being used."],
    },
    ".bin" => {
        :doc => ["bin file. This is used for zImage"]
    },

}

REXT = {
    ".tar" => {
        :doc => ["uncompressed tar archive."],
    },
    ".gz" => {
        :doc => ["gzip compressed tar archive."],
    },
    ".xz" => {
        :doc => ["xz compressed tar archive."],
    },
    ".squashfs" => {
        :doc => ["squashfs filesystem."],
    },
}

IEXT = {
    ".tar" => {
        :doc => ["uncompressed tar archive."],
    },
    ".gz" => {
        :doc => ["gzip compressed tar archive."],
    },
    ".xz" => {
        :doc => ["xz compressed tar archive."],
    },
    ".squashfs" => {
        :doc => ["squashfs filesystem."],
    },
}

def help_option(txt, option)
    l = 0
    option.each do |k, v|
        l = k.size if k.size > l
    end
    puts txt
    option.each do |k, v|
        v[:doc].each_with_index do |d, i|
            if i == 0
                puts sprintf(" %-#{l}s - %s", k, d)
            else
                puts sprintf(" %-#{l}s   %s", "", d)
            end
        end
    end
end

def vputs(*args)
    puts args if $opt[:verbose]
end

def sys(cmd)
    puts cmd
    stdout, stderr, status = Open3.capture3(cmd)

    if status.to_i != 0
        s = "\n\n<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n"
        s += "PWD: #{Dir.pwd}\n"
        s += "CMD: #{cmd}\n"
        s += "CMD FAILED (#{status})\n"
        s += "STDOUT:\n"
        s += "#{stdout}\n"
        s += "STDERR:\n"
        s += "#{stderr}\n"
        s += ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n\n"

        raise s
    end

    return stdout
end

# Create a new temporary directory at each call.
# $tmpdir/1
# $tmpdir/2
# ...
# Make sure to remove $tmpdir before exit
$tmpdir = nil
$tmpdirix = 0
def mktmpdir
    raise "$tmpdir not assigned!" if $tmpdir.nil?
    $tmpdirix += 1
    tmpdir = "#{$tmpdir}/#{$tmpdirix}"
    vputs "Create tmpdir #{tmpdir}"
    sys "mkdir -p #{tmpdir}"
    return tmpdir
end

# soc: current soc
# src: rootfs in .tar, .tar.gz, .tar.xz or .squashfs format
# fw_env: optional content in /etc/fw_env.config
# return path to unpacked filesystem
def unpack_rootfs(soc, src)
    fs = mktmpdir
    vputs "Unpack #{src} in #{fs}"
    if File.extname(src) == ".squashfs"
        sys "unsquashfs -d #{fs} -f #{src}"
    else
        sys "tar -C #{fs} -xf #{src}"
    end
    IO.write("#{fs}/etc/fw_env.config", soc[:fw_env]) if soc[:fw_env]
    return fs
end

# src: path to unpacked rootfs
# dst: full destination path without extension
# return path to ext4 file
def make_ext4(src, dst)
    fn = "#{dst}.ext4"
    vputs "Generate ext4 filesystem #{fn}"
    sys "rm -rf #{fn}"
    sys "touch #{fn}"
    sys "truncate -s 1G #{fn}"
    sys "fakeroot mkfs.ext4 -q -E root_owner -d #{src} #{fn}"
    sys "resize2fs -M #{fn}"
    return fn
end

# src: path to unpacked rootfs
# dst: full destination path without extension
# return path to ubifs file
def make_ubifs(src, dst)
    fn = "#{dst}.ubifs"
    vputs "Generate ubifs filesystem #{fn}"
    sys "rm -rf #{fn}"
    sys "mkfs.ubifs -r #{src} -m 2048 -e 124KiB -c 512 -o #{fn}"
    return fn
end

# soc: current soc
# src: path to rootfs
# return path to squashfs file
def make_squashfs(soc, src)
    fs = unpack_rootfs(soc, src)

    tmp = mktmpdir
    sqfs = "#{tmp}/rootfs.squashfs"
    vputs "mksquashfs #{fs}/* #{sqfs} -no-progress -quiet -all-root -noappend -comp xz"
    sys "mksquashfs #{fs}/* #{sqfs} -no-progress -quiet -all-root -noappend -comp xz"
    return sqfs
end

# src: path to kernel .gz or .xz
# return path to kernel converted to .gz
def make_kernel(src)
    kernel = src
    if File.extname(kernel) == ".xz"
        vputs "Convert kernel from .xz to .gz"
        tmp = mktmpdir
        o = "#{tmp}/#{File.basename(kernel, ".xz")}.gz"
        sys "xz -d -c #{kernel} | gzip -f -c > #{o}"
        kernel = o
    end
    # if user supplied a .gz use it directly
    return kernel
end

# soc: current soc
# name of .its file
# kernel: path to kernel.gz
# fs: path to squashfs filesystem
# dtbs: array of paths to dtbs
# overlays: array of paths to overlays
# return path to generated .its file
def make_its(soc, name, kernel, fs, dtbs, overlays)
    s  = "/dts-v1/;\n"
    s += "/ {\n"
    s += "\tdescription = \"Image Tree Source file for #{name}\";\n"
    s += "\t#address-cells = <1>;\n"
    s += "\n"
    s += "\timages {\n"
    s += "\t\tkernel {\n"
    s += "\t\t\tdescription = \"Kernel\";\n"
    s += "\t\t\tdata = /incbin/(\"#{kernel}\");\n"
    s += "\t\t\ttype = \"kernel\";\n"
    s += "\t\t\tarch = \"#{soc[:arch]}\";\n"
    s += "\t\t\tos = \"linux\";\n"
    s += "\t\t\tcompression = \"#{soc[:kcomp]}\";\n"
    s += "\t\t\tload = #{soc[:kerneladdr]};\n"
    s += "\t\t\tentry = #{soc[:kernelentry]};\n"
    s += "\t\t};\n\n"

    dtbs.each do |d|
        s += "\t\tfdt_#{d[1]} {\n"
        s += "\t\t\tdescription = \"Flattened Device Tree\";\n"
        s += "\t\t\tdata = /incbin/(\"#{d[0]}\");\n"
        s += "\t\t\ttype = \"flat_dt\";\n"
        s += "\t\t\tarch = \"#{soc[:arch]}\";\n"
        s += "\t\t\tload = #{soc[:dtbaddr]};\n" if soc[:dtbaddr]
        s += "\t\t\tcompression = \"none\";\n"
        s += "\t\t};\n\n"
    end

    overlays.each do |o|
        s += "\t\tfdt_#{o[1]} {\n"
        s += "\t\t\tdescription = \"Flattened Device Tree Overlay\";\n"
        s += "\t\t\tdata = /incbin/(\"#{o[0]}\");\n"
        s += "\t\t\ttype = \"flat_dt\";\n"
        s += "\t\t\tarch = \"#{soc[:arch]}\";\n"
        s += "\t\t\tload = #{soc[:overlayaddr]};\n" if soc[:overlayaddr]
        s += "\t\t\tcompression = \"none\";\n"
        s += "\t\t};\n\n"
    end

    if fs
        s += "\t\tramdisk {\n"
        s += "\t\t\tdescription = \"Ramdisk\";\n"
        s += "\t\t\tdata = /incbin/(\"#{fs}\");\n"
        s += "\t\t\ttype = \"ramdisk\";\n"
        s += "\t\t\tarch = \"#{soc[:arch]}\";\n"
        s += "\t\t\tos = \"linux\";\n"
        s += "\t\t\tcompression = \"none\";\n"
        s += "\t\t\tload = #{soc[:ramdiskaddr]};\n" if soc[:ramdiskaddr]
        s += "\t\t};\n\n"
    end

    s += "\t};\n\n"
    s += "\tconfigurations {\n"
    s += "\t\tdefault = \"#{dtbs[0][1]}\";\n"

    dtbs.each do |d|
        s += "\t\t#{d[1]} {\n"
        s += "\t\t\tdescription = \"Kernel with DT fdt_#{d[1]}\";\n"
        s += "\t\t\tkernel = \"kernel\";\n"
        s += "\t\t\tfdt = \"fdt_#{d[1]}\";\n"
        s += "\t\t\tramdisk = \"ramdisk\";\n" if fs
        s += "\t\t};\n\n"
    end

    overlays.each do |o|
        s += "\t\t#{o[1]} {\n"
        s += "\t\t\tdescription = \"DT fdt_#{o[1]}\";\n"
        s += "\t\t\tfdt = \"fdt_#{o[1]}\";\n"
        s += "\t\t};\n\n"
    end

    s += "\t};\n"
    s += "};\n"

    tmp = mktmpdir
    its = "#{tmp}/#{name}.its"

    IO.write its, s
    return its
end

# soc: current soc
# name of .its file
# kernel: path to kernel.gz
# fs: path to squashfs filesystem
# dtbs: array of paths to dtbs
# overlays: array of paths to overlays
# fn: path to generated file without extension
# return path to generated .itb file
def make_itb(soc, name, kernel, fs, dtbs, overlays, fn)
    if fs
        vputs "Generate squashfs filesystem"
        sqfs = make_squashfs($soc, fs)
    end

    vputs "Generate kernel.gz"
    knl = make_kernel(kernel)

    vputs "Generate #{fn}.its"
    its = make_its(soc, name, knl, fs ? sqfs : nil, dtbs, overlays)

    vputs "mkimage -q -f #{its} #{fn}.itb"
    sys "mkimage -q -f #{its} #{fn}.itb"

    # Save .its file for review
    sys "cp #{its} #{fn}.its"

    return "#{fn}.itb"
end

OptionParser.new do |opts|
    opts.banner = """Usage: #{File.basename($0)} [options]

This command will create ITB images or EXT4 file systems for different SOCs.

An ITB (Image Tree Blob) is an image using the FIT (Flattened Image Tree)
format that can contain kernel(s), device tree(s), file system(s) etc.

Use '#{File.basename($0)} -t help' to see what can be created.

Options:"""
    opts.on("-d", "--dtb PATH[,CFG_NAME]",
            "Absolute or relative path to device tree blob with .dtb extension.",
            "If optional cfg name is given, it is used as configuration name in its/itb.",
            "If cfg name is omitted, filename is used as configuration name.",
            "Repeat this option to add multiple dtbs.",
            "Default configuration in its/itb uses the first dtb.") do |d|
        dt = d.split(',')
        # dt[0]: filename
        # dt[1]: cfg name
        raise "Unknown device tree blob extension: '#{File.extname(dt[0])}'!" if File.extname(dt[0]) != ".dtb"
        raise "Device tree blob '#{dt[0]}' not found!" if !File.file?(dt[0])

        # Convert to absolute path
        dt[0] = File.expand_path(dt[0])
        # Generate cfg name from filename if name is missing
        dt[1] = File.basename(dt[0], ".dtb") if dt[1].nil?
        $opt[:dtbs] << dt
    end

    opts.on("-a", "--overlay PATH[,CFG_NAME]",
            "Absolute or relative path to device tree blob overlay with .dtbo extension.",
            "If optional cfg name is given, it is used as configuration name in its/itb.",
            "If cfg name is omitted, filename is used as configuration name.",
            "Repeat this option to add multiple dtbo.",
            "Default configuration in its/itb uses the first dtb.") do |o|
        overlay = o.split(',')
        # overla[0]: filename
        # overlay[1]: cfg name
        raise "Unknown device tree blob overlay extension: '#{File.extname(overlay[0])}'!" if File.extname(overlay[0]) != ".dtbo"
        raise "Device tree blob overlay '#{overlay[0]}' not found!" if !File.file?(overlay[0])

        # Convert to absolute path
        overlay[0] = File.expand_path(overlay[0])
        # Generate cfg name from filename if name is missing
        overlay[1] = File.basename(overlay[0], ".dtbo") if overlay[1].nil?
        $opt[:overlays] << overlay
    end

    opts.on("-h", "--help", "Show this message") do
        puts opts
        exit
    end

    opts.on("-i", "--initramfs PATH",
            "Absolute or relative path to initramfs.",
            "Use -i help for supported file extensions.") do |i|
        if i.casecmp("help") == 0
            help_option("Supported initramfs extensions are:", IEXT)
            exit
        end
        raise "Unknown initramfs extension: '#{File.extname(i)}'!" if IEXT[File.extname(i)].nil?
        raise "Initramfs '#{i}' not found!" if !File.file?(i)
        # Convert to absolute path
        $opt[:initramfs] = File.expand_path(i)
    end

    opts.on("-k", "--kernel PATH",
            "Absolute or relative path to kernel.",
            "Use -k help for supported file extensions.") do |k|
        if k.casecmp("help") == 0
            help_option("Supported kernel extensions are:", KEXT)
            exit
        end
        raise "Unknown kernel extension: '#{File.extname(k)}'!" if KEXT[File.extname(k)].nil?
        raise "Kernel '#{k}' not found!" if !File.file?(k)
        # Convert to absolute path
        $opt[:kernel] = File.expand_path(k)
    end

    opts.on("-n", "--name FILENAME",
            "Optional filename of the generated artifact.",
            "Default filename is 'type' with extension '.itb', '.ext4' or '.ubifs'.") do |n|
        raise "Invalid filename '#{n}'!" if /^[0-9a-zA-Z_\-.]+$/.match(n).nil?
        $opt[:name] = n
    end

    opts.on("-o", "--output PATH",
            "Absolute or relative path to folder where artifacts are saved.") do |o|
        raise "Output directory '#{o}' does not exist!" if !Dir.exist?(o)
        # Convert to absolute path
        $opt[:output] = File.expand_path(o)
    end

    opts.on("-r", "--rootfs PATH",
            "Absolute or relative path to rootfs.",
            "Use -r help for supported file extensions.") do |r|
        if r.casecmp("help") == 0
            help_option("Supported rootfs extensions are:", REXT)
            exit
        end
        raise "Unknown rootfs extension: '#{File.extname(r)}'!" if REXT[File.extname(r)].nil?
        raise "Root filesystem '#{r}' not found!" if !File.file?(r)
        # Convert to absolute path
        $opt[:rootfs] = File.expand_path(r)
    end

    opts.on("-s", "--soc NAME",
            "Name of the SOC. Use -s help for supported socs.") do |s|
        if s.casecmp("help") == 0
            help_option("Supported SOCs are:", SOCS)
            exit
        end
        raise "Unknown SOC: '#{s}'!" if SOCS[s].nil?
        $opt[:soc] = s
    end

    opts.on("-t", "--type TYPE",
            "Type of generated output. Use -t help for supported types.") do |t|
        if t.casecmp("help") == 0
            help_option("Supported types are:", TYPES)
            exit
        end
        raise "Unknown type: '#{t}'!" if TYPES[t].nil?
        $opt[:type] = t
    end

    opts.on("-v", "--verbose",
            "Run verbosely.") do |v|
        $opt[:verbose] = v
    end

    opts.on("-z", "--gzip",
            "gzip the final artifact.") do |z|
        $opt[:gzip] = true
    end

end.parse!

vputs "Options:\n#{PP.pp($opt,"")}"

raise "Missing option --type!" if $opt[:type].nil?
raise "Missing option --soc!" if $opt[:soc].nil?
raise "Missing option --output!" if $opt[:output].nil?

$soc = SOCS[$opt[:soc]]

if $opt[:name]
    $fn = "#{$opt[:output]}/#{$opt[:name]}"
else
    $fn = "#{$opt[:output]}/#{$opt[:type]}"
end

Dir.mktmpdir do |tmpdir|
    $tmpdir = tmpdir

    case $opt[:type]
    when "itb-rootfs"
        raise "Missing option --kernel!" if $opt[:kernel].nil?
        raise "Missing option --dtb!" if $opt[:dtbs][0].nil?
        raise "Missing option --rootfs!" if $opt[:rootfs].nil?

        artifact = make_itb($soc, $opt[:soc], $opt[:kernel], $opt[:rootfs], $opt[:dtbs], $opt[:overlays], $fn)

    when "itb-initramfs"
        raise "Missing option --kernel!" if $opt[:kernel].nil?
        raise "Missing option --dtb!" if $opt[:dtbs][0].nil?
        raise "Missing option --initramfs!" if $opt[:initramfs].nil?

        artifact = make_itb($soc, $opt[:soc], $opt[:kernel], $opt[:initramfs], $opt[:dtbs], $opt[:overlays], $fn)

    when "itb-bare"
        raise "Missing option --kernel!" if $opt[:kernel].nil?
        raise "Missing option --dtb!" if $opt[:dtbs][0].nil?

        artifact = make_itb($soc, $opt[:soc], $opt[:kernel], nil, $opt[:dtbs], $opt[:overlays], $fn)

    when "ext4-itb-bare"
        raise "Missing option --kernel!" if $opt[:kernel].nil?
        raise "Missing option --dtb!" if $opt[:dtbs][0].nil?
        raise "Missing option --rootfs!" if $opt[:rootfs].nil?

        itb = make_itb($soc, $opt[:soc], $opt[:kernel], nil, $opt[:dtbs], $opt[:overlays], $fn)

        fs = unpack_rootfs($soc, $opt[:rootfs])

        # copy itb to /
        sys "cp #{itb} #{fs}/Image.itb"

        artifact = make_ext4(fs, $fn)

    when "ext4-itb-initramfs"
        raise "Missing option --kernel!" if $opt[:kernel].nil?
        raise "Missing option --dtb!" if $opt[:dtbs][0].nil?
        raise "Missing option --rootfs!" if $opt[:rootfs].nil?
        raise "Missing option --initramfs!" if $opt[:initramfs].nil?

        itb = make_itb($soc, $opt[:soc], $opt[:kernel], $opt[:initramfs], $opt[:dtbs], $opt[:overlays], $fn)

        fs = unpack_rootfs($soc, $opt[:rootfs])

        # copy itb to /
        sys "cp #{itb} #{fs}/Image.itb"

        artifact = make_ext4(fs, $fn)

    when "ext4-bare"
        raise "Missing option --rootfs!" if $opt[:rootfs].nil?

        fs = unpack_rootfs($soc, $opt[:rootfs])
        artifact = make_ext4(fs, $fn)

    when "ubifs-itb-bare"
        raise "Missing option --kernel!" if $opt[:kernel].nil?
        raise "Missing option --dtb!" if $opt[:dtbs][0].nil?
        raise "Missing option --rootfs!" if $opt[:rootfs].nil?

        itb = make_itb($soc, $opt[:soc], $opt[:kernel], nil, $opt[:dtbs], $opt[:overlays], $fn)

        fs = unpack_rootfs($soc, $opt[:rootfs])

        # copy itb to /
        sys "cp #{itb} #{fs}/Image.itb"

        artifact = make_ubifs(fs, $fn)

    else
        raise "Type: #{$opt[:type]} not supported"
    end

    if $opt[:gzip] and artifact
        vputs "Gzipping artifact #{artifact}"
        sys "gzip -f #{artifact}"
    end

#    puts "Press <enter> after checking files in /tmp/"; gets

end # tmpdir is removed when Dir.mktmpdir exits
