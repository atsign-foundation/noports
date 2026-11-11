option(NOPORTS_ATSDK_PATH "Local atsdk path" OFF)
if(NOT atsdk_FOUND)
  message(STATUS "[atsdk] fetching package...")
  include(FetchContent)
  if(NOPORTS_ATSDK_PATH)
    FetchContent_Declare(
      atsdk
      SOURCE_DIR
      ${CMAKE_SOURCE_DIR}/${NOPORTS_ATSDK_PATH}
    )
  else()
    FetchContent_Declare(
      atsdk
      GIT_REPOSITORY https://github.com/atsign-foundation/at_c.git
      # INTEGRATION ONLY (not for merge): at_c fix/connection-leak-on-failed-connect
      # (at_c#736, 0.4.2) on top of v0.4.1
      GIT_TAG 1cc1d9192b393619f9d2314e78dcfb721947c3c9
    )
  endif()
  FetchContent_MakeAvailable(atsdk)
  install(
    TARGETS atclient atchops atlogger atauth atcommons
  )
endif()
