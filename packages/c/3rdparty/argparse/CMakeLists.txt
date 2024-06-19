
# targets
# -------
# argparse::argparse-static
# argparse::argparse-shared

include(GNUInstallDirs)

set(ARGPARSE_STATIC_LIB argparse-static)
set(ARGPARSE_SHARED_LIB argparse-shared)

set(ARGPARSE_SOURCES
    ${CMAKE_CURRENT_LIST_DIR}/src/argparse.c
)

set(ARGPARSE_INCLUDE_DIR ${CMAKE_CURRENT_LIST_DIR}/include)

add_library(${ARGPARSE_STATIC_LIB} STATIC
    ${ARGPARSE_SOURCES}
)

add_library(${ARGPARSE_SHARED_LIB} SHARED
    ${ARGPARSE_SOURCES}
)

target_include_directories(${ARGPARSE_STATIC_LIB} PUBLIC
    $<BUILD_INTERFACE:${ARGPARSE_INCLUDE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

target_include_directories(${ARGPARSE_SHARED_LIB} PUBLIC
    $<BUILD_INTERFACE:${ARGPARSE_INCLUDE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

add_library(argparse::${ARGPARSE_STATIC_LIB} ALIAS ${ARGPARSE_STATIC_LIB})
add_library(argparse::${ARGPARSE_SHARED_LIB} ALIAS ${ARGPARSE_SHARED_LIB})

