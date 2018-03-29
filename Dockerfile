
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
        rpm --root ${centos_root} -ivh centos-release*.rpm

# downloading mandatory packages
RUN     set -eux; yum reinstall --downloadonly --downloaddir . \
        bash \
        glibc \
        glibc-common \
        basesystem \
        setup \
        filesystem \
        libgcc \
        tzdata \
        libselinux \
        pcre \
        libstdc++ \
        libsepol \
        ncurses-libs \
        ncurses-base \
        nss-softokn-freebl \
        nspr

# installing mandatory packages
RUN     rpm --root ${centos_root} -ivh \
        basesystem-*.el7.centos.noarch.rpm \
        glibc-*.x86_64.rpm \
        glibc-common-*.x86_64.rpm \
        setup-*.el7.noarch.rpm \
        filesystem-*.el7.x86_64.rpm \
        libgcc-*.x86_64.rpm \
        bash-*.x86_64.rpm \
        libselinux-*.x86_64.rpm \
        libsepol-*.x86_64.rpm \
        tzdata-*.el7.noarch.rpm \
        pcre-*.el7.x86_64.rpm \
        libstdc++-*.x86_64.rpm \
        ncurses-libs-*.x86_64.rpm \
        ncurses-base-*.noarch.rpm \
        nss-softokn-freebl-*.x86_64.rpm \
        nspr-*.x86_64.rpm

# downloading libltdl support
RUN     set -eux; yum install --downloadonly --downloaddir . \
        libtool-ltdl

# installing libltdl support
RUN     set -eux; rpm --root $centos_root -ivh \
        libtool-ltdl*.rpm

# downloading packages to populate ca certificates
RUN     set -eux; yum reinstall --downloadonly --downloaddir . \
        ca-certificates \
        p11-kit \
        p11-kit-trust \
        chkconfig \
        popt \
        libtasn1 \
        libffi

# installing packages to populate ca certificates
RUN     set -eux; rpm --root $centos_root -ivh \
        ca-certificates-*.el7.noarch.rpm \
        p11-kit-*.el7.x86_64.rpm \
        p11-kit-trust-*.el7.x86_64.rpm \
        libtasn1-*.el7.x86_64.rpm \
        libffi-*.el7.x86_64.rpm \
        chkconfig-*.el7.x86_64.rpm \
        popt-*.el7.x86_64.rpm

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
