# File: dracoTesting.cmake

include( FeatureSummary )
option( BUILD_TESTING "Should we compile the tests?" ON )
add_feature_info( BUILD_TESTING BUILD_TESTING
   "Turn off to prevent the compilation of unit tests (ctest).")

# how many cores on the local system?
if( UNIX )
  if( EXISTS "/proc/cpuinfo" )
    file( READ "/proc/cpuinfo" cpuinfo )
    # convert one big string into a set of strings, one per line
    string( REGEX REPLACE "\n" ";" cpuinfo ${cpuinfo} )
    set( proc_ids "" )
    foreach( line ${cpuinfo} )
       if( ${line} MATCHES "processor" )
          list( APPEND proc_ids ${line} )
       endif()
    endforeach()
    list( LENGTH proc_ids DRACO_NUM_CORES )
    set( MPIEXEC_MAX_NUMPROCS ${DRACO_NUM_CORES} CACHE STRING
       "Number of cores on the local machine." )
  endif()
endif()

# enable ctest funcitons and run ctest in parallel if we have multiple cores.
if( BUILD_TESTING )
  include(CTest)
  enable_testing()
  # by default do not use parallel build flags (e.g.: -j16)
  set( pbuildtestflags "" )
  if( WIN32 OR "${MPIEXEC_MAX_NUMPROCS}none" STREQUAL "none"  )
     # stick with scalar builds for now.
  else()
     set( pbuildtestflags "-j${MPIEXEC_MAX_NUMPROCS}" )
  endif()
  if( ${CMAKE_GENERATOR} MATCHES Ninja )
    add_custom_target( check
      COMMAND "${CMAKE_COMMAND}" --build "${Draco_BINARY_DIR}" -- ${pbuildtestflags}
      COMMAND ${CMAKE_CTEST_COMMAND} ${pbuildtestflags} $$(ARGS) )
  else()
    add_custom_target( check
      COMMAND "${CMAKE_COMMAND}" --build "${Draco_BINARY_DIR}" -- ${pbuildtestflags}
      COMMAND ${CMAKE_CTEST_COMMAND} ${pbuildtestflags} $(ARGS) )
  endif()
endif()
