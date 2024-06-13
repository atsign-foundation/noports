if(NOT atsdk_FOUND)
  message(STATUS "atsdk not found, fetching from GitHub..")
  FetchContent_Declare(
    atsdk
    GIT_REPOSITORY https://github.com/atsign-foundation/at_c.git
    GIT_TAG 6b6f1e0338e2f5de3b6b4c800104711ffa794c72
  )
  FetchContent_MakeAvailable(atsdk)
  install(TARGETS atclient atchops atlogger)
else()
  message(STATUS "atsdk already installed...")
endif()
