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
      # FIXME before merging: this is the head of at_c#737, not yet released.
      # Replace with the v0.4.3 tag commit once it is tagged.
      # at_c v0.4.3: a re-authentication that fails closes its connection and
      # keeps the connection's hooks (at_c#737) on top of v0.4.2
      GIT_TAG 6507d49bb3305bb143dbb9c48a161a833b8a29e8
    )
  endif()
  FetchContent_MakeAvailable(atsdk)
  install(
    TARGETS atclient atchops atlogger atauth atcommons
  )
endif()
