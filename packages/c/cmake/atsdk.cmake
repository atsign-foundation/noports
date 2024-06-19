if(NOT atsdk_FOUND)
  message(STATUS "atsdk not found, fetching from GitHub..")
  FetchContent_Declare(
    atsdk
    GIT_REPOSITORY https://github.com/atsign-foundation/at_c.git
    GIT_TAG dcda1141adc18b8be6608d2849de833c4f959005
  )
  FetchContent_MakeAvailable(atsdk)
  install(TARGETS atclient atchops atlogger)
else()
  message(STATUS "atsdk already installed...")
endif()
