MAKEFLAGS += --no-print-directory

ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
OUT_DIR:="/var/workdir/out"
KERNEL_VERSION:=$(shell cd linux && make kernelversion | tr '.' '_')
KERNEL_REVISION:=$(shell cd linux && git rev-parse HEAD)
KERNEL_CONFIG:=$(ROOT_DIR)/kconfig
NPROC:=$(shell nproc --all)

fetch-kernel:
	git clone https://github.com/torvalds/linux || true

build-docker:
	podman build . -t fedora-kernel-builder

sh: fetch-kernel build-docker
	podman run -it -v $(ROOT_DIR):/var/workdir/ fedora-kernel-builder /bin/bash

build-x86-kernel:
	podman run -it -v $(ROOT_DIR):/var/workdir/ fedora-kernel-builder /bin/bash -c "make _build-x86-kernel"

build-arm64-kernel:
	podman run -it -v $(ROOT_DIR):/var/workdir/ fedora-kernel-builder /bin/bash -c "make _build-arm64-kernel"

dump-btf-configs:
	podman run -it -v $(ROOT_DIR):/var/workdir/ fedora-kernel-builder /bin/bash -c "make _dump-btf-configs"

# Run the below in the container.
_build-bpftool:
	cd linux/tools/bpf/bpftool && make bpftool

_build-x86-kernel:
	mkdir -p $(OUT_DIR)/x86
	cp $(KERNEL_CONFIG)/.config $(OUT_DIR)/x86/.config
	cd linux && \
	make O=$(OUT_DIR)/x86 ARCH=x86 CROSS_COMPILE=x86_64-linux-gnu- KCONFIG_CONFIG=$(OUT_DIR)/x86/.config olddefconfig && \
	make LOCALVERSION="-$(KERNEL_REVISION)" KBUILD_BUILD_USER=testvm KBUILD_BUILD_HOST=testvm O=$(OUT_DIR)/x86 ARCH=x86 CROSS_COMPILE=x86_64-linux-gnu- KCONFIG_CONFIG=$(OUT_DIR)/x86/.config -j$(NPROC) all

_build-arm64-kernel:
	mkdir -p $(OUT_DIR)/arm64
	cp $(KERNEL_CONFIG)/.config $(OUT_DIR)/arm64/.config
	cd linux && \
	make O=$(OUT_DIR)/arm64 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KCONFIG_CONFIG=$(OUT_DIR)/arm64/.config olddefconfig  && \
	make O=$(OUT_DIR)/arm64 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KCONFIG_CONFIG=$(OUT_DIR)/arm64/.config -j$(NPROC) all

_dump-btf-configs: _build-bpftool _build-x86-kernel _build-arm64-kernel
	echo "// Git revision: $(KERNEL_REVISION)" > $(OUT_DIR)/vmlinux_$(KERNEL_VERSION)_x86.h
	echo "// Git revision: $(KERNEL_REVISION)" > $(OUT_DIR)/vmlinux_$(KERNEL_VERSION)_arm64.h
	/var/workdir/linux/tools/bpf/bpftool/bpftool btf dump file out/x86/vmlinux format c >> $(OUT_DIR)/vmlinux_$(KERNEL_VERSION)_x86.h
	/var/workdir/linux/tools/bpf/bpftool/bpftool btf dump file out/arm64/vmlinux format c >> $(OUT_DIR)/vmlinux_$(KERNEL_VERSION)_arm64.h

clean:
	-rm -rf out/x86/
	-rm -rf out/arm64/
	-rm -rf out/vmlinux_*
	-rm -rf out/.*


.PHONY: clean test all
