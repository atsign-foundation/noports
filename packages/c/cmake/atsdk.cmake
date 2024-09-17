if(NOT atsdk_FOUND)
  message(STATUS "atsdk not found, fetching from GitHub..")
  FetchContent_Declare(
    atsdk
    GIT_REPOSITORY https://github.com/atsign-foundation/at_c.git
    GIT_TAG d6e6962d891d18d31d20346a4f236b541d7d5aad
  )
  FetchContent_MakeAvailable(atsdk)
  install(TARGETS atclient atchops atlogger)
else()
  message(STATUS "atsdk already installed...")
endif()
