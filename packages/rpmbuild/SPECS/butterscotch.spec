
Name:           butterscotch
Version:        1.1.2
Release:        1%{?dist}
Summary:        This software helps you create snapshots on a system with BTRFS filesystems.

License:        Apache v2
URL:            https://github.com/oxagast/butterscotch
Source0:        butterscotch.tar.gz

Requires:       bash
Enhances:       btrfs-progs


%description
This software helps users create rolling BTRFS snapshots on their systems.

%global debug_package %{nil}

%prep
%setup -q

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{_bindir} %{buildroot}%{_mandir}/man1/
install -D -m 644 butterscotch.sh %{buildroot}%{_bindir}/butterscotch
install -D -m 755 butterscotch.sh %{_bindir}/butterscotch
install -D -m 755 butterscotch.1 %{buildroot}%{_mandir}/man1/butterscotch.1
install -D -m 644 butterscotch.1 %{_mandir}/man1/butterscotch.1
gzip -f %{_mandir}/man1/butterscotch.1
chmod 755 %{buildroot}/usr/bin/butterscotch /usr/bin/butterscotch
#chmod 644 %{_mandir}/man1/butterscotch.1.gz /usr/share/man/man1/butterscotch.1.gz


%files
%license LICENSE
/usr/share/man/man1/butterscotch.1.gz
/usr/bin/butterscotch

%clean
rm -rf %{buildroot}

%changelog
* Mon Dec 08 2025 Marshall Whittaker <marshall@oxasploits.com>
- Initial RPM release (1.1)
