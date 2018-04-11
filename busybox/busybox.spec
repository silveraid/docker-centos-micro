%bcond_with   		uclibc
%define Werror_cflags	%{nil} 
%define _ssp_cflags	%{nil}

Summary:	Multi-call binary combining many common Unix tools into one executable
Name:		busybox
Version:	1.28.1
Release:	1
Epoch:		1
License:	GPLv2
Group:		Shells
URL:		http://www.busybox.net/
Source0:	http://www.busybox.net/downloads/%{name}-%{version}.tar.bz2
Source1:	http://www.busybox.net/downloads/%{name}-%{version}.tar.bz2.sign
Source2:	busybox-config

BuildRequires:	gcc >= 3.3.1-2mdk
BuildRequires:	glibc-static
%define	cflags	%{optflags}
# BuildRequires:	kernel-userspace-headers

%description
BusyBox combines tiny versions of many common UNIX utilities into a
single small executable. It provides minimalist replacements for most
of the utilities you usually find in GNU coreutils, shellutils, etc.
The utilities in BusyBox generally have fewer options than their
full-featured GNU cousins; however, the options that are included provide
the expected functionality and behave very much like their GNU counterparts.
BusyBox provides a fairly complete POSIX environment for any small or
embedded system.

BusyBox has been written with size-optimization and limited resources in
mind. It is also extremely modular so you can easily include or exclude
commands (or features) at compile time. This makes it easy to customize
your embedded systems. To create a working system, just add /dev, /etc,
and a kernel.

%package	static
Group:		Shells
Summary:	Static linked busybox

%description	static
This package contains a static linked busybox.

%prep
%setup -q

%build
cat %{SOURCE2} > .config
# %make_build CC=%{__cc} LDFLAGS="%{ldflags}" V=1
%make_build CC=%{__cc} V=1 CONFIG_STATIC=y
mv busybox_unstripped busybox.full.static
# %make_build CC=%{__cc} LDFLAGS="%{ldflags}" V=1 CONFIG_STATIC=n
%make_build CC=%{__cc} V=1 CONFIG_STATIC=n
mv busybox_unstripped busybox.full

%check
# FIXME
%if 0
%make_build CC=%{__cc} V=1 check
%endif

%install
install -m755 busybox.full -D %{buildroot}%{_bindir}/busybox
install -m755 busybox.full.static -D %{buildroot}/bin/busybox.static

%files
%doc AUTHORS README TODO
%{_bindir}/busybox

%files static
%doc AUTHORS README TODO
/bin/busybox.static
