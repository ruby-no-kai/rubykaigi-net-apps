prefix=/opt/quiche

Name: quiche
Description: Implementation of the QUIC transport protocol and HTTP/3
URL: https://github.com/cloudflare/quiche
Version: @QUICHE_VERSION@
Cflags: -I${prefix}/include
Libs: ${prefix}/lib/libquiche.so.0
