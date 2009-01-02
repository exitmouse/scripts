Summary: scripts.mit.edu base packages
Group: Applications/System
Name: scripts-base
Version: 0.SVNVERSION_TO_UPDATE
Release: 0
Vendor: The scripts.mit.edu Team (scripts@mit.edu)
URL: http://scripts.mit.edu
License: GPL
Source: %{name}.tar.gz 
BuildRoot: %{_tmppath}/%(%{__id_u} -n)-%{name}-%{version}-root
Requires: accountadm, execsys, kmod-openafs = 1.4.8-1.1.scripts.2.6.27.9_73.fc9, scripts-krb5-libs, scripts-httpd, scripts-mod_ssl, openafs, scripts-openafs-client, scripts-openafs-authlibs, scripts-openafs-devel, scripts-openafs-krb5, openafs-debuginfo, openafs-docs, scripts-openssh-server, sql-signup, tokensys, whoisd, logview, nss-ldapd
%define debug_package %{nil}

%description 

scripts.mit.edu base package
Contains:
 - Dependencies to install rpms required for base scripts functionality
See http://scripts.mit.edu/wiki for more information.

%prep
%setup -q -n %{name}

%build

%install

%clean

%files

%changelog
* Thu Jan  1 2009  Quentin Smith <quentin@mit.edu>
- prerelease
