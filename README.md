# Firmware Mod Kit

Firmware Mod Kit (FMK) is a collection of scripts and utilities for taking apart
and reassembling firmware images for embedded Linux devices, mainly routers.
It splits an image into its header, root file system and footer, unpacks the
file system so it can be modified, and puts everything back together with the
checksums updated.

This repository continues the project that was hosted on Google Code, whose last
upstream commit dates from November 2013. It has been brought up to date so that
it builds with current compilers and runs on current distributions.

> **Warning**
> Flashing a modified firmware image can permanently disable ("brick") a device.
> Make sure you have a way to recover it before you flash anything you built.

## Requirements

FMK runs on Linux. To build the bundled tools you need a C and C++ compiler,
`make`, and the development files for zlib and liblzma (xz). To use the scripts
you need `bash`, GNU coreutils and [binwalk](https://github.com/ReFirmLabs/binwalk),
version 2.x or 3.x.

The other tools are only needed for particular image types:

| Tool | Needed for |
|------|------------|
| `sudo` or `fakeroot` | preserving device nodes (see [Privileges](#privileges)) |
| squashfs-tools | SquashFS 4.x images compressed with lzo, lz4 or zstd |
| [sasquatch](https://github.com/devttys0/sasquatch) | vendor SquashFS variants the bundled tools cannot read (extraction only) |
| [jefferson](https://github.com/onekey-sec/jefferson) | extracting JFFS2 images without root |
| mtd-utils | rebuilding JFFS2 images (`mkfs.jffs2`) |
| `hexdump` | CramFS images |
| `cpio` | `uncpio.sh` |
| 7-Zip (`7z`, `7zz` or `7za`) | `src/firmware-tools/unwdk.py` |
| Python 3 | the helper scripts in `src/bff` and `src/firmware-tools` |

### Debian and Ubuntu

```sh
sudo apt install build-essential zlib1g-dev liblzma-dev binwalk \
    squashfs-tools mtd-utils bsdextrautils cpio 7zip fakeroot python3
```

### Arch Linux

```sh
sudo pacman -S --needed base-devel zlib xz binwalk \
    squashfs-tools mtd-utils cpio 7zip fakeroot python
```

### Fedora

```sh
sudo dnf install gcc gcc-c++ make zlib-devel xz-devel binwalk \
    squashfs-tools mtd-utils cpio fakeroot python3
```

### jefferson and sasquatch

Neither is packaged by most distributions. jefferson is a Python program and can
be installed with [pipx](https://pipx.pypa.io/):

```sh
pipx install jefferson
```

sasquatch has to be built from its source.

## Building

```sh
make
```

This runs `src/configure` and builds every tool under `src/`. Parallel builds
(`make -j8`) are supported. `make clean` removes what was built.

The extract and build scripts also build the tools on first use if they have
not been built yet.

## Usage

### Extracting a firmware image

```sh
./extract-firmware.sh firmware.bin [output directory]
```

The output directory defaults to `fmk` and must not exist yet. It receives:

| Path | Contents |
|------|----------|
| `rootfs/` | the extracted root file system |
| `image_parts/header.img` | everything in front of the file system (headers, boot loader, kernel) |
| `image_parts/rootfs.img` | the original file system image |
| `image_parts/footer.img` | whatever follows the file system and its padding, if anything |
| `logs/binwalk.log` | the binwalk scan results |
| `logs/config.log` | the settings needed to rebuild the image |

### Rebuilding a firmware image

After changing the files under `rootfs/`:

```sh
./build-firmware.sh [output directory] [-nopad | -min]
```

The new image is written to `new-firmware.bin` in the output directory. It has
the same size as the original: the space left over after the new file system is
filled with `0xFF` bytes and the original footer is put back at its old offset.
TRX, uImage and DLOB header checksums are recalculated, the checksum of TP-Link
images is corrected, and Buffalo images are additionally saved in encrypted
form as `new-firmware.bin.enc`.

FMK refuses to build an image that is larger than the original.

| Option | Effect |
|--------|--------|
| `-nopad` | do not pad the image to its original size |
| `-min` | use 1 MB SquashFS blocks to make the file system as small as possible |

### Privileges

A root file system contains device nodes, which only root can create. The
scripts therefore run the file system tools through `sudo` unless they are
started as root. The `FMK_SUDO` variable selects a different command:

```sh
# Stay unprivileged. Device nodes are lost; fine for inspecting an image.
FMK_SUDO= ./extract-firmware.sh firmware.bin

# Record device nodes without real root. Use the same state file,
# given as an absolute path, for extracting and for rebuilding.
export FMK_SUDO="fakeroot -i $PWD/fmk.state -s $PWD/fmk.state"
./extract-firmware.sh firmware.bin
./build-firmware.sh
```

SquashFS images are always rebuilt with every file owned by root.

### Choosing binwalk

The scripts use the `binwalk` found in `PATH`. Set `BINWALK` to use another one:

```sh
BINWALK=/opt/binwalk/bin/binwalk ./extract-firmware.sh firmware.bin
```

Results differ between binwalk versions. Old 2.x releases do not recognise newer
formats such as zstd-compressed SquashFS, and binwalk 3.x does not detect every
YAFFS image that 2.x does.

## Supported file systems

| File system | Extraction | Rebuilding |
|-------------|------------|------------|
| SquashFS 2.x, 3.x, 4.x (gzip, LZMA, xz) and many vendor variants | bundled tools | bundled tools |
| SquashFS 4.x (lzo, lz4, zstd) | system `unsquashfs` | system `mksquashfs` |
| CramFS, both byte orders | bundled tools | bundled tools |
| JFFS2 | jefferson, or the bundled `unjffs2` as root | `mkfs.jffs2` |
| YAFFS2 | bundled tools | bundled tools, untested on real devices |

`unsquashfs_all.sh` and `uncramfs_all.sh` can also be used on their own to unpack
a bare file system image by trying each suitable tool in turn.

## Other scripts and tools

| Script | Purpose |
|--------|---------|
| `ddwrt-gui-extract.sh`, `ddwrt-gui-rebuild.sh` | extract and restore the web interface files of DD-WRT images |
| `uncpio.sh` | unpack a cpio archive |
| `ipkg_install.sh`, `ipkg_remove.sh` and their `_all` variants | install or remove ipkg packages in an extracted root file system |
| `other-scripts/` | less polished helpers for transplanting a root file system between images |
| `deprecated/` | the scripts used before `extract-firmware.sh` and `build-firmware.sh` |

The tools under `src/` can be used directly as well, among them `untrx` and
`asustrx` for TRX images, `crcalc` for header checksums, `tpl-tool` for TP-Link
images, `buffalo-enc` for Buffalo images and `webdecomp` for DD-WRT web files.

## Licensing

The bundled tools come from many projects and keep their own licences, which
are found in their source directories under `src/`.
