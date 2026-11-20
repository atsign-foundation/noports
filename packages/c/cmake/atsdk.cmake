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
      # at_c v0.4.3 (this is the tag commit): a re-authentication that fails
      # closes its connection and keeps the connection's hooks (at_c#737) on
      # top of v0.4.2
      GIT_TAG 9f973cfc00ee70d495ffc845c3ba1bf64aafe44f
    )
  endif()
  FetchContent_MakeAvailable(atsdk)
  install(
    TARGETS atclient atchops atlogger atauth atcommons
  )
endif()
