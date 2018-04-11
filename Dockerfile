
#
#  This dockerfile builds a new centos container from absolutely scratch
#  to minimize the attack surface of vulnerable packages
#

FROM    centos:7 as builder

# destination folder of the new os
ARG     centos_root=/centos_image/rootfs

# make sure everything is the latest
RUN     set -eux; yum -y update

# starting to build up my os from scratch
RUN     set -eux; \
        mkdir -p ${centos_root} && \
        rpm --root ${centos_root} --initdb && \
        yum reinstall --downloadonly --downloaddir . centos-release && \
        rpm --root ${centos_root} -ivh centos-release*.rpm && \
        rpm --root ${centos_root} --import  ${centos_root}/etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

# installing mandatory packages
RUN     set -eux; yum -y --installroot=${centos_root} \
        --setopt=tsflags='nodocs' \
        --setopt=override_install_langs=en_US.utf8 \
        install \
        glibc \
        libtool-ltdl \
        ca-certificates

# preparing to compile busybox
RUN     set -eux; yum groupinstall -y "Development Tools" && \
        yum install -y glibc-static wget && \
        mkdir -p /root/rpmbuild && \
        mkdir -p /root/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

# deploying spec file, configuration and signature
COPY    busybox/busybox-1.28.1.tar.bz2.sign /root/rpmbuild/SOURCES/
COPY    busybox/busybox-config /root/rpmbuild/SOURCES/
COPY    busybox/busybox.spec /root/rpmbuild/SPECS/

# pulling source and checking checksum
RUN     set -eux; \
        url="https://busybox.net/downloads/busybox-1.28.1.tar.bz2"; \
        wget -q -O /root/rpmbuild/SOURCES/busybox-1.28.1.tar.bz2 "$url"

# getting the build ready
RUN     set -eux; chown -R root: /root/rpmbuild && \
        cd /root/rpmbuild && \
        rpmbuild -v -bb --clean SPECS/busybox.spec

# installing busybox
RUN     set -eux; \
        rpm --root ${centos_root} -ivh /root/rpmbuild/RPMS/x86_64/busybox-static-1.28.1-1.x86_64.rpm && \
        chroot ${centos_root} /usr/bin/busybox.static --install

# How do I reduce the size of locale-archive?
RUN     set -eux; \
        rm -rf ${centos_root}/var/cache/yum && \
        echo "localedef --list-archive | grep -v -i ^en | xargs localedef --delete-from-archive" > ${centos_root}/fixme.sh && \
        echo "mv /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl" >> ${centos_root}/fixme.sh && \
        echo "build-locale-archive" >> ${centos_root}/fixme.sh && \
        chmod 755 ${centos_root}/fixme.sh && \
        chroot ${centos_root} /fixme.sh && \
        rm ${centos_root}/fixme.sh

#
#  FINAL CONTAINER
#

FROM    scratch

COPY    --from=builder /centos_image/rootfs /
