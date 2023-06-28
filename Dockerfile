FROM fedora:latest

RUN dnf -y update && dnf -y install gcc git make bison bc xz diffutils flex \
	# Needed for cross-compilation
	gcc-x86_64-linux-gnu gcc-aarch64-linux-gnu \
	# Needed for bpftool
	elfutils-libelf-devel zlib-devel \
	# Extra for bpftool
	clang llvm libcap-devel binutils-devel llvm-devel \
	# pahole for BTF handling
	dwarves

WORKDIR /var/workdir