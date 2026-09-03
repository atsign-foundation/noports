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
      # INTEGRATION TESTING ONLY - do not merge this pin to trunk.
      # Head of at_c fix/atauth-code-review-findings (at_c#715): the
      # at_activate/atauth + atclient code review fixes, on top of v0.4.0.
      # Replace with the tagged release commit once at_c#715 lands.
      GIT_TAG a4dd5e700062696da590ef987d7b3ad4bd4bd550
    )
  endif()
  FetchContent_MakeAvailable(atsdk)
  install(
    TARGETS atclient atchops atlogger atauth atcommons
  )
endif()
