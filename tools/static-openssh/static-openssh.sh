#!/usr/bin/env bash

set -uex
umask 0077

ZLIB_VERSION=1.3.1
OPENSSL_VERSION=3.2.1
OPENSSH_VERSION=V_9_6_P1

prefix="/opt/openssh"
top="$(pwd)"
root="$top/root"
build="$top/build"
dist="$top/dist"

export "CPPFLAGS=-I$root/include -L. -fPIC"
export "CFLAGS=-I$root/include -L. -fPIC"
export "LDFLAGS=-L$root/lib -L$root/lib64"

#COMMENT THIS for debugging the script. Each stage will cache download and build
#rm -rf "$root" "$build" "$dist"
mkdir -p "$root" "$build" "$dist"

if [ ! -f "build/zlib-$ZLIB_VERSION/minigzip" ]; then
echo "---- Building ZLIB -----"
if [ ! -f "$dist/zlib-$ZLIB_VERSION.tar.gz" ]; then
curl --output $dist/zlib-$ZLIB_VERSION.tar.gz --location https://zlib.net/zlib-$ZLIB_VERSION.tar.gz
gzip -dc $dist/zlib-*.tar.gz |(cd "$build" && tar xf -)
fi
cd "$build"/zlib-*
./configure --prefix="$root" --static
make
make install
cd "$top"
fi

if [ ! -f "build/openssl-$OPENSSL_VERSION/wow" ]; then
echo "---- Building OpenSSL -----"
if [ ! -f "$dist/openssl-$OPENSSL_VERSION.tar.gz" ]; then
curl --output $dist/openssl-$OPENSSL_VERSION.tar.gz --location https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz
gzip -dc $dist/openssl-*.tar.gz |(cd "$build" && tar xf -)
fi
cd "$build"/openssl-*
# Debian 12 / Ubuntu 20.x.x break the autoconf in ./config on armv7 devices
  CPU=$(uname -m)
  if [[ $CPU == "armv7l" ]]
     then  
     ./Configure linux-armv4 --prefix="$root"  no-shared no-tests
     else
     ./config --prefix="$root"  no-shared no-tests
  fi
make
make install
cd "$top"
fi

if [ ! -f "$dist/openssh-$OPENSSH_VERSION.tar.gz" ]; then
curl --output $dist/openssh-$OPENSSH_VERSION.tar.gz --location https://github.com/openssh/openssh-portable/archive/refs/tags/$OPENSSH_VERSION.tar.gz
fi
gzip -dc $dist/openssh-*.tar.gz |(cd "$build" && tar xf -)
cd "$build"/openssh-*
cp -p "$root"/lib/*.a .
[ -f sshd_config.orig ] || cp -p sshd_config sshd_config.orig
sed \
  -e 's/^#\(PubkeyAuthentication\) .*/\1 yes/' \
  -e '/^# *Kerberos/d' \
  -e '/^# *GSSAPI/d' \
  -e 's/^#\([A-Za-z]*Authentication\) .*/\1 no/' \
  sshd_config.orig \
  >sshd_config \
; 
export PATH=$root/bin:$PATH 
autoreconf
./configure LIBS="-lpthread"  "--with-ldflags=-static" "--prefix=$root" "--exec-prefix=$root" --with-privsep-user=nobody --with-privsep-path="$prefix/var/empty" "--with-ssl-dir=$root"
make
cd "$top"