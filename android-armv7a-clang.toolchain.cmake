cmake_minimum_required( VERSION 2.8.12 )

if( DEFINED CMAKE_CROSSCOMPILING )
	# subsequent toolchain loading is not really needed
	return()
endif()

if( CMAKE_TOOLCHAIN_FILE )
	# touch toolchain variable only to suppress "unused variable" warning
endif()

get_property( _CMAKE_IN_TRY_COMPILE GLOBAL PROPERTY IN_TRY_COMPILE )
if( _CMAKE_IN_TRY_COMPILE )
	include( "${CMAKE_CURRENT_SOURCE_DIR}/../android.toolchain.config.cmake" OPTIONAL )
endif()

# this one is important
set( CMAKE_SYSTEM_NAME Linux )
# this one not so much
set( CMAKE_SYSTEM_VERSION 1 )

# rpath makes low sence for Android
set( CMAKE_SKIP_RPATH TRUE CACHE BOOL "If set, runtime paths are not added when using shared libraries." )

set( ANDROID_SUPPORTED_NDK_VERSIONS ${ANDROID_EXTRA_NDK_VERSIONS} 
	-r10b -r10 -r9e -r9d -r9c -r9b -r9 -r8e -r8d -r8c -r8b -r8)
if(NOT DEFINED ANDROID_NDK_SEARCH_PATHS)
	if( CMAKE_HOST_WIN32 )
		file( TO_CMAKE_PATH "$ENV{PROGRAMFILES}" ANDROID_NDK_SEARCH_PATHS )
		set( ANDROID_NDK_SEARCH_PATHS "${ANDROID_NDK_SEARCH_PATHS}/android-ndk" "$ENV{SystemDrive}/NVPACK/android-ndk" )
	else()
		file( TO_CMAKE_PATH "$ENV{HOME}" ANDROID_NDK_SEARCH_PATHS )
		set( ANDROID_NDK_SEARCH_PATHS /opt/android-ndk "${ANDROID_NDK_SEARCH_PATHS}/NVPACK/android-ndk" )
	endif()
endif()

set( ANDROID_SUPPORTED_ABIS_arm "armeabi-v7a;armeabi;armeabi-v7a with NEON;armeabi-v7a with VFPV3;armeabi-v6 with VFP" )
set( ANDROID_SUPPORTED_ABIS_x86 "x86" )
set( ANDROID_SUPPORTED_ABIS_mipsel "mips" )

set( ANDROID_SUPPORTED_ABIS_ALL ${ANDROID_SUPPORTED_ABIS_arm} ${ANDROID_SUPPORTED_ABIS_x86} ${ANDROID_SUPPORTED_ABIS_mips})

set( ANDROID_DEFAULT_NDK_API_LEVEL_arm 8 )
set( ANDROID_DEFAULT_NDK_API_LEVEL_x86 9 )
set( ANDROID_DEFAULT_NDK_API_LEVEL_mips 9 )


macro( __INIT_VARIABLE var_name )
	set( __test_path 0 )
	foreach( __var ${ARGN} )
		if( __var STREQUAL "PATH" )
			set( __test_path 1 )
			break()
		endif()
	endforeach()
	if( __test_path AND NOT EXISTS "${${var_name}}" )
		unset( ${var_name} CACHE )
	endif()
	if( "${${var_name}}" STREQUAL "" )
		set( __values 0 )
		foreach( __var ${ARGN} )
			if( __var STREQUAL "VALUES" )
				set( __values 1 )
			elseif( NOT __var STREQUAL "PATH" )
				set( __obsolete 0 )
				if( __var MATCHES "^OBSOLETE_.*$" )
					string( REPLACE "OBSOLETE_" "" __var "${__var}" )
					set( __obsolete 1 )
				endif()
				if( __var MATCHES "^ENV_.*$" )
					string( REPLACE "ENV_" "" __var "${__var}" )
					set( __value "$ENV{${__var}}" )
				elseif( DEFINED ${__var} )
					set( __value "${${__var}}" )
				else()
					if( __values )
						set( __value "${__var}" )
					else()
						set( __value "" )
					endif()
				endif()
				if( NOT "${__value}" STREQUAL "" )
					if( __test_path )
						if( EXISTS "${__value}" )
							file( TO_CMAKE_PATH "${__value}" ${var_name} )
							if( __obsolete AND NOT _CMAKE_IN_TRY_COMPILE )
								message( WARNING "Using value of obsolete variable ${__var} as initial value for ${var_name}. Please note, that ${__var} can be completely removed in future versions of the toolchain." )
							endif()
							break()
						endif()
					else()
						set( ${var_name} "${__value}" )
						if( __obsolete AND NOT _CMAKE_IN_TRY_COMPILE )
							message( WARNING "Using value of obsolete variable ${__var} as initial value for ${var_name}. Please note, that ${__var} can be completely removed in future versions of the toolchain." )
						endif()
						break()
					endif()
				endif()
			endif()
		endforeach()
		unset( __value )
		unset( __values )
		unset( __obsolete )
	elseif( __test_path )
		file( TO_CMAKE_PATH "${${var_name}}" ${var_name} )
	endif()
	unset( __test_path )
endmacro()

if( CYGWIN )
	message( FATAL_ERROR "Android NDK and android-cmake toolchain are not welcome Cygwin. It is unlikely that this cmake toolchain will work under cygwin. But if you want to try then you can set cmake variable ANDROID_FORBID_SYGWIN to FALSE and rerun cmake." )
endif()

# detect current host platform
if( NOT DEFINED ANDROID_NDK_HOST_X64 AND (CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "amd64|x86_64|AMD64" OR CMAKE_HOST_APPLE) )
	set( ANDROID_NDK_HOST_X64 1 CACHE BOOL "Try to use 64-bit compiler toolchain" )
	mark_as_advanced( ANDROID_NDK_HOST_X64 )
endif()
set( TOOL_OS_SUFFIX "" )
if( CMAKE_HOST_APPLE )
	set( ANDROID_NDK_HOST_SYSTEM_NAME "darwin-x86_64" )
	set( ANDROID_NDK_HOST_SYSTEM_NAME2 "darwin-x86" )
elseif( CMAKE_HOST_WIN32 )
	set( ANDROID_NDK_HOST_SYSTEM_NAME "windows-x86_64" )
	set( ANDROID_NDK_HOST_SYSTEM_NAME2 "windows" )
	set( TOOL_OS_SUFFIX ".exe" )
elseif( CMAKE_HOST_UNIX )
	set( ANDROID_NDK_HOST_SYSTEM_NAME "linux-x86_64" )
	set( ANDROID_NDK_HOST_SYSTEM_NAME2 "linux-x86" )
else()
	message( FATAL_ERROR "Cross-compilation on your platform is not supported by this cmake toolchain" )
endif()

if( NOT ANDROID_NDK_HOST_X64 )
	set( ANDROID_NDK_HOST_SYSTEM_NAME ${ANDROID_NDK_HOST_SYSTEM_NAME2} )
endif()

# see if we have path to Android NDK
find_path(ANDROID_NDK
	NAMES 
		"ndk-build"
		"ndk-build.bat"
	PATHS
		"$ENV{ANDROID_NDK}"
		"$ENV{ANDROID_NDK_HOME}"
)
if( NOT ANDROID_NDK )
	#try to find Android NDK in one of the the default locations
	set( __ndkSearchPaths )
	foreach( __ndkSearchPath ${ANDROID_NDK_SEARCH_PATHS} )
		foreach( suffix ${ANDROID_SUPPORTED_NDK_VERSIONS} )
			list( APPEND __ndkSearchPaths "${__ndkSearchPath}${suffix}" )
		endforeach()
	endforeach()
	find_path(ANDROID_NDK
		NAMES 
			"ndk-build"
			"ndk-build.bat"
		PATHS
			${__ndkSearchPaths}
	)
	unset( __ndkSearchPaths )

	if( ANDROID_NDK )
		message( STATUS "Using default path for Android NDK: ${ANDROID_NDK}" )
		message( STATUS "  If you prefer to use a different location, please define a cmake or environment variable: ANDROID_NDK" )
	endif( ANDROID_NDK )
endif( NOT ANDROID_NDK )

# remember found paths
if( ANDROID_NDK )
	get_filename_component( ANDROID_NDK "${ANDROID_NDK}" ABSOLUTE )
	set( ANDROID_NDK "${ANDROID_NDK}" CACHE PATH "Path of the Android NDK" FORCE )
	set( BUILD_WITH_ANDROID_NDK True )
	if( EXISTS "${ANDROID_NDK}/RELEASE.TXT" )
		file( STRINGS "${ANDROID_NDK}/RELEASE.TXT" ANDROID_NDK_RELEASE_FULL LIMIT_COUNT 1 REGEX r[0-9]+[a-z]? )
		string( REGEX MATCH r[0-9]+[a-z]? ANDROID_NDK_RELEASE "${ANDROID_NDK_RELEASE_FULL}" )
	else()
		set( ANDROID_NDK_RELEASE "r1x" )
		set( ANDROID_NDK_RELEASE_FULL "unreleased" )
	endif()
else()
	list(GET ANDROID_NDK_SEARCH_PATHS 0 ANDROID_NDK_SEARCH_PATH)
	message( FATAL_ERROR "Could not find Android NDK.
    You should set an environment variable:
      export ANDROID_NDK=~/my-android-ndk" )
endif()

# android NDK layout
if( BUILD_WITH_ANDROID_NDK )
	if( NOT DEFINED ANDROID_NDK_LAYOUT )
		# try to automatically detect the layout
		if( EXISTS "${ANDROID_NDK}/RELEASE.TXT")
			set( ANDROID_NDK_LAYOUT "RELEASE" )
		endif()
	endif()

	set( ANDROID_NDK_LAYOUT "${ANDROID_NDK_LAYOUT}" CACHE STRING "The inner layout of NDK" )
	mark_as_advanced( ANDROID_NDK_LAYOUT )

	set( ANDROID_NDK_TOOLCHAINS_PATH "${ANDROID_NDK}/toolchains" )
	set( ANDROID_NDK_TOOLCHAINS_SUBPATH  "/prebuilt/${ANDROID_NDK_HOST_SYSTEM_NAME}" )
	set( ANDROID_NDK_TOOLCHAINS_SUBPATH2 "/prebuilt/${ANDROID_NDK_HOST_SYSTEM_NAME2}" )
	get_filename_component( ANDROID_NDK_TOOLCHAINS_PATH "${ANDROID_NDK_TOOLCHAINS_PATH}" ABSOLUTE )
endif()

# extract clang toolchains
file( GLOB ANDROID_SUPPORTED_NATIVE_API_LEVELS RELATIVE "${ANDROID_NDK}/platforms" "${ANDROID_NDK}/platforms/android-*" )
string( REPLACE "android-" "" ANDROID_SUPPORTED_NATIVE_API_LEVELS "${ANDROID_SUPPORTED_NATIVE_API_LEVELS}" )

set(ANDROID_ABI "armeabi-v7a" CACHE STRING "Selected Android ABI for this build")
set_property(CACHE ANDROID_ABI PROPERTY STRINGS ${ANDROID_SUPPORTED_ABIS_ALL})

# set target ABI options
if( ANDROID_ABI STREQUAL "x86" )
	set( X86 true )
	set( ANDROID_NDK_ABI_NAME "x86" )
	set( ANDROID_ARCH_NAME "x86" )
	set( ANDROID_ARCH_FULLNAME "x86" )
	set( ANDROID_LLVM_TRIPLE "i686-none-linux-android" )
	set( CMAKE_SYSTEM_PROCESSOR "i686" )
	set( ANDROID_TOOLCHAIN_PREFIX "x86" )
	set( ANDROID_TOOLCHAIN_GCC_PREFIX "i686-linux-android" )
elseif( ANDROID_ABI STREQUAL "mips" )
	set( MIPS true )
	set( ANDROID_NDK_ABI_NAME "mips" )
	set( ANDROID_ARCH_NAME "mips" )
	set( ANDROID_ARCH_FULLNAME "mipsel" )
	set( ANDROID_LLVM_TRIPLE "mipsel-none-linux-android" )
	set( CMAKE_SYSTEM_PROCESSOR "mips" )
	set( ANDROID_TOOLCHAIN_PREFIX "mipsel-linux-android" )
elseif( ANDROID_ABI STREQUAL "armeabi" )
	set( ARMEABI true )
	set( ANDROID_NDK_ABI_NAME "armeabi" )
	set( ANDROID_ARCH_NAME "arm" )
	set( ANDROID_ARCH_FULLNAME "arm" )
	set( ANDROID_LLVM_TRIPLE "armv5te-none-linux-androideabi" )
	set( CMAKE_SYSTEM_PROCESSOR "armv5te" )
	set( ANDROID_TOOLCHAIN_PREFIX "arm-linux-androideabi" )
elseif( ANDROID_ABI STREQUAL "armeabi-v6 with VFP" )
	set( ARMEABI_V6 true )
	set( ANDROID_NDK_ABI_NAME "armeabi" )
	set( ANDROID_ARCH_NAME "arm" )
	set( ANDROID_ARCH_FULLNAME "arm" )
	set( ANDROID_LLVM_TRIPLE "armv5te-none-linux-androideabi" )
	set( ANDROID_TOOLCHAIN_PREFIX "arm-linux-androideabi" )
	set( CMAKE_SYSTEM_PROCESSOR "armv6" )
	# need always fallback to older platform
	set( ARMEABI true )
elseif( ANDROID_ABI STREQUAL "armeabi-v7a")
	set( ARMEABI_V7A true )
	set( ANDROID_NDK_ABI_NAME "armeabi-v7a" )
	set( ANDROID_ARCH_NAME "arm" )
	set( ANDROID_ARCH_FULLNAME "arm" )
	set( ANDROID_LLVM_TRIPLE "armv7-none-linux-androideabi" )
	set( ANDROID_TOOLCHAIN_PREFIX "arm-linux-androideabi" )
	set( CMAKE_SYSTEM_PROCESSOR "armv7-a" )
elseif( ANDROID_ABI STREQUAL "armeabi-v7a with VFPV3" )
	set( ARMEABI_V7A true )
	set( ANDROID_NDK_ABI_NAME "armeabi-v7a" )
	set( ANDROID_ARCH_NAME "arm" )
	set( ANDROID_ARCH_FULLNAME "arm" )
	set( ANDROID_LLVM_TRIPLE "armv7-none-linux-androideabi" )
	set( ANDROID_TOOLCHAIN_PREFIX "arm-linux-androideabi" )
	set( CMAKE_SYSTEM_PROCESSOR "armv7-a" )
	set( VFPV3 true )
elseif( ANDROID_ABI STREQUAL "armeabi-v7a with NEON" )
	set( ARMEABI_V7A true )
	set( ANDROID_NDK_ABI_NAME "armeabi-v7a" )
	set( ANDROID_ARCH_NAME "arm" )
	set( ANDROID_ARCH_FULLNAME "arm" )
	set( ANDROID_LLVM_TRIPLE "armv7-none-linux-androideabi" )
	set( ANDROID_TOOLCHAIN_PREFIX "arm-linux-androideabi" )
	set( CMAKE_SYSTEM_PROCESSOR "armv7-a" )
	set( VFPV3 true )
	set( NEON true )
else()
	message( SEND_ERROR "Unknown ANDROID_ABI=\"${ANDROID_ABI}\" is specified." )
endif()

# check that toolchain realy exists
file(GLOB ANDROID_availableToolchainsList RELATIVE "${ANDROID_NDK_TOOLCHAINS_PATH}" "${ANDROID_NDK_TOOLCHAINS_PATH}/${ANDROID_TOOLCHAIN_PREFIX}-*" )
list(SORT ANDROID_availableToolchainsList)

if( CMAKE_BINARY_DIR AND EXISTS "${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/CMakeSystem.cmake" )
	# really dirty hack
	# it is not possible to change CMAKE_SYSTEM_PROCESSOR after the first run...
	file( APPEND "${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/CMakeSystem.cmake" "SET(CMAKE_SYSTEM_PROCESSOR \"${CMAKE_SYSTEM_PROCESSOR}\")\n" )
endif()

if(ARMEABI_V7A)
	set(ANDROID_FORCE_ARM_BUILD "OFF" CACHE BOOL "Use 32-bit ARM instructions instead of Thumb-1")
	mark_as_advanced(ANDROID_FORCE_ARM_BUILD)
else()
	unset(ANDROID_FORCE_ARM_BUILD CACHE)
endif()

# choose toolchain
set(ANDROID_PREFER_CLANG "ON" CACHE BOOL "Use Clang instead of GCC when available")

if(ANDROID_TOOLCHAIN_NAME)
	list(FIND ANDROID_availableToolchainsList "${ANDROID_TOOLCHAIN_NAME}" toolchainIdx)
	if(toolchainIdx EQUAL -1)
		list(SORT ANDROID_availableToolchainsList)
		string(REPLACE ";" "\n  * " toolchains_list "${ANDROID_availableToolchainsList}")
		set(toolchains_list "  * ${toolchains_list}")
		message(FATAL_ERROR 
"Specified toolchain \"${ANDROID_TOOLCHAIN_NAME}\" is missing in your NDK or broken. 
Please verify that your NDK is working or select another compiler toolchain.
To configure the toolchain set CMake variable ANDROID_TOOLCHAIN_NAME to one of the following values:\n${toolchains_list}\n" )
	endif()
else()
	set(best_clang "")
	set(best_clang_ver "0")
	set(best_gcc "")
	set(best_gcc_ver "0")
	
	foreach(tc ${ANDROID_availableToolchainsList} )
		string(REGEX MATCH "[0-9]+[.][0-9]+([.][0-9x]+)?$" version "${tc}" )
		
		if(tc MATCHES "-clang")
			if("${best_clang_ver}" VERSION_LESS version)
				set(best_clang_ver "${version}")
				set(best_clang "${tc}")
			endif()
		else()
			if("${best_gcc_ver}" VERSION_LESS version)
				set(best_gcc_ver "${version}")
				set(best_gcc "${tc}")
			endif()
		endif()
	endforeach()

	if(ANDROID_PREFER_CLANG)
		if(best_clang)
			set(ANDROID_TOOLCHAIN_NAME "${best_clang}")
			set(ANDROID_COMPILER_IS_CLANG 1)
			set(ANDROID_COMPILER_VERSION "${best_clang_ver}")
		else()
			set(ANDROID_TOOLCHAIN_NAME "${best_gcc}")
			set(ANDROID_COMPILER_VERSION "${best_gcc_ver}")
		endif()
	else()
		if(best_gcc)
			set(ANDROID_TOOLCHAIN_NAME "${best_gcc}")
			set(ANDROID_COMPILER_VERSION "${best_gcc_ver}")
		else()
			set(ANDROID_TOOLCHAIN_NAME "${best_clang}")
			set(ANDROID_COMPILER_IS_CLANG 1)
			set(ANDROID_COMPILER_VERSION "${best_clang_ver}")
		endif()
	endif()

	if(best_gcc)
		set(ANDROID_GCC_VERSION "${best_gcc_ver}")
	endif()
	
	unset(best_clang)
	unset(best_clang_ver)
	unset(best_gcc)
	unset(best_gcc_ver)
endif()

if(NOT ANDROID_TOOLCHAIN_NAME)
	message( FATAL_ERROR "No one of available compiler toolchains is able to compile for ${ANDROID_ARCH_NAME} platform." )
endif()
# ANDROID_TOOLCHAIN_MACHINE_NAME ???

unset(ANDROID_availableToolchainsList)

# clang
if(ANDROID_COMPILER_IS_CLANG)
	string( REGEX REPLACE "-clang${ANDROID_COMPILER_VERSION}\$" "-4.6" ANDROID_GCC_TOOLCHAIN_NAME "${ANDROID_TOOLCHAIN_NAME}" )
	if(NOT EXISTS "${ANDROID_NDK_TOOLCHAINS_PATH}/llvm-${ANDROID_COMPILER_VERSION}${ANDROID_NDK_TOOLCHAINS_SUBPATH}/bin/clang${TOOL_OS_SUFFIX}" )
		message( FATAL_ERROR "Could not find the Clang compiler driver" )
	endif()
	set(ANDROID_CLANG_TOOLCHAIN_ROOT "${ANDROID_NDK_TOOLCHAINS_PATH}/llvm-${ANDROID_COMPILER_VERSION}${ANDROID_NDK_TOOLCHAINS_SUBPATH}" )
	
	# figure out how clang executable is called
	string(REPLACE "." "" ANDROID_striped_version ANDROID_COMPILER_VERSION)
	find_program(ANDROID_COMPILER_CLANG_C
		NAMES 
			"clang" "clang${ANDROID_COMPILER_VERSION}" "clang${ANDROID_striped_version}"
		PATHS
			"${ANDROID_CLANG_TOOLCHAIN_ROOT}/bin/"
		NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH)
	find_program(ANDROID_COMPILER_CLANG_CXX
		NAMES 
			"clang++" "clang${ANDROID_COMPILER_VERSION}++" "clang${ANDROID_striped_version}++"
		PATHS
			"${ANDROID_CLANG_TOOLCHAIN_ROOT}/bin/"
		NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH)
else()
	set(ANDROID_GCC_TOOLCHAIN_NAME "${ANDROID_TOOLCHAIN_NAME}" )
endif()

# choose native API level
# __INIT_VARIABLE( ANDROID_NATIVE_API_LEVEL ENV_ANDROID_NATIVE_API_LEVEL ANDROID_API_LEVEL ENV_ANDROID_API_LEVEL ANDROID_STANDALONE_TOOLCHAIN_API_LEVEL ANDROID_DEFAULT_NDK_API_LEVEL_${ANDROID_ARCH_NAME} ANDROID_DEFAULT_NDK_API_LEVEL )
# string( REGEX MATCH "[0-9]+" ANDROID_NATIVE_API_LEVEL "${ANDROID_NATIVE_API_LEVEL}" )
# adjust API level
#set( __real_api_level ${ANDROID_DEFAULT_NDK_API_LEVEL_${ANDROID_ARCH_NAME}} )
#foreach( __level ${ANDROID_SUPPORTED_NATIVE_API_LEVELS} )
#	if( NOT __level GREATER ANDROID_NATIVE_API_LEVEL AND NOT __level LESS __real_api_level )
#		set( __real_api_level ${__level} )
#	endif()
#endforeach()
#if( __real_api_level AND NOT ANDROID_NATIVE_API_LEVEL EQUAL __real_api_level )
#	message( STATUS "Adjusting Android API level 'android-${ANDROID_NATIVE_API_LEVEL}' to 'android-${__real_api_level}'")
#	set( ANDROID_NATIVE_API_LEVEL ${__real_api_level} )
#endif()
#unset(__real_api_level)
## validate
#list( FIND ANDROID_SUPPORTED_NATIVE_API_LEVELS "${ANDROID_NATIVE_API_LEVEL}" __levelIdx )
#if( __levelIdx EQUAL -1 )
#	message( SEND_ERROR "Specified Android native API level 'android-${ANDROID_NATIVE_API_LEVEL}' is not supported by your NDK/toolchain." )
#else()
#	if( BUILD_WITH_ANDROID_NDK )
#		__DETECT_NATIVE_API_LEVEL( __realApiLevel "${ANDROID_NDK}/platforms/android-${ANDROID_NATIVE_API_LEVEL}/arch-${ANDROID_ARCH_NAME}/usr/include/android/api-level.h" )
#		if( NOT __realApiLevel EQUAL ANDROID_NATIVE_API_LEVEL )
#			message( SEND_ERROR "Specified Android API level (${ANDROID_NATIVE_API_LEVEL}) does not match to the level found (${__realApiLevel}). Probably your copy of NDK is broken." )
#		endif()
#		unset( __realApiLevel )
#	endif()
#	set( ANDROID_NATIVE_API_LEVEL "${ANDROID_NATIVE_API_LEVEL}" CACHE STRING "Android API level for native code" FORCE )
#	if( CMAKE_VERSION VERSION_GREATER "2.8" )
#		list( SORT ANDROID_SUPPORTED_NATIVE_API_LEVELS )
#		set_property( CACHE ANDROID_NATIVE_API_LEVEL PROPERTY STRINGS ${ANDROID_SUPPORTED_NATIVE_API_LEVELS} )
#	endif()
#endif()
#unset( __levelIdx )

set( ANDROID_NATIVE_API_LEVEL "8" CACHE STRING "Android API level for native code")
set_property( CACHE ANDROID_NATIVE_API_LEVEL PROPERTY STRINGS ${ANDROID_SUPPORTED_NATIVE_API_LEVELS} )


# runtime choice (STL, rtti, exceptions)
set(ANDROID_STL "gnustl_static" CACHE STRING "C++ runtime")
set(ANDROID_STL_FORCE_FEATURES ON CACHE BOOL "automatically configure rtti and exceptions support based on C++ runtime")
mark_as_advanced( ANDROID_STL ANDROID_STL_FORCE_FEATURES )

if( BUILD_WITH_ANDROID_NDK )
	if( NOT "${ANDROID_STL}" MATCHES "^(none|system|system_re|gabi\\+\\+_static|gabi\\+\\+_shared|stlport_static|stlport_shared|gnustl_static|gnustl_shared|c\\+\\+_static|c\\+\\+_shared)$")
		message( FATAL_ERROR "ANDROID_STL is set to invalid value \"${ANDROID_STL}\".
The possible values are:
  none           -> Do not configure the runtime.
  system         -> Use the default minimal system C++ runtime library.
  system_re      -> Same as system but with rtti and exceptions.
  gabi++_static  -> Use the GAbi++ runtime as a static library.
  gabi++_shared  -> Use the GAbi++ runtime as a shared library.
  stlport_static -> Use the STLport runtime as a static library.
  stlport_shared -> Use the STLport runtime as a shared library.
  gnustl_static  -> (default) Use the GNU STL as a static library.
  gnustl_shared  -> Use the GNU STL as a shared library.
  c++_static     -> Use the LLVM LibC++ runtime as a static library.
  c++_shared     -> Use the LLVM LibC++ runtime as a shared library.
" )
	endif()
endif()

unset( ANDROID_RTTI )
unset( ANDROID_EXCEPTIONS )
unset( ANDROID_STL_INCLUDE_DIRS )
unset( __libstl )
unset( __libsupcxx )

# setup paths and STL for NDK
if( BUILD_WITH_ANDROID_NDK )
	set( ANDROID_TOOLCHAIN_ROOT "${ANDROID_NDK_TOOLCHAINS_PATH}/${ANDROID_GCC_TOOLCHAIN_NAME}${ANDROID_NDK_TOOLCHAINS_SUBPATH}" )
	set( ANDROID_SYSROOT "${ANDROID_NDK}/platforms/android-${ANDROID_NATIVE_API_LEVEL}/arch-${ANDROID_ARCH_NAME}" )

	if( ANDROID_STL STREQUAL "none" )
		# do nothing
	elseif( ANDROID_STL STREQUAL "system" )
		set( ANDROID_RTTI             OFF )
		set( ANDROID_EXCEPTIONS       OFF )
		set( ANDROID_STL_INCLUDE_DIRS "${ANDROID_NDK}/sources/cxx-stl/system/include" )
	elseif( ANDROID_STL STREQUAL "system_re" )
		set( ANDROID_RTTI             ON )
		set( ANDROID_EXCEPTIONS       ON )
		set( ANDROID_STL_INCLUDE_DIRS "${ANDROID_NDK}/sources/cxx-stl/system/include" )
	elseif( ANDROID_STL MATCHES "gabi" )
		set( ANDROID_RTTI             ON )
		set( ANDROID_EXCEPTIONS       OFF )
		set( ANDROID_STL_INCLUDE_DIRS "${ANDROID_NDK}/sources/cxx-stl/gabi++/include" )
		set( __libstl                 "${ANDROID_NDK}/sources/cxx-stl/gabi++/libs/${ANDROID_NDK_ABI_NAME}/libgabi++_static.a" )
	elseif( ANDROID_STL MATCHES "stlport" )
		if( NOT ANDROID_NDK_RELEASE STRLESS "r8d" )
			set( ANDROID_EXCEPTIONS       ON )
		else()
			set( ANDROID_EXCEPTIONS       OFF )
		endif()
		if( ANDROID_NDK_RELEASE STRLESS "r7" )
			set( ANDROID_RTTI            OFF )
		else()
			set( ANDROID_RTTI            ON )
		endif()
		set( ANDROID_STL_INCLUDE_DIRS "${ANDROID_NDK}/sources/cxx-stl/stlport/stlport" )
		set( __libstl                 "${ANDROID_NDK}/sources/cxx-stl/stlport/libs/${ANDROID_NDK_ABI_NAME}/libstlport_static.a" )
	elseif( ANDROID_STL MATCHES "gnustl" )
		set( ANDROID_EXCEPTIONS       ON )
		set( ANDROID_RTTI             ON )
		if( EXISTS "${ANDROID_NDK}/sources/cxx-stl/gnu-libstdc++/${ANDROID_GCC_VERSION}" )
			if( ARMEABI_V7A AND ANDROID_GCC_VERSION VERSION_EQUAL "4.7" AND ANDROID_NDK_RELEASE STREQUAL "r8d" )
				# gnustl binary for 4.7 compiler is buggy :(
				# TODO: look for right fix
				set( __libstl                "${ANDROID_NDK}/sources/cxx-stl/gnu-libstdc++/4.6" )
			else()
				set( __libstl                "${ANDROID_NDK}/sources/cxx-stl/gnu-libstdc++/${ANDROID_GCC_VERSION}" )
			endif()
		else()
			set( __libstl                "${ANDROID_NDK}/sources/cxx-stl/gnu-libstdc++" )
		endif()
		set( ANDROID_STL_INCLUDE_DIRS "${__libstl}/include" "${__libstl}/libs/${ANDROID_NDK_ABI_NAME}/include" )
		if( EXISTS "${__libstl}/libs/${ANDROID_NDK_ABI_NAME}/libgnustl_static.a" )
			set( __libstl                "${__libstl}/libs/${ANDROID_NDK_ABI_NAME}/libgnustl_static.a" )
		else()
			set( __libstl                "${__libstl}/libs/${ANDROID_NDK_ABI_NAME}/libstdc++.a" )
		endif()
	elseif( ANDROID_STL MATCHES "c\\+\\+" )
		set( ANDROID_EXCEPTIONS       ON )
		set( ANDROID_RTTI             ON )
		set( __libstl                "${ANDROID_NDK}/sources/cxx-stl/llvm-libc++" )
		set( ANDROID_STL_INCLUDE_DIRS "${__libstl}/libcxx/include" "${__libstl}/libs/${ANDROID_NDK_ABI_NAME}/include" )
		set( __libstl                "${__libstl}/libs/${ANDROID_NDK_ABI_NAME}/libc++_static.a" )
	else()
		message( FATAL_ERROR "Unknown runtime: ${ANDROID_STL}" )
	endif()
	
	# find libsupc++.a - rtti & exceptions
	if( ANDROID_STL STREQUAL "system_re" OR ANDROID_STL MATCHES "gnustl" )
		set( __libsupcxx "${ANDROID_NDK}/sources/cxx-stl/gnu-libstdc++/${ANDROID_GCC_VERSION}/libs/${ANDROID_NDK_ABI_NAME}/libsupc++.a" ) # r8b or newer
		if( NOT EXISTS "${__libsupcxx}" )
			set( __libsupcxx "${ANDROID_NDK}/sources/cxx-stl/gnu-libstdc++/libs/${ANDROID_NDK_ABI_NAME}/libsupc++.a" ) # r7-r8
		endif()
		
#		if( NOT EXISTS "${__libsupcxx}")
#			message( ERROR "Could not find libsupc++.a for a chosen platform. Either your NDK is not supported or is broken.")
#		endif()
	endif()
endif()

# case of shared STL linkage
if( ANDROID_STL MATCHES "shared" AND DEFINED __libstl )
	string( REPLACE "_static.a" "_shared.so" __libstl "${__libstl}" )
	# TODO: check if .so file exists before the renaming
endif()

# setup the cross-compiler
if(NOT CMAKE_C_COMPILER)
	if( ANDROID_COMPILER_IS_CLANG )
		set(CMAKE_C_COMPILER   "${ANDROID_COMPILER_CLANG_C}"   CACHE PATH "C compiler")
		set(CMAKE_CXX_COMPILER "${ANDROID_COMPILER_CLANG_CXX}" CACHE PATH "C++ compiler")
	else()
		set(CMAKE_C_COMPILER   "${ANDROID_TOOLCHAIN_ROOT}/bin/${ANDROID_TOOLCHAIN_PREFIX}-gcc${TOOL_OS_SUFFIX}"    CACHE PATH "C compiler")
		set(CMAKE_CXX_COMPILER "${ANDROID_TOOLCHAIN_ROOT}/bin/${ANDROID_TOOLCHAIN_PREFIX}-g++${TOOL_OS_SUFFIX}"    CACHE PATH "C++ compiler")
	endif()
	set( CMAKE_ASM_COMPILER "${ANDROID_TOOLCHAIN_ROOT}/bin/${ANDROID_TOOLCHAIN_PREFIX}-gcc${TOOL_OS_SUFFIX}"     CACHE PATH "assembler" )
	set( CMAKE_STRIP        "${ANDROID_TOOLCHAIN_ROOT}/bin/${ANDROID_TOOLCHAIN_PREFIX}-strip${TOOL_OS_SUFFIX}"   CACHE PATH "strip" )
	set( CMAKE_AR           "${ANDROID_TOOLCHAIN_ROOT}/bin/${ANDROID_TOOLCHAIN_PREFIX}-ar${TOOL_OS_SUFFIX}"      CACHE PATH "archive" )
	set( CMAKE_LINKER       "${ANDROID_TOOLCHAIN_ROOT}/bin/${ANDROID_TOOLCHAIN_PREFIX}-ld${TOOL_OS_SUFFIX}"      CACHE PATH "linker" )
	set( CMAKE_NM           "${ANDROID_TOOLCHAIN_ROOT}/bin/${ANDROID_TOOLCHAIN_PREFIX}-nm${TOOL_OS_SUFFIX}"      CACHE PATH "nm" )
	set( CMAKE_OBJCOPY      "${ANDROID_TOOLCHAIN_ROOT}/bin/${ANDROID_TOOLCHAIN_PREFIX}-objcopy${TOOL_OS_SUFFIX}" CACHE PATH "objcopy" )
	set( CMAKE_OBJDUMP      "${ANDROID_TOOLCHAIN_ROOT}/bin/${ANDROID_TOOLCHAIN_PREFIX}-objdump${TOOL_OS_SUFFIX}" CACHE PATH "objdump" )
	set( CMAKE_RANLIB       "${ANDROID_TOOLCHAIN_ROOT}/bin/${ANDROID_TOOLCHAIN_PREFIX}-ranlib${TOOL_OS_SUFFIX}"  CACHE PATH "ranlib" )
endif()

set( _CMAKE_TOOLCHAIN_PREFIX "${ANDROID_TOOLCHAIN_PREFIX}-" )
if( CMAKE_VERSION VERSION_LESS 2.8.5 )
	set( CMAKE_ASM_COMPILER_ARG1 "-c" )
endif()
if( APPLE )
	find_program( CMAKE_INSTALL_NAME_TOOL NAMES install_name_tool )
	if( NOT CMAKE_INSTALL_NAME_TOOL )
		message( FATAL_ERROR "Could not find install_name_tool, please check your installation." )
	endif()
	mark_as_advanced( CMAKE_INSTALL_NAME_TOOL )
endif()

# flags and definitions
remove_definitions( -DANDROID )
add_definitions( -DANDROID )

if(ANDROID_SYSROOT MATCHES "[ ;\"]")
	# quotes can break try_compile and compiler identification
	message(WARNING "Path to your Android NDK (or toolchain) has non-alphanumeric symbols.\nThe build might be broken.\n")
endif()
set( ANDROID_CXX_FLAGS "--sysroot=${ANDROID_SYSROOT}" )

# NDK flags
if( ARMEABI OR ARMEABI_V7A )
	set( ANDROID_CXX_FLAGS "${ANDROID_CXX_FLAGS} -fpic -funwind-tables" )
	if( NOT ANDROID_FORCE_ARM_BUILD AND NOT ARMEABI_V6 )
		set( ANDROID_CXX_FLAGS_RELEASE "-mthumb -fomit-frame-pointer -fno-strict-aliasing" )
		set( ANDROID_CXX_FLAGS_DEBUG   "-marm -fno-omit-frame-pointer -fno-strict-aliasing" )
		if( NOT ANDROID_COMPILER_IS_CLANG )
			set( ANDROID_CXX_FLAGS "${ANDROID_CXX_FLAGS} -finline-limit=64" )
		endif()
	else()
		# always compile ARMEABI_V6 in arm mode; otherwise there is no difference from ARMEABI
		set( ANDROID_CXX_FLAGS_RELEASE "-marm -fomit-frame-pointer -fstrict-aliasing" )
		set( ANDROID_CXX_FLAGS_DEBUG   "-marm -fno-omit-frame-pointer -fno-strict-aliasing" )
		if( NOT ANDROID_COMPILER_IS_CLANG )
			set( ANDROID_CXX_FLAGS "${ANDROID_CXX_FLAGS} -funswitch-loops -finline-limit=300" )
		endif()
	endif()
elseif( X86 )
	set( ANDROID_CXX_FLAGS "${ANDROID_CXX_FLAGS} -funwind-tables" )
	if( NOT ANDROID_COMPILER_IS_CLANG )
		set( ANDROID_CXX_FLAGS "${ANDROID_CXX_FLAGS} -funswitch-loops -finline-limit=300" )
	else()
		set( ANDROID_CXX_FLAGS "${ANDROID_CXX_FLAGS} -fPIC" )
	endif()
	set( ANDROID_CXX_FLAGS_RELEASE "-fomit-frame-pointer -fstrict-aliasing" )
	set( ANDROID_CXX_FLAGS_DEBUG   "-fno-omit-frame-pointer -fno-strict-aliasing" )
elseif( MIPS )
	set( ANDROID_CXX_FLAGS         "${ANDROID_CXX_FLAGS} -fpic -fno-strict-aliasing -finline-functions -ffunction-sections -funwind-tables -fmessage-length=0" )
	set( ANDROID_CXX_FLAGS_RELEASE "-fomit-frame-pointer" )
	set( ANDROID_CXX_FLAGS_DEBUG   "-fno-omit-frame-pointer" )
	if( NOT ANDROID_COMPILER_IS_CLANG )
		set( ANDROID_CXX_FLAGS "${ANDROID_CXX_FLAGS} -fno-inline-functions-called-once -fgcse-after-reload -frerun-cse-after-loop -frename-registers" )
		set( ANDROID_CXX_FLAGS_RELEASE "${ANDROID_CXX_FLAGS_RELEASE} -funswitch-loops -finline-limit=300" )
	endif()
elseif()
	set( ANDROID_CXX_FLAGS_RELEASE "" )
	set( ANDROID_CXX_FLAGS_DEBUG   "" )
endif()

set( ANDROID_CXX_FLAGS "${ANDROID_CXX_FLAGS} -fsigned-char" ) # good/necessary when porting desktop libraries

if( NOT X86 AND NOT ANDROID_COMPILER_IS_CLANG )
	set( ANDROID_CXX_FLAGS "-Wno-psabi ${ANDROID_CXX_FLAGS}" )
endif()

if( NOT ANDROID_COMPILER_VERSION VERSION_LESS "4.6" AND NOT ANDROID_COMPILER_IS_CLANG )
	set( ANDROID_CXX_FLAGS "${ANDROID_CXX_FLAGS} -no-canonical-prefixes" ) # see https://android-review.googlesource.com/#/c/47564/
endif()

# ABI-specific flags
if( ARMEABI_V7A )
	set( ANDROID_CXX_FLAGS "${ANDROID_CXX_FLAGS} -march=armv7-a -mfloat-abi=softfp" )
	if( NEON )
		set( ANDROID_CXX_FLAGS "${ANDROID_CXX_FLAGS} -mfpu=neon" )
	elseif( VFPV3 )
		set( ANDROID_CXX_FLAGS "${ANDROID_CXX_FLAGS} -mfpu=vfpv3" )
	else()
		set( ANDROID_CXX_FLAGS "${ANDROID_CXX_FLAGS} -mfpu=vfpv3-d16" )
	endif()
elseif( ARMEABI_V6 )
	set( ANDROID_CXX_FLAGS "${ANDROID_CXX_FLAGS} -march=armv6 -mfloat-abi=softfp -mfpu=vfp" ) # vfp == vfpv2
elseif( ARMEABI )
	set( ANDROID_CXX_FLAGS "${ANDROID_CXX_FLAGS} -march=armv5te -mtune=xscale -msoft-float" )
endif()

if( ANDROID_STL MATCHES "gnustl" AND (EXISTS "${__libstl}" OR EXISTS "${__libsupcxx}") )
	set( CMAKE_CXX_CREATE_SHARED_LIBRARY "<CMAKE_C_COMPILER> <CMAKE_SHARED_LIBRARY_CXX_FLAGS> <LANGUAGE_COMPILE_FLAGS> <LINK_FLAGS> <CMAKE_SHARED_LIBRARY_CREATE_CXX_FLAGS> <CMAKE_SHARED_LIBRARY_SONAME_CXX_FLAG><TARGET_SONAME> -o <TARGET> <OBJECTS> <LINK_LIBRARIES>" )
	set( CMAKE_CXX_CREATE_SHARED_MODULE  "<CMAKE_C_COMPILER> <CMAKE_SHARED_LIBRARY_CXX_FLAGS> <LANGUAGE_COMPILE_FLAGS> <LINK_FLAGS> <CMAKE_SHARED_LIBRARY_CREATE_CXX_FLAGS> <CMAKE_SHARED_LIBRARY_SONAME_CXX_FLAG><TARGET_SONAME> -o <TARGET> <OBJECTS> <LINK_LIBRARIES>" )
	set( CMAKE_CXX_LINK_EXECUTABLE       "<CMAKE_C_COMPILER> <FLAGS> <CMAKE_CXX_LINK_FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>" )
else()
	set( CMAKE_CXX_CREATE_SHARED_LIBRARY "<CMAKE_CXX_COMPILER> <CMAKE_SHARED_LIBRARY_CXX_FLAGS> <LANGUAGE_COMPILE_FLAGS> <LINK_FLAGS> <CMAKE_SHARED_LIBRARY_CREATE_CXX_FLAGS> <CMAKE_SHARED_LIBRARY_SONAME_CXX_FLAG><TARGET_SONAME> -o <TARGET> <OBJECTS> <LINK_LIBRARIES>" )
	set( CMAKE_CXX_CREATE_SHARED_MODULE  "<CMAKE_CXX_COMPILER> <CMAKE_SHARED_LIBRARY_CXX_FLAGS> <LANGUAGE_COMPILE_FLAGS> <LINK_FLAGS> <CMAKE_SHARED_LIBRARY_CREATE_CXX_FLAGS> <CMAKE_SHARED_LIBRARY_SONAME_CXX_FLAG><TARGET_SONAME> -o <TARGET> <OBJECTS> <LINK_LIBRARIES>" )
	set( CMAKE_CXX_LINK_EXECUTABLE       "<CMAKE_CXX_COMPILER> <FLAGS> <CMAKE_CXX_LINK_FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>" )
endif()

# STL
if( EXISTS "${__libstl}" OR EXISTS "${__libsupcxx}" )
	if( EXISTS "${__libstl}" )
		set( CMAKE_CXX_CREATE_SHARED_LIBRARY "${CMAKE_CXX_CREATE_SHARED_LIBRARY} \"${__libstl}\"" )
		set( CMAKE_CXX_CREATE_SHARED_MODULE  "${CMAKE_CXX_CREATE_SHARED_MODULE} \"${__libstl}\"" )
		set( CMAKE_CXX_LINK_EXECUTABLE       "${CMAKE_CXX_LINK_EXECUTABLE} \"${__libstl}\"" )
	endif()
	if( EXISTS "${__libsupcxx}" )
		set( CMAKE_CXX_CREATE_SHARED_LIBRARY "${CMAKE_CXX_CREATE_SHARED_LIBRARY} \"${__libsupcxx}\"" )
		set( CMAKE_CXX_CREATE_SHARED_MODULE  "${CMAKE_CXX_CREATE_SHARED_MODULE} \"${__libsupcxx}\"" )
		set( CMAKE_CXX_LINK_EXECUTABLE       "${CMAKE_CXX_LINK_EXECUTABLE} \"${__libsupcxx}\"" )
		# C objects:
		set( CMAKE_C_CREATE_SHARED_LIBRARY "<CMAKE_C_COMPILER> <CMAKE_SHARED_LIBRARY_C_FLAGS> <LANGUAGE_COMPILE_FLAGS> <LINK_FLAGS> <CMAKE_SHARED_LIBRARY_CREATE_C_FLAGS> <CMAKE_SHARED_LIBRARY_SONAME_C_FLAG><TARGET_SONAME> -o <TARGET> <OBJECTS> <LINK_LIBRARIES>" )
		set( CMAKE_C_CREATE_SHARED_MODULE  "<CMAKE_C_COMPILER> <CMAKE_SHARED_LIBRARY_C_FLAGS> <LANGUAGE_COMPILE_FLAGS> <LINK_FLAGS> <CMAKE_SHARED_LIBRARY_CREATE_C_FLAGS> <CMAKE_SHARED_LIBRARY_SONAME_C_FLAG><TARGET_SONAME> -o <TARGET> <OBJECTS> <LINK_LIBRARIES>" )
		set( CMAKE_C_LINK_EXECUTABLE       "<CMAKE_C_COMPILER> <FLAGS> <CMAKE_C_LINK_FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>" )
		set( CMAKE_C_CREATE_SHARED_LIBRARY "${CMAKE_C_CREATE_SHARED_LIBRARY} \"${__libsupcxx}\"" )
		set( CMAKE_C_CREATE_SHARED_MODULE  "${CMAKE_C_CREATE_SHARED_MODULE} \"${__libsupcxx}\"" )
		set( CMAKE_C_LINK_EXECUTABLE       "${CMAKE_C_LINK_EXECUTABLE} \"${__libsupcxx}\"" )
	endif()
	if( ANDROID_STL MATCHES "gnustl" )
		if( NOT EXISTS "${ANDROID_LIBM_PATH}" )
			set( ANDROID_LIBM_PATH -lm )
		endif()
		set( CMAKE_CXX_CREATE_SHARED_LIBRARY "${CMAKE_CXX_CREATE_SHARED_LIBRARY} ${ANDROID_LIBM_PATH}" )
		set( CMAKE_CXX_CREATE_SHARED_MODULE  "${CMAKE_CXX_CREATE_SHARED_MODULE} ${ANDROID_LIBM_PATH}" )
		set( CMAKE_CXX_LINK_EXECUTABLE       "${CMAKE_CXX_LINK_EXECUTABLE} ${ANDROID_LIBM_PATH}" )
	endif()
endif()

set( ANDROID_NO_UNDEFINED           "ON"  CACHE BOOL "Show all undefined symbols as linker errors" )
set( ANDROID_SO_UNDEFINED           "OFF" CACHE BOOL "Allows or disallows undefined symbols in shared libraries" )
set( ANDROID_FUNCTION_LEVEL_LINKING "ON"  CACHE BOOL "Put every function into separate section, so it can be stripped in unused" )
set( ANDROID_GOLD_LINKER            "ON"  CACHE BOOL "Enables gold linker (only avaialble for NDK r8b for ARM and x86 architectures on linux-86 and darwin-x86 hosts)" )
set( ANDROID_NOEXECSTACK            "ON"  CACHE BOOL "Allows or disallows construction of trampolines in stack" )
set( ANDROID_RELRO                  "ON"  CACHE BOOL "Enables RELRO - a memory corruption mitigation technique" )
mark_as_advanced( ANDROID_NO_UNDEFINED ANDROID_SO_UNDEFINED ANDROID_FUNCTION_LEVEL_LINKING ANDROID_GOLD_LINKER ANDROID_NOEXECSTACK ANDROID_RELRO )

# linker flags
set( ANDROID_LINKER_FLAGS "" )

if( ARMEABI_V7A )
	# this is *required* to use the following linker flags that routes around
	# a CPU bug in some Cortex-A8 implementations:
	set( ANDROID_LINKER_FLAGS "${ANDROID_LINKER_FLAGS} -Wl,--fix-cortex-a8" )
endif()

if( ANDROID_NO_UNDEFINED )
	if( MIPS )
		# there is some sysroot-related problem in mips linker...
		if( NOT ANDROID_SYSROOT MATCHES "[ ;\"]" )
			set( ANDROID_LINKER_FLAGS "${ANDROID_LINKER_FLAGS} -Wl,--no-undefined -Wl,-rpath-link,${ANDROID_SYSROOT}/usr/lib" )
		endif()
	else()
		set( ANDROID_LINKER_FLAGS "${ANDROID_LINKER_FLAGS} -Wl,--no-undefined" )
	endif()
endif()

if( ANDROID_SO_UNDEFINED )
	set( ANDROID_LINKER_FLAGS "${ANDROID_LINKER_FLAGS} -Wl,-allow-shlib-undefined" )
endif()

if( ANDROID_FUNCTION_LEVEL_LINKING )
	set( ANDROID_CXX_FLAGS    "${ANDROID_CXX_FLAGS} -fdata-sections -ffunction-sections" )
	set( ANDROID_LINKER_FLAGS "${ANDROID_LINKER_FLAGS} -Wl,--gc-sections" )
endif()

if(ANDROID_COMPILER_VERSION VERSION_EQUAL "4.6" AND NOT ANDROID_COMPILER_IS_CLANG)
	if(ANDROID_GOLD_LINKER AND (CMAKE_HOST_UNIX OR ANDROID_NDK_RELEASE STRGREATER "r8b") AND (ARMEABI OR ARMEABI_V7A OR X86) )
		set( ANDROID_LINKER_FLAGS "${ANDROID_LINKER_FLAGS} -fuse-ld=gold" )
	elseif( ANDROID_NDK_RELEASE STRGREATER "r8b")
		set( ANDROID_LINKER_FLAGS "${ANDROID_LINKER_FLAGS} -fuse-ld=bfd" )
	elseif( ANDROID_NDK_RELEASE STREQUAL "r8b" AND ARMEABI AND NOT _CMAKE_IN_TRY_COMPILE )
		message( WARNING 
"The default bfd linker from arm GCC 4.6 toolchain can fail with 'unresolvable R_ARM_THM_CALL relocation' error message. 
  See https://code.google.com/p/android/issues/detail?id=35342
  On Linux and OS X host platform you can workaround this problem using gold linker (default).
  Rerun cmake with -DANDROID_GOLD_LINKER=ON option in case of problems.
")
	endif()
endif()

if(ANDROID_NOEXECSTACK )
	if(ANDROID_COMPILER_IS_CLANG)
		set(ANDROID_CXX_FLAGS    "${ANDROID_CXX_FLAGS} -Xclang -mnoexecstack")
	else()
		set(ANDROID_CXX_FLAGS    "${ANDROID_CXX_FLAGS} -Wa,--noexecstack")
	endif()
	set(ANDROID_LINKER_FLAGS "${ANDROID_LINKER_FLAGS} -Wl,-z,noexecstack")
endif()

if( ANDROID_RELRO )
	set( ANDROID_LINKER_FLAGS "${ANDROID_LINKER_FLAGS} -Wl,-z,relro -Wl,-z,now" )
endif()

if( ANDROID_COMPILER_IS_CLANG )
	set( ANDROID_CXX_FLAGS "-Qunused-arguments ${ANDROID_CXX_FLAGS}" )
	if( ARMEABI_V7A AND NOT ANDROID_FORCE_ARM_BUILD )
		set( ANDROID_CXX_FLAGS "-target thumbv7-none-linux-androideabi ${ANDROID_CXX_FLAGS}" )
	else()
		set( ANDROID_CXX_FLAGS "-target ${ANDROID_LLVM_TRIPLE} ${ANDROID_CXX_FLAGS}" )
	endif()

	if( BUILD_WITH_ANDROID_NDK )
		set( ANDROID_CXX_FLAGS "-gcc-toolchain ${ANDROID_TOOLCHAIN_ROOT} ${ANDROID_CXX_FLAGS}" )
	endif()
endif()

# cache flags
set( CMAKE_CXX_FLAGS           ""                        CACHE STRING "c++ flags" )
set( CMAKE_C_FLAGS             ""                        CACHE STRING "c flags" )
set( CMAKE_CXX_FLAGS_RELEASE   "-O3 -DNDEBUG"            CACHE STRING "c++ Release flags" )
set( CMAKE_C_FLAGS_RELEASE     "-O3 -DNDEBUG"            CACHE STRING "c Release flags" )
set( CMAKE_CXX_FLAGS_DEBUG     "-O0 -g -DDEBUG -D_DEBUG" CACHE STRING "c++ Debug flags" )
set( CMAKE_C_FLAGS_DEBUG       "-O0 -g -DDEBUG -D_DEBUG" CACHE STRING "c Debug flags" )
set( CMAKE_SHARED_LINKER_FLAGS ""                        CACHE STRING "shared linker flags" )
set( CMAKE_MODULE_LINKER_FLAGS ""                        CACHE STRING "module linker flags" )
set( CMAKE_EXE_LINKER_FLAGS    "-Wl,-z,nocopyreloc"      CACHE STRING "executable linker flags" )

# finish flags
set( CMAKE_CXX_FLAGS           "${ANDROID_CXX_FLAGS} ${CMAKE_CXX_FLAGS}" )
set( CMAKE_C_FLAGS             "${ANDROID_CXX_FLAGS} ${CMAKE_C_FLAGS}" )
set( CMAKE_CXX_FLAGS_RELEASE   "${ANDROID_CXX_FLAGS_RELEASE} ${CMAKE_CXX_FLAGS_RELEASE}" )
set( CMAKE_C_FLAGS_RELEASE     "${ANDROID_CXX_FLAGS_RELEASE} ${CMAKE_C_FLAGS_RELEASE}" )
set( CMAKE_CXX_FLAGS_DEBUG     "${ANDROID_CXX_FLAGS_DEBUG} ${CMAKE_CXX_FLAGS_DEBUG}" )
set( CMAKE_C_FLAGS_DEBUG       "${ANDROID_CXX_FLAGS_DEBUG} ${CMAKE_C_FLAGS_DEBUG}" )
set( CMAKE_SHARED_LINKER_FLAGS "${ANDROID_LINKER_FLAGS} ${CMAKE_SHARED_LINKER_FLAGS}" )
set( CMAKE_MODULE_LINKER_FLAGS "${ANDROID_LINKER_FLAGS} ${CMAKE_MODULE_LINKER_FLAGS}" )
set( CMAKE_EXE_LINKER_FLAGS    "${ANDROID_LINKER_FLAGS} ${CMAKE_EXE_LINKER_FLAGS}" )

if( MIPS AND BUILD_WITH_ANDROID_NDK AND ANDROID_NDK_RELEASE STREQUAL "r8" )
	set( CMAKE_SHARED_LINKER_FLAGS "-Wl,-T,${ANDROID_NDK_TOOLCHAINS_PATH}/${ANDROID_GCC_TOOLCHAIN_NAME}/mipself.xsc ${CMAKE_SHARED_LINKER_FLAGS}" )
	set( CMAKE_MODULE_LINKER_FLAGS "-Wl,-T,${ANDROID_NDK_TOOLCHAINS_PATH}/${ANDROID_GCC_TOOLCHAIN_NAME}/mipself.xsc ${CMAKE_MODULE_LINKER_FLAGS}" )
	set( CMAKE_EXE_LINKER_FLAGS    "-Wl,-T,${ANDROID_NDK_TOOLCHAINS_PATH}/${ANDROID_GCC_TOOLCHAIN_NAME}/mipself.x ${CMAKE_EXE_LINKER_FLAGS}" )
endif()

# don't allow selected config to remain empty
if( ANDROID_COMPILER_IS_CLANG ) 
	if( NOT CMAKE_BUILD_TYPE )
		set(CMAKE_BUILD_TYPE "Debug")
	endif()
endif()

set( CMAKE_TRY_COMPILE_CONFIGURATION "" CACHE STRING "Configuration used for platform checks" )

if( NOT CMAKE_TRY_COMPILE_CONFIGURATION )
	set(CMAKE_TRY_COMPILE_CONFIGURATION ${CMAKE_BUILD_TYPE})
endif()

# configure rtti
if( DEFINED ANDROID_RTTI AND ANDROID_STL_FORCE_FEATURES )
	if( ANDROID_RTTI )
		set( CMAKE_CXX_FLAGS "-frtti ${CMAKE_CXX_FLAGS}" )
	else()
		set( CMAKE_CXX_FLAGS "-fno-rtti ${CMAKE_CXX_FLAGS}" )
	endif()
endif()

# configure exceptios
if( DEFINED ANDROID_EXCEPTIONS AND ANDROID_STL_FORCE_FEATURES )
	if( ANDROID_EXCEPTIONS )
		set( CMAKE_CXX_FLAGS "-fexceptions ${CMAKE_CXX_FLAGS}" )
		set( CMAKE_C_FLAGS "-fexceptions ${CMAKE_C_FLAGS}" )
	else()
		set( CMAKE_CXX_FLAGS "-fno-exceptions ${CMAKE_CXX_FLAGS}" )
		set( CMAKE_C_FLAGS "-fno-exceptions ${CMAKE_C_FLAGS}" )
	endif()
endif()

# global includes and link directories
include_directories( SYSTEM "${ANDROID_SYSROOT}/usr/include" ${ANDROID_STL_INCLUDE_DIRS} )
get_filename_component(__android_install_path "${CMAKE_INSTALL_PREFIX}/libs/${ANDROID_NDK_ABI_NAME}" ABSOLUTE) # avoid CMP0015 policy warning
link_directories( "${__android_install_path}" )

# detect if need link crtbegin_so.o explicitly
if( NOT DEFINED ANDROID_EXPLICIT_CRT_LINK )
	set( __cmd "${CMAKE_CXX_CREATE_SHARED_LIBRARY}" )
	string( REPLACE "<CMAKE_CXX_COMPILER>" "${CMAKE_CXX_COMPILER} ${CMAKE_CXX_COMPILER_ARG1}" __cmd "${__cmd}" )
	string( REPLACE "<CMAKE_C_COMPILER>"   "${CMAKE_C_COMPILER} ${CMAKE_C_COMPILER_ARG1}"   __cmd "${__cmd}" )
	string( REPLACE "<CMAKE_SHARED_LIBRARY_CXX_FLAGS>" "${CMAKE_CXX_FLAGS}" __cmd "${__cmd}" )
	string( REPLACE "<LANGUAGE_COMPILE_FLAGS>" "" __cmd "${__cmd}" )
	string( REPLACE "<LINK_FLAGS>" "${CMAKE_SHARED_LINKER_FLAGS}" __cmd "${__cmd}" )
	string( REPLACE "<CMAKE_SHARED_LIBRARY_CREATE_CXX_FLAGS>" "-shared" __cmd "${__cmd}" )
	string( REPLACE "<CMAKE_SHARED_LIBRARY_SONAME_CXX_FLAG>" "" __cmd "${__cmd}" )
	string( REPLACE "<TARGET_SONAME>" "" __cmd "${__cmd}" )
	string( REPLACE "<TARGET>" "${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/toolchain_crtlink_test.so" __cmd "${__cmd}" )
	string( REPLACE "<OBJECTS>" "\"${ANDROID_SYSROOT}/usr/lib/crtbegin_so.o\"" __cmd "${__cmd}" )
	string( REPLACE "<LINK_LIBRARIES>" "" __cmd "${__cmd}" )
	separate_arguments( __cmd )
	foreach( __var ANDROID_NDK ANDROID_NDK_TOOLCHAINS_PATH ANDROID_STANDALONE_TOOLCHAIN )
		if( ${__var} )
			set( __tmp "${${__var}}" )
			separate_arguments( __tmp )
			string( REPLACE "${__tmp}" "${${__var}}" __cmd "${__cmd}")
		endif()
	endforeach()
	string( REPLACE "'" "" __cmd "${__cmd}" )
	string( REPLACE "\"" "" __cmd "${__cmd}" )
	execute_process( COMMAND ${__cmd} RESULT_VARIABLE __cmd_result OUTPUT_QUIET ERROR_QUIET )
	if( __cmd_result EQUAL 0 )
		set( ANDROID_EXPLICIT_CRT_LINK ON )
	else()
		set( ANDROID_EXPLICIT_CRT_LINK OFF )
	endif()
endif()

if( ANDROID_EXPLICIT_CRT_LINK )
	set( CMAKE_CXX_CREATE_SHARED_LIBRARY "${CMAKE_CXX_CREATE_SHARED_LIBRARY} \"${ANDROID_SYSROOT}/usr/lib/crtbegin_so.o\"" )
	set( CMAKE_CXX_CREATE_SHARED_MODULE  "${CMAKE_CXX_CREATE_SHARED_MODULE} \"${ANDROID_SYSROOT}/usr/lib/crtbegin_so.o\"" )
endif()

# setup output directories
set( CMAKE_INSTALL_PREFIX "${ANDROID_TOOLCHAIN_ROOT}/user" CACHE STRING "path for installing" )

# copy shaed stl library to build directory
if( NOT _CMAKE_IN_TRY_COMPILE AND __libstl MATCHES "[.]so$" )
	get_filename_component( __libstlname "${__libstl}" NAME )
	execute_process( COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${__libstl}" "${LIBRARY_OUTPUT_PATH}/${__libstlname}" RESULT_VARIABLE __fileCopyProcess )
	if( NOT __fileCopyProcess EQUAL 0 OR NOT EXISTS "${LIBRARY_OUTPUT_PATH}/${__libstlname}")
		message( SEND_ERROR "Failed copying of ${__libstl} to the ${LIBRARY_OUTPUT_PATH}/${__libstlname}" )
	endif()
	unset( __fileCopyProcess )
	unset( __libstlname )
endif()


# set these global flags for cmake client scripts to change behavior
set( ANDROID True )
set( BUILD_ANDROID True )

# where is the target environment
set( CMAKE_FIND_ROOT_PATH "${ANDROID_TOOLCHAIN_ROOT}/bin" "${ANDROID_TOOLCHAIN_ROOT}/${ANDROID_TOOLCHAIN_MACHINE_NAME}" "${ANDROID_SYSROOT}" "${CMAKE_INSTALL_PREFIX}" "${CMAKE_INSTALL_PREFIX}/share" )

# only search for libraries and includes in the ndk toolchain
set( CMAKE_FIND_ROOT_PATH_MODE_PROGRAM ONLY )
set( CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY )
set( CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY )


# macro to find packages on the host OS
macro( find_host_package )
	set( CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER )
	set( CMAKE_FIND_ROOT_PATH_MODE_LIBRARY NEVER )
	set( CMAKE_FIND_ROOT_PATH_MODE_INCLUDE NEVER )
	if( CMAKE_HOST_WIN32 )
		SET( WIN32 1 )
		SET( UNIX )
	elseif( CMAKE_HOST_APPLE )
		SET( APPLE 1 )
		SET( UNIX )
	endif()
	find_package( ${ARGN} )
	SET( WIN32 )
	SET( APPLE )
	SET( UNIX 1 )
	set( CMAKE_FIND_ROOT_PATH_MODE_PROGRAM ONLY )
	set( CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY )
	set( CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY )
endmacro()

# macro to find programs on the host OS
macro( find_host_program )
	set( CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER )
	set( CMAKE_FIND_ROOT_PATH_MODE_LIBRARY NEVER )
	set( CMAKE_FIND_ROOT_PATH_MODE_INCLUDE NEVER )
	if( CMAKE_HOST_WIN32 )
		SET( WIN32 1 )
		SET( UNIX )
	elseif( CMAKE_HOST_APPLE )
		SET( APPLE 1 )
		SET( UNIX )
	endif()
	find_program( ${ARGN} )
	SET( WIN32 )
	SET( APPLE )
	SET( UNIX 1 )
	set( CMAKE_FIND_ROOT_PATH_MODE_PROGRAM ONLY )
	set( CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY )
	set( CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY )
endmacro()


macro( ANDROID_GET_ABI_RAWNAME TOOLCHAIN_FLAG VAR )
	if( "${TOOLCHAIN_FLAG}" STREQUAL "ARMEABI" )
		set( ${VAR} "armeabi" )
	elseif( "${TOOLCHAIN_FLAG}" STREQUAL "ARMEABI_V7A" )
		set( ${VAR} "armeabi-v7a" )
	elseif( "${TOOLCHAIN_FLAG}" STREQUAL "X86" )
		set( ${VAR} "x86" )
	elseif( "${TOOLCHAIN_FLAG}" STREQUAL "MIPS" )
		set( ${VAR} "mips" )
	else()
		set( ${VAR} "unknown" )
	endif()
endmacro()


# export toolchain settings for the try_compile() command
if( NOT PROJECT_NAME STREQUAL "CMAKE_TRY_COMPILE" )
	set( __toolchain_config "")
	foreach( __var 
				NDK_CCACHE  
				LIBRARY_OUTPUT_PATH_ROOT  
				ANDROID_FORBID_SYGWIN  
				ANDROID_SET_OBSOLETE_VARIABLES
				ANDROID_NDK_HOST_X64
				ANDROID_NDK
				ANDROID_NDK_LAYOUT
				ANDROID_STANDALONE_TOOLCHAIN
				ANDROID_TOOLCHAIN_NAME
				ANDROID_ABI
				ANDROID_NATIVE_API_LEVEL
				ANDROID_STL
				ANDROID_STL_FORCE_FEATURES
				ANDROID_FORCE_ARM_BUILD
				ANDROID_NO_UNDEFINED
				ANDROID_SO_UNDEFINED
				ANDROID_FUNCTION_LEVEL_LINKING
				ANDROID_GOLD_LINKER
				ANDROID_NOEXECSTACK
				ANDROID_RELRO
				ANDROID_LIBM_PATH
				ANDROID_EXPLICIT_CRT_LINK
				)
		if( DEFINED ${__var} )
			if( "${__var}" MATCHES " ")
				set( __toolchain_config "${__toolchain_config}set( ${__var} \"${${__var}}\" CACHE INTERNAL \"\" )\n" )
			else()
				set( __toolchain_config "${__toolchain_config}set( ${__var} ${${__var}} CACHE INTERNAL \"\" )\n" )
			endif()
		endif()
	endforeach()
	file( WRITE "${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/android.toolchain.config.cmake" "${__toolchain_config}" )
	unset( __toolchain_config )
endif()


# force cmake to produce / instead of \ in build commands for Ninja generator
if( CMAKE_GENERATOR MATCHES "Ninja" AND CMAKE_HOST_WIN32 )
	# it is a bad hack after all
	# CMake generates Ninja makefiles with UNIX paths only if it thinks that we are going to build with MinGW
	set( CMAKE_COMPILER_IS_MINGW TRUE ) # tell CMake that we are MinGW
	set( CMAKE_CROSSCOMPILING TRUE )    # stop recursion
	enable_language( C )
	enable_language( CXX )
	# unset( CMAKE_COMPILER_IS_MINGW ) # can't unset because CMake does not convert back-slashes in response files without it
	unset( MINGW )
endif()
