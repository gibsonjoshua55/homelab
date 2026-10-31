# Tooling image: butane, coreos-installer, and QEMU for both architectures.
FROM registry.fedoraproject.org/fedora:43
RUN dnf -y install --setopt=install_weak_deps=False \
      butane coreos-installer qemu-img \
      qemu-system-x86-core qemu-system-aarch64-core edk2-aarch64 \
      openssh-clients \
    && dnf clean all
COPY run-vm.sh /usr/local/bin/run-vm
WORKDIR /work
