option(NOPORTS_ATSDK_PATH "Local atsdk path" OFF)
option(NOPORTS_CJSON_PATH "Local cJSON path" OFF)
option(NOPORTS_MBEDTLS_PATH "Local mbedtls path" OFF)
option(NOPORTS_GS_TOOL "Include graceful-shutdown-tool" OFF)
set(ATSDK_CJSON_PATH ${NOPORTS_CJSON_PATH})
set(ATSDK_MBEDTLS_PATH ${NOPORTS_MBEDTLS_PATH})

cmake_minimum_required(VERSION 3.19)
set(CMAKE_C_STANDARD 99)
cmake_policy(SET CMP0135 NEW)
project(noports VERSION 1.0.4 LANGUAGES C)

include("${CMAKE_CURRENT_LIST_DIR}/cmake/CPackSetup.cmake")

add_subdirectory(sshnpd)

if(NOPORTS_GS_TOOL)
  add_subdirectory(graceful-shutdown-tool)
endif()
