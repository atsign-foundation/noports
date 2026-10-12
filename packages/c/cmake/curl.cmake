# libcurl, which the daemon looks clients' public signing keys up with, over
# HTTPS GET. Built for HTTP(S) alone, on the mbedtls the atsdk already builds,
# so the daemon carries one TLS library.
if(NOPORTS_USE_SHARED_LIBS)
  find_package(CURL REQUIRED)
  return()
endif()

option(NOPORTS_CURL_PATH "Local curl path" OFF)
if(NOT TARGET CURL::libcurl)
  message(STATUS "[curl] fetching package...")
  include(FetchContent)
  if(NOPORTS_CURL_PATH)
    FetchContent_Declare(curl SOURCE_DIR ${CMAKE_SOURCE_DIR}/${NOPORTS_CURL_PATH})
  else()
    FetchContent_Declare(
      curl
      URL https://github.com/curl/curl/releases/download/curl-8_22_0/curl-8.22.0.tar.xz
      URL_HASH SHA256=f7ef3ae8a22e521f289803fe93543eb64c329b58aa73a9e224dfd915a2a5f4f7
    )
  endif()

  # The atsdk declares mbedtls under one of these names
  foreach(name MbedTLS mbedtls)
    FetchContent_GetProperties(${name} SOURCE_DIR noports_mbedtls_source_dir)
    if(noports_mbedtls_source_dir)
      break()
    endif()
  endforeach()
  if(NOT EXISTS "${noports_mbedtls_source_dir}/include/mbedtls/ssl.h")
    message(FATAL_ERROR "[curl] can't find the atsdk's mbedtls sources")
  endif()

  # curl declares these as cache entries, which discard a normal variable of
  # the same name. No CA bundle is built in: the daemon passes the atsdk's own
  # CA certificates on each request.
  set(CURL_ZLIB OFF CACHE STRING "" FORCE)
  set(CURL_BROTLI OFF CACHE STRING "" FORCE)
  set(CURL_ZSTD OFF CACHE STRING "" FORCE)
  set(CURL_CA_BUNDLE none CACHE STRING "" FORCE)
  set(CURL_CA_PATH none CACHE STRING "" FORCE)

  # A function, so these settings reach curl's build and nothing else
  function(noports_make_curl_available)
    set(BUILD_SHARED_LIBS OFF)
    set(BUILD_STATIC_LIBS ON)
    set(BUILD_CURL_EXE OFF)
    set(BUILD_TESTING OFF)
    set(BUILD_LIBCURL_DOCS OFF)
    set(BUILD_MISC_DOCS OFF)
    set(ENABLE_CURL_MANUAL OFF)
    set(CURL_DISABLE_INSTALL ON)
    set(CURL_ENABLE_EXPORT_TARGET OFF)
    set(PICKY_COMPILER OFF)
    set(HTTP_ONLY ON)
    set(CURL_DISABLE_ALTSVC ON)
    set(CURL_DISABLE_COOKIES ON)
    set(CURL_DISABLE_HSTS ON)
    set(CURL_DISABLE_NETRC ON)
    set(CURL_DISABLE_PROXY ON)
    set(CURL_DISABLE_HTTP_AUTH ON)
    set(CURL_DISABLE_MIME ON)
    set(CURL_DISABLE_WEBSOCKETS ON)
    set(CURL_DISABLE_DOH ON)
    set(CURL_DISABLE_PROGRESS_METER ON)
    set(CURL_DISABLE_PARSEDATE ON)
    set(CURL_DISABLE_GETOPTIONS ON)
    set(CURL_DISABLE_HEADERS_API ON)
    set(CURL_DISABLE_SHA512_256 ON)
    set(CURL_DISABLE_BINDLOCAL ON)
    set(CURL_DISABLE_AWS ON)
    set(CURL_USE_LIBPSL OFF)
    set(CURL_USE_LIBSSH2 OFF)
    set(CURL_USE_LIBSSH OFF)
    set(CURL_USE_GSSAPI OFF)
    set(USE_NGHTTP2 OFF)
    set(USE_LIBIDN2 OFF)
    set(ENABLE_ARES OFF)
    set(CURL_USE_PKGCONFIG OFF)
    set(CURL_USE_CMAKECONFIG OFF)
    set(CURL_ENABLE_SSL ON)
    set(CURL_USE_OPENSSL OFF)
    set(CURL_USE_MBEDTLS ON)
    set(MBEDTLS_INCLUDE_DIR ${noports_mbedtls_source_dir}/include)
    set(MBEDTLS_LIBRARY mbedtls)
    set(MBEDX509_LIBRARY mbedx509)
    set(MBEDCRYPTO_LIBRARY mbedcrypto)
    # NOTE: curl probes for DES (used only by NTLM, which is off) by linking a
    # test program to mbedtls, which can't link to a target not yet built
    set(HAVE_MBEDTLS_DES_CRYPT_ECB 0)
    FetchContent_MakeAvailable(curl)
  endfunction()
  noports_make_curl_available()
endif()
