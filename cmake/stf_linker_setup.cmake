function(setup_stf_linker set_compiler_options)
    if (STF_LINK_SETUP_DONE AND STF_COMPILER_SETUP_DONE)
        message("-- ${PROJECT_NAME} link-time optimization and compiler flags handled by parent project")
        return()
    endif()

    SET(STF_LINK_FLAGS )
    SET(STF_COMPILE_FLAGS )

    # Don't need to change default linker on OS X
    if (NOT CMAKE_CXX_COMPILER_ID MATCHES "AppleClang")
        find_program(GOLD "ld.gold")
        find_program(LLD "ld.lld")

        if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
            if(LLD)
                SET(STF_LINK_FLAGS ${STF_LINK_FLAGS} -fuse-ld=lld)
            elseif(GOLD)
                SET(STF_LINK_FLAGS ${STF_LINK_FLAGS} -fuse-ld=gold)
            else()
                message(FATAL_ERROR "Either ld.lld or ld.gold are required when compiling with clang")
            endif()
        else()
            if(GOLD)
                SET(STF_LINK_FLAGS ${STF_LINK_FLAGS} -fuse-ld=gold)
            else()
                message(FATAL_ERROR "ld.gold is required when compiling with gcc")
            endif()
        endif()
    endif()

    if (CMAKE_BUILD_TYPE MATCHES "^[Dd]ebug")
        SET(STF_LINK_FLAGS ${STF_LINK_FLAGS} -O0 -g -pipe -fno-omit-frame-pointer)
        SET(STF_COMPILE_FLAGS ${STF_COMPILE_FLAGS} -O0 -g -pipe -fno-omit-frame-pointer)
        SET(NO_STF_LTO 1)
    elseif (CMAKE_BUILD_TYPE MATCHES "^[Ff]ast[Dd]ebug")
        SET(STF_LINK_FLAGS ${STF_LINK_FLAGS} -O3 -g -pipe -fno-omit-frame-pointer)
        SET(NO_STF_LTO 1)
    else()
        SET(STF_LINK_FLAGS ${STF_LINK_FLAGS} -O3 -pipe)
        SET(STF_COMPILE_FLAGS ${STF_COMPILE_FLAGS} -O3 -pipe)

        # Enable more aggressive inlining in Clang
        if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
            SET(STF_COMPILE_FLAGS ${STF_COMPILE_FLAGS} -mllvm -inline-threshold=1024)
        endif()

        if (CMAKE_BUILD_TYPE MATCHES "^[Pp]rofile")
            SET(STF_LINK_FLAGS ${STF_LINK_FLAGS} -g -fno-omit-frame-pointer)
            SET(STF_COMPILE_FLAGS ${STF_COMPILE_FLAGS} -g -fno-omit-frame-pointer)
            if(STF_ENABLE_GPROF)
                SET(STF_LINK_FLAGS ${STF_LINK_FLAGS} -pg)
                SET(STF_COMPILE_FLAGS ${STF_COMPILE_FLAGS} -pg)
            endif()
        else()
            SET(STF_LINK_FLAGS ${STF_LINK_FLAGS} -fomit-frame-pointer)
            SET(STF_COMPILE_FLAGS ${STF_COMPILE_FLAGS} -fomit-frame-pointer)
        endif()
    endif()

    if(STF_LINK_SETUP_DONE)
        message("-- ${PROJECT_NAME} link-time optimization handled by parent project")
    elseif(NOT NO_STF_LTO)
        message("-- Enabling link-time optimization in ${PROJECT_NAME}")

        if(FULL_LTO)
            message("--  Full LTO: enabled")
            SET(LTO_FLAGS -flto)
        else()
            if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
                message("--  Full LTO: disabled")
                SET(LTO_FLAGS -flto=thin)
            else()
                message("--  Full LTO: enabled")
                SET(LTO_FLAGS -flto)
            endif()
        endif()

        SET(STF_COMPILE_FLAGS ${STF_COMPILE_FLAGS} ${LTO_FLAGS})
        SET(STF_LINK_FLAGS ${STF_LINK_FLAGS} ${LTO_FLAGS})

        if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
          if (CMAKE_CXX_COMPILER_ID MATCHES "AppleClang")
            SET(CMAKE_AR "ar")
          else()
            unset(LLVM_AR)
            unset(LLVM_AR CACHE)
            # using regular Clang or AppleClang
            find_program(LLVM_AR "llvm-ar")
            if (NOT LLVM_AR)
              unset(LLVM_AR)
              unset(LLVM_AR CACHE)
              find_program(LLVM_AR "llvm-ar-9")
              if (NOT LLVM_AR)
                message(FATAL_ERROR "llvm-ar is needed to link trace_tools on this system")
              else()
                SET(CMAKE_AR "llvm-ar-9")
              endif()
            else()
              SET(CMAKE_AR "llvm-ar")
            endif()
          endif()
        else ()
          SET(CMAKE_AR  "gcc-ar")
        endif()
    else()
        message("-- Disabling link-time optimization in ${PROJECT_NAME}")
    endif()

    if(set_compiler_options)
        if(STF_COMPILER_SETUP_DONE)
            message("--  ${PROJECT_NAME} compiler options handled by parent project")
        else()
            message("--  Set optimized STF compiler options: enabled")
            add_compile_options(${STF_COMPILE_FLAGS})
            SET(STF_COMPILER_SETUP_DONE true PARENT_SCOPE)
        endif()
    else()
        message("--  Set optimized STF compiler options: disabled")
    endif()

    if(NOT STF_LINK_SETUP_DONE)
        add_link_options(${STF_LINK_FLAGS})
        SET(STF_LINK_SETUP_DONE true PARENT_SCOPE)
    endif()

    SET(CMAKE_CXX_ARCHIVE_CREATE "<CMAKE_AR> qcs <TARGET> <LINK_FLAGS> <OBJECTS>")
    SET(CMAKE_CXX_ARCHIVE_FINISH   true)
endfunction()
