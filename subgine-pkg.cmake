cmake_minimum_required(VERSION 3.15)

#
# Help Printing
#

function(print_help)
	message("usage: subgine-pkg <command> [<args>]")
	message("")
	message("Avalable commands:")
	message("   setup    Create a profile configuration with given CMake arguments")
	message("   install  Fetch and install dependencies")
	message("   update   Install and update local dependencies")
	message("   clean    Clean all build and cache directories")
	message("   prune    Delete all cache, installed packages and fetched sources")
	message("   remove   Remove the specified package")
	message("   help     Print this help")
endfunction()

set(command-list "update" "clean" "prune" "help" "setup" "install" "remove")

if(${CMAKE_ARGC} LESS 4)
	print_help()
elseif(${CMAKE_ARGC} GREATER_EQUAL 4)

if(${CMAKE_ARGV3} STREQUAL "help")
	print_help()
elseif(NOT ${CMAKE_ARGV3} IN_LIST command-list)
	message(FATAL_ERROR "subgine-pkg: '${CMAKE_ARGV3}' is not a subgine-pkg command. See 'subgine-pkg help'")
else()

set(subgine-pkg-silent OFF)

macro(message)
	if(NOT subgine-pkg-silent)
		_message(${ARGV})
	endif()
endmacro()

#
# Json Parser
#
# This section's code mostly taken from https://github.com/sbellus/json-cmake
#
# Thank you Stefan Bellus!
#
macro(ParseJson prefix jsonString)
	cmake_policy(PUSH)

	set(json_string "${jsonString}")
	string(LENGTH "${json_string}" json_jsonLen)
	set(json_index 0)
	set(json_AllVariables ${prefix}._all_var)
	set(json_ArrayNestingLevel 0)
	set(json_MaxArrayNestingLevel 0)

	_sbeParse(${prefix})
	
	unset(json_index)
	unset(json_AllVariables)
	unset(json_jsonLen)
	unset(json_string)
	unset(json_value)
	unset(json_inValue)
	unset(json_name)
	unset(json_inName)
	unset(json_newPrefix)
	unset(json_reservedWord)
	unset(json_arrayIndex)
	unset(json_char)
	unset(json_end)
	unset(json_ArrayNestingLevel)
	foreach(json_nestingLevel RANGE ${json_MaxArrayNestingLevel})
		unset(json_${json_nestingLevel}_arrayIndex)
	endforeach()
	unset(json_nestingLevel)
	unset(json_MaxArrayNestingLevel)
	
	cmake_policy(POP)
endmacro()

macro(sbeClearJson prefix)
	foreach(json_var ${${prefix}})
		unset(${json_var})
	endforeach()
	
	unset(${prefix})
	unset(json_var)
endmacro()

macro(sbePrintJson prefix)
	foreach(json_var ${${prefix}})
		message("${json_var} = ${${json_var}}")
	endforeach()
endmacro()

macro(_sbeParse prefix)
	set(expected_token "")
	while(${json_index} LESS ${json_jsonLen})
		string(SUBSTRING "${json_string}" ${json_index} 1 json_char)
		
		if("\"" STREQUAL "${json_char}")
			_sbeParseNameValue(${prefix})
		elseif("{" STREQUAL "${json_char}")
			list(APPEND ${json_AllVariables} ${prefix})
			list(APPEND ${json_AllVariables} ${prefix}._type)
			set(${prefix} "")
			set(${prefix}._type "object")
			_sbeMoveToNextNonEmptyCharacter()
			_sbeParseObject(${prefix})
		elseif("[" STREQUAL "${json_char}")
			_sbeMoveToNextNonEmptyCharacter()
			_sbeParseArray(${prefix})
		endif()

		if(${json_index} LESS ${json_jsonLen})
			string(SUBSTRING "${json_string}" ${json_index} 1 json_char)
		else()
			break()
		endif()

		if ("}" STREQUAL "${json_char}" OR "]" STREQUAL "${json_char}")
			break()
		endif()
		
		_sbeMoveToNextNonEmptyCharacter()
	endwhile()
endmacro()

macro(_sbeParseNameValue prefix)
	set(json_name "")
	set(json_inName no)

	while(${json_index} LESS ${json_jsonLen})
		string(SUBSTRING "${json_string}" ${json_index} 1 json_char)
		
		# check if name ends
		if("\"" STREQUAL "${json_char}" AND json_inName)
			set(json_inName no)
			_sbeMoveToNextNonEmptyCharacter()
			if(NOT ${json_index} LESS ${json_jsonLen})
				break()
			endif()
			string(SUBSTRING "${json_string}" ${json_index} 1 json_char)
			set(json_newPrefix ${prefix}.${json_name})
			list(APPEND ${prefix} ${json_name})
			set(json_name "")
			
			if(":" STREQUAL "${json_char}")
				_sbeMoveToNextNonEmptyCharacter()
				if(NOT ${json_index} LESS ${json_jsonLen})
					break()
				endif()
				string(SUBSTRING "${json_string}" ${json_index} 1 json_char)
				
				if("\"" STREQUAL "${json_char}")
					_sbeParseValue(${json_newPrefix})
					break()
				elseif("{" STREQUAL "${json_char}")
					list(APPEND ${json_AllVariables} ${prefix})
					list(APPEND ${json_AllVariables} ${prefix}._type)
					set(${prefix} "")
					set(${prefix}._type "object")
					_sbeMoveToNextNonEmptyCharacter()
					_sbeParseObject(${json_newPrefix})
					break()
				elseif("[" STREQUAL "${json_char}")
					_sbeMoveToNextNonEmptyCharacter()
					_sbeParseArray(${json_newPrefix})
					break()
				else()
					# reserved word starts
					_sbeParseReservedWord(${json_newPrefix})
					break()
				endif()
			else()
				# name without value
				list(APPEND ${json_AllVariables} ${json_newPrefix})
				set(${json_newPrefix} "")
				break()
			endif()
		endif()

		if(json_inName)
			# remove escapes
			if("\\" STREQUAL "${json_char}")
				math(EXPR json_index "${json_index} + 1")
				if(NOT ${json_index} LESS ${json_jsonLen})
					break()
				endif()
				string(SUBSTRING "${json_string}" ${json_index} 1 json_char)
			endif()
		
			set(json_name "${json_name}${json_char}")
		endif()
		
		# check if name starts
		if("\"" STREQUAL "${json_char}" AND NOT json_inName)
			set(json_inName yes)
		endif()
	   
		_sbeMoveToNextNonEmptyCharacter()
	endwhile()	
endmacro()

macro(_sbeParseReservedWord prefix)
	set(json_reservedWord "")
	set(json_end no)
	while(${json_index} LESS ${json_jsonLen} AND NOT json_end)
		string(SUBSTRING "${json_string}" ${json_index} 1 json_char)
		
		if("," STREQUAL "${json_char}" OR "}" STREQUAL "${json_char}" OR "]" STREQUAL "${json_char}")
			set(json_end yes)
		else()
			set(json_reservedWord "${json_reservedWord}${json_char}")
			math(EXPR json_index "${json_index} + 1")
		endif()
	endwhile()

	list(APPEND ${json_AllVariables} ${prefix})
	string(STRIP  "${json_reservedWord}" json_reservedWord)
	set(${prefix} ${json_reservedWord})
endmacro()

macro(_sbeParseValue prefix)
	cmake_policy(SET CMP0054 NEW) # turn off implicit expansions in if statement
	
	set(json_value "")
	set(json_inValue no)
	
	while(${json_index} LESS ${json_jsonLen})
		string(SUBSTRING "${json_string}" ${json_index} 1 json_char)

		# check if json_value ends, it is ended by "
		if("\"" STREQUAL "${json_char}" AND json_inValue)
			set(json_inValue no)
			
			set(${prefix} ${json_value})
			list(APPEND ${json_AllVariables} ${prefix})
			_sbeMoveToNextNonEmptyCharacter()
			break()
		endif()
		
		if(json_inValue)
			 # if " is escaped consume
			if("\\" STREQUAL "${json_char}")
				math(EXPR json_index "${json_index} + 1")
				if(NOT ${json_index} LESS ${json_jsonLen})
					break()
				endif()
				string(SUBSTRING "${json_string}" ${json_index} 1 json_char)
				if(NOT "\"" STREQUAL "${json_char}")
					# if it is not " then copy also escape character
					set(json_char "\\${json_char}")
				endif()
			endif()
			
			_sbeAddEscapedCharacter("${json_char}")
		endif()
		
		# check if value starts
		if("\"" STREQUAL "${json_char}" AND NOT json_inValue)
			set(json_inValue yes)
		endif()
		
		math(EXPR json_index "${json_index} + 1")
	endwhile()
endmacro()

macro(_sbeAddEscapedCharacter char)
	string(CONCAT json_value "${json_value}" "${char}")
endmacro()

macro(_sbeParseObject prefix)
	_sbeParse(${prefix})
	_sbeMoveToNextNonEmptyCharacter()
endmacro()

macro(_sbeParseArray prefix)
	math(EXPR json_ArrayNestingLevel "${json_ArrayNestingLevel} + 1")
	
	list(APPEND ${json_AllVariables} ${prefix})
	list(APPEND ${json_AllVariables} ${prefix}._type)
	set(${prefix} "")
	set(${prefix}._type "array")

	while(${json_index} LESS ${json_jsonLen})
		string(SUBSTRING "${json_string}" ${json_index} 1 json_char)

		if("\"" STREQUAL "${json_char}")
			if(NOT DEFINED json_${json_ArrayNestingLevel}_arrayIndex)
				set(json_${json_ArrayNestingLevel}_arrayIndex 0)
			endif()
			
			# simple value
			list(APPEND ${prefix} ${json_${json_ArrayNestingLevel}_arrayIndex})
			_sbeParseValue(${prefix}_${json_${json_ArrayNestingLevel}_arrayIndex})
		elseif("{" STREQUAL "${json_char}")
			if(NOT DEFINED json_${json_ArrayNestingLevel}_arrayIndex)
				set(json_${json_ArrayNestingLevel}_arrayIndex 0)
			endif()
			
			list(APPEND ${json_AllVariables} ${prefix}_${json_${json_ArrayNestingLevel}_arrayIndex})
			list(APPEND ${json_AllVariables} ${prefix}_${json_${json_ArrayNestingLevel}_arrayIndex}._type)
			set(${prefix}_${json_${json_ArrayNestingLevel}_arrayIndex} "")
			set(${prefix}_${json_${json_ArrayNestingLevel}_arrayIndex}._type "object")
			
			# object
			_sbeMoveToNextNonEmptyCharacter()
			list(APPEND ${prefix} ${json_${json_ArrayNestingLevel}_arrayIndex})
			_sbeParseObject(${prefix}_${json_${json_ArrayNestingLevel}_arrayIndex})
		elseif(NOT "]" STREQUAL "${json_char}")
			if(NOT DEFINED json_${json_ArrayNestingLevel}_arrayIndex)
				set(json_${json_ArrayNestingLevel}_arrayIndex 0)
			endif()
			
			list(APPEND ${prefix} ${json_${json_ArrayNestingLevel}_arrayIndex})
			_sbeParseReservedWord(${prefix}_${json_${json_ArrayNestingLevel}_arrayIndex})
		endif()
		
		if(NOT ${json_index} LESS ${json_jsonLen})
			break()
		endif()
		
		string(SUBSTRING "${json_string}" ${json_index} 1 json_char)
		
		if("]" STREQUAL "${json_char}")
			_sbeMoveToNextNonEmptyCharacter()
			break()
		elseif("," STREQUAL "${json_char}")
			math(EXPR json_${json_ArrayNestingLevel}_arrayIndex "${json_${json_ArrayNestingLevel}_arrayIndex} + 1")
		endif()
				
		_sbeMoveToNextNonEmptyCharacter()
	endwhile()
	
	if(${json_MaxArrayNestingLevel} LESS ${json_ArrayNestingLevel})
		set(json_MaxArrayNestingLevel ${json_ArrayNestingLevel})
	endif()
	math(EXPR json_ArrayNestingLevel "${json_ArrayNestingLevel} - 1")
endmacro()

macro(_sbeMoveToNextNonEmptyCharacter)
	math(EXPR json_index "${json_index} + 1")
	if(${json_index} LESS ${json_jsonLen})
		string(SUBSTRING "${json_string}" ${json_index} 1 json_char)
		while(${json_char} MATCHES "[ \t\n\r]" AND ${json_index} LESS ${json_jsonLen})
			math(EXPR json_index "${json_index} + 1")
			string(SUBSTRING "${json_string}" ${json_index} 1 json_char)
		endwhile()
	endif()
endmacro()
#
# End of Json Parser
#

# ----------------------

#
# Environement Validation
#
set(subgine-pkg-silent ON)
find_package(Git REQUIRED)
set(subgine-pkg-silent OFF)

set(current-directory "${CMAKE_CURRENT_SOURCE_DIR}")

if(NOT EXISTS "${current-directory}/sbg-manifest.json")
	message(FATAL_ERROR "A sbg-manifest.json file must be in the current working directory")
endif()

file(READ "sbg-manifest.json" manifest_content)

ParseJson(manifest "${manifest_content}")

if(NOT "${manifest._type}" STREQUAL "object")
	message(FATAL_ERROR "The manifest must contain a root object")
endif()

if(NOT DEFINED manifest.installation-path)
	message(FATAL_ERROR "The manifest must contain a string member installation-path")
endif()

set(installation-path "${current-directory}/${manifest.installation-path}")
set(test-path "${installation-path}/.test")

set(library-directory-name "module")
set(sources-directory-name "sources")
set(config-directory-name "config")

set(sources-path "${installation-path}/${sources-directory-name}")
set(library-path "${installation-path}/${library-directory-name}")
set(config-path "${installation-path}/${config-directory-name}")
set(build-directory-name "build")
set(built-options-file-name "subgine-pkg-options.txt")
set(built-revision-file-name "subgine-pkg-revision.txt")
set(current-profile "default")
set(config-suffix "${current-profile}")

include(ProcessorCount)

#
# Dependency Functions
#
macro(select_profile profile)
	set(current-profile "${profile}")
	set(config-suffix "${current-profile}")
endmacro()

macro(select_profile_from_arg variable)
	if(DEFINED ${variable})
		select_profile("${${variable}}")
	endif()
endmacro()

# This function extract an argument value in the form of -DARGUMENT=VALUE
function(argument_value argument-variable cmake-arguments return-value)
	set(test-project-path "${test-path}/.extract-arguments")
	file(WRITE "${test-project-path}/CMakeLists.txt" "cmake_minimum_required(VERSION 3.14)\nproject(extract-argument NONE)\nfile(WRITE \"./argument-result.txt\" \"\${${argument-variable}}\")")
	execute_process(
		COMMAND ${CMAKE_COMMAND}
			-DCMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY=ON
			-DCMAKE_FIND_USE_CMAKE_SYSTEM_PATH=OFF
			-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON
			${cmake-arguments} .
		WORKING_DIRECTORY "${test-project-path}"
		OUTPUT_QUIET
		ERROR_QUIET
		RESULT_VARIABLE failbit
	)
	
	if (NOT ${failbit} EQUAL 0)
		message(FATAL_ERROR "Cannot extract argument ${argument-variable} from command line, CMake subprocess failed with return code ${failbit}")
	endif()
	
	file(READ "${test-project-path}/argument-result.txt" argument-result)
	set(${return-value} "${argument-result}" PARENT_SCOPE)
endfunction()

# This function simply remove the `v` from the tag to get the version number
function(version_from_tag tag return-value)
	string(REGEX MATCH "^v" matches "${tag}")
		
	if("${matches}" STREQUAL "v")
		string(SUBSTRING "${tag}" 1 -1 version-string)
		set(${return-value} "${version-string}" PARENT_SCOPE)
	else()
		set(${return-value} "${tag}" PARENT_SCOPE)
	endif()
endfunction()

# This function generate the string for the version string we put in the `find_package` command
function(dependency_cmake_version_check dependency return-value)
	if (NOT ${dependency}.ignore-version)
		if(DEFINED ${dependency}.version)
			set(version-string-validate "${${dependency}.version}")
		elseif(DEFINED ${dependency}.tag)
			version_from_tag(${${dependency}.tag} version-string-validate)
		else()
			set(version-string-validate "")
		endif()

		if(NOT "${version-string-validate}" STREQUAL "")
			if(${${dependency}.strict})
				set(${return-value} "${version-string-validate} EXACT" PARENT_SCOPE)
			else()
				set(${return-value} "${version-string-validate}" PARENT_SCOPE)
			endif()
		else()
			set(${return-value} "" PARENT_SCOPE)
		endif()
	else()
		set(${return-value} "" PARENT_SCOPE)
	endif()
endfunction()

# This function validate the json object of a dependency.
# It must have a name, a repository, and a tag or a branch
function(assert_dependency_json_valid dependency)
	if(NOT DEFINED ${dependency}.name)
		message(FATAL_ERROR "The dependency '${dependency}' must have a name")
	endif()
	if(NOT DEFINED ${dependency}.repository)
		message(FATAL_ERROR "The dependency '${${dependency}.name}' must have a repository specified")
	endif()
	if(NOT DEFINED ${dependency}.tag AND NOT DEFINED ${dependency}.branch)
		message(FATAL_ERROR "The dependency '${${dependency}.name}' must have a tag or branch specified")
	endif()
endfunction()

# This function clear the cache if the arguments have changed
function(clean_test_project_if_needed profile cmake-arguments)
	if(EXISTS "${test-path}/${profile}/last-arguments.txt")
		file(READ "${test-path}/${profile}/last-arguments.txt" last-cmake-arguments)
		if (NOT "${cmake-arguments}" STREQUAL "${last-cmake-arguments}")
			file(REMOVE_RECURSE "${test-path}/${profile}")
			file(MAKE_DIRECTORY "${test-path}/${profile}")
		endif()
	endif()
endfunction()

# This function check if a dependency is available with the current configuration and CMake flags
function(check_dependency_exist dependency cmake-flags return-value)
	set(profile-test-path "${test-path}/${current-profile}")
	if (NOT IS_DIRECTORY "${installation-path}")
		file(MAKE_DIRECTORY "${installation-path}")
	endif()
	
	if (NOT IS_DIRECTORY "${test-path}")
		file(MAKE_DIRECTORY "${test-path}")
	endif()
	
	if (NOT IS_DIRECTORY "${profile-test-path}")
		file(MAKE_DIRECTORY "${profile-test-path}")
	endif()
	
	# We cleanup previous cache so we are not affected by it when we change the arguments passed ot a profile
	clean_test_project_if_needed("${current-profile}" "${cmake-flags}")
	
	# The following will try to find a subgine metadata file so we get
	# all the required module path and prefix path to find the dependency and its dependencies.
	file(WRITE "${profile-test-path}/subgine-package-file.cmake" "
cmake_minimum_required(VERSION 3.14)

list(APPEND CMAKE_PREFIX_PATH \"${library-path}/${current-profile}/\")
find_file(sbg-package-config-file subgine-pkg-${${dependency}.name}-${current-profile}.cmake)
message(\"\${sbg-package-config-file}\")")

	execute_process(
		COMMAND ${CMAKE_COMMAND} ${cmake-flags} -P "${profile-test-path}/subgine-package-file.cmake"
		ERROR_VARIABLE sbg-package-config-file
		OUTPUT_QUIET
	)
	
	set(check-module-paths "")
	set(check-prefix-paths "${library-path}/${current-profile}")
	
	string(STRIP "${sbg-package-config-file}" sbg-package-config-file)
	if(NOT "${sbg-package-config-file}" STREQUAL "sbg-package-config-file-NOTFOUND")
		include("${sbg-package-config-file}")
		list(APPEND check-prefix-paths ${found-pkg-${${dependency}.name}-prefix-path})
		if(NOT "${found-pkg-${${dependency}.name}-module-path}" STREQUAL "")
			list(APPEND check-module-paths "${found-pkg-${${dependency}.name}-module-path}")
		endif()
	endif()
	
	if(NOT "${check-module-paths}" STREQUAL "")
		set(cmake-module-path-command "list(APPEND CMAKE_MODULE_PATH ${check-module-paths})")
	endif()
	
	# Finally, we generate the CMake project file and try to run it
	dependency_cmake_version_check(${dependency} cmake-version-check)
	
	if (DEFINED ${dependency}.component)
		set(dependency_component "COMPONENTS ${${dependency}.component}")
	else()
		set(dependency_component "")
	endif()
	
	if (DEFINED ${dependency}.target)
		set(target-cmake-check "if(TARGET ${${dependency}.target})\nelse()\nmessage(SEND_ERROR \"Package ${${dependency}.name} not found\")\nendif()")
	else()
		set(target-cmake-check "")
	endif()
	
	file(WRITE "${profile-test-path}/CMakeLists.txt" "cmake_minimum_required(VERSION 3.14)\nproject(testfindpackage CXX)\nunset(${${dependency}.name}_DIR CACHE)\n${cmake-module-path-command}\nlist(APPEND CMAKE_PREFIX_PATH ${check-prefix-paths})\nfind_package(${${dependency}.name} ${cmake-version-check} ${dependency_component} REQUIRED)\n${target-cmake-check}")
	
	execute_process(
		COMMAND ${CMAKE_COMMAND}
			-DCMAKE_PROJECT_INCLUDE=${config-path}/${current-profile}-add-prefix-path.cmake
			-DCMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY=ON
			-DCMAKE_FIND_USE_CMAKE_SYSTEM_PATH=OFF
			-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON
			${cmake-flags}
			-S "${profile-test-path}"
			-B "${profile-test-path}"
		RESULT_VARIABLE result-check-dep
		OUTPUT_QUIET
		ERROR_QUIET
	)
	
	# We ran the test, so we write the arguments for the next run
	file(WRITE "${profile-test-path}/last-arguments.txt" "${cmake-flags}")
	
	if (${result-check-dep} EQUAL 0)
		set(${return-value} ON PARENT_SCOPE)
	else()
		set(${return-value} OFF PARENT_SCOPE)
	endif()
endfunction()

function(update_dependency dependency cmake-flags)
	if(NOT IS_DIRECTORY "${sources-path}")
		file(MAKE_DIRECTORY "${sources-path}")
	endif()
	if(IS_DIRECTORY "${sources-path}/${${dependency}.name}/.git")
		message(STATUS "Fetching updates for ${${dependency}.name}...")
		execute_process(
			COMMAND ${GIT_EXECUTABLE} fetch
			WORKING_DIRECTORY "${sources-path}/${${dependency}.name}"
			ERROR_QUIET
			OUTPUT_QUIET
		)
	else()
		file(REMOVE_RECURSE "${sources-path}/${${dependency}.name}")
		
		set(recurse-argument "")
		if (DEFINED ${dependency}.fetch-submodules)
			if (${${dependency}.fetch-submodules})
				set(recurse-argument "--recurse-submodules")
			endif()
		endif()
		
		execute_process(
			COMMAND ${GIT_EXECUTABLE} clone ${${dependency}.repository} ${${dependency}.name} ${recurse-argument}
			WORKING_DIRECTORY ${sources-path}
		)
	endif()
	
	if (DEFINED ${dependency}.tag)
		set(checkout-argument "${${dependency}.tag}")
	else()
		set(checkout-argument "${${dependency}.branch}")
	endif()

	execute_process(
		COMMAND ${GIT_EXECUTABLE} checkout ${checkout-argument}
		WORKING_DIRECTORY "${sources-path}/${${dependency}.name}"
		ERROR_QUIET
		OUTPUT_QUIET
	)
	
	if(EXISTS "${sources-path}/${${dependency}.name}/sbg-manifest.json")
		message("Reading ${${dependency}.name} dependencies...")
		file(READ "${sources-path}/${${dependency}.name}/sbg-manifest.json" manifest_content_${${dependency}.name})
		
		ParseJson(manifest_${${dependency}.name} "${manifest_content_${${dependency}.name}}")
		
		if(NOT "${manifest_${${dependency}.name}._type}" STREQUAL "object")
			message(FATAL_ERROR "The manifest for dependency \"${${dependency}.name}\" must contain a root object")
		endif()
		
		if (NOT DEFINED manifest_${${dependency}.name}.dependencies)
			message(FATAL_ERROR "The manifest for dependency \"${${dependency}.name}\" does not contains dependencies or is invalid")
		endif()
		
		update_dependency_list(manifest_${${dependency}.name}.dependencies "${cmake-flags}")
	endif()
	
	should_rebuild_dependency(${dependency} ASSUME_LOCAL "${cmake-flags}" should-rebuild)
	if(should-rebuild)
		build_dependency(${dependency} "${cmake-flags}")
	endif()
endfunction()

function(write_dependency_options_file dependency cmake-flags)
	file(WRITE "${sources-path}/${${dependency}.name}/${build-directory-name}/${config-suffix}/${built-options-file-name}" "${${dependency}.options};${cmake-flags}")
endfunction()

function(write_dependency_revision_file dependency)
	dependency_current_revision(${dependency} current-revision)
	file(WRITE "${sources-path}/${${dependency}.name}/${build-directory-name}/${config-suffix}/${built-revision-file-name}" "${current-revision}")
endfunction()

function(dependency_cmake_options dependency return-value)
	set(cmake-options ${${dependency}.options})
	separate_arguments(cmake-options)
	set(${return-value} ${cmake-options} PARENT_SCOPE)
endfunction()

function(dependency_build_additional_flags dependency return-value)
	ProcessorCount(cores)
	if(${cores} GREATER 0)
		set(additional-arguments "--parallel ${cores}")
		separate_arguments(additional-arguments)
		set(${return-value} ${additional-arguments} PARENT_SCOPE)
	else()
		set(${return-value} "" PARENT_SCOPE)
	endif()
endfunction()

function(build_dependency dependency cmake-flags)
	set(build-directory "${sources-path}/${${dependency}.name}/${build-directory-name}/${config-suffix}")
	set(sources-directory "${sources-path}/${${dependency}.name}")
	
	if(NOT IS_DIRECTORY "${build-directory}")
		file(MAKE_DIRECTORY "${build-directory}")
	endif()
	
	dependency_cmake_options(${dependency} cmake-options)
	execute_process(
		COMMAND ${CMAKE_COMMAND} ${cmake-flags} -Dsubgine-pkg-as-dependency=ON 
			-DCMAKE_INSTALL_PREFIX=${library-path}/${config-suffix}/${${dependency}.name}
			-DCMAKE_PROJECT_INCLUDE=${config-path}/${current-profile}-add-prefix-path.cmake
			-DCMAKE_EXPORT_NO_PACKAGE_REGISTRY=ON
			-DCMAKE_FIND_USE_CMAKE_SYSTEM_PATH=OFF
			-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON
			${cmake-options}
			-S "${sources-directory}"
			-B "${build-directory}"
		RESULT_VARIABLE result-build-dependency
		ERROR_VARIABLE build-dependency-error
		OUTPUT_QUIET
	)
	
	message(STATUS "Configuring ${${dependency}.name}...")
	
	if (NOT ${result-build-dependency} EQUAL 0)
		message("Dependency ${${dependency}.name} failed to configure... aborting")
		message("Failed to configure with output:\n${build-dependency-error}")
		message(FATAL_ERROR "stopping due to previous errors")
	endif()
	
	dependency_build_additional_flags(${dependency} additional-flags)
	
	message(STATUS "Building ${${dependency}.name}...")
	
	execute_process(
		COMMAND ${CMAKE_COMMAND} --build . --target install ${additional-flags}
		WORKING_DIRECTORY "${sources-path}/${${dependency}.name}/${build-directory-name}/${config-suffix}"
		RESULT_VARIABLE result-build-dependency
		ERROR_VARIABLE build-dependency-error
		OUTPUT_QUIET
	)
	
	if (${result-build-dependency} EQUAL 0)
		write_dependency_revision_file(${dependency})
		write_dependency_options_file(${dependency} "${cmake-flags}")
	else()
		message("Dependency ${${dependency}.name} failed to build... aborting")
		message("Failed to build with output:\n${build-dependency-error}")
		message(FATAL_ERROR "stopping due to previous errors")
	endif()
	
	message("Installed ${${dependency}.name} ✔")
	
	check_dependency_exist(${dependency} "${cmake-flags}" dependency-${${dependency}.name}-exists)
endfunction()

function(dependency_has_local_source_dir dependency return-value)
	if(IS_DIRECTORY "${sources-path}/${${dependency}.name}")
		set(${return-value} ON PARENT_SCOPE)
	else()
		set(${return-value} OFF PARENT_SCOPE)
	endif()
endfunction()

function(update_dependency_list dependency-list cmake-flags)
	foreach(dependency-id ${${dependency-list}})
		set(dependency ${dependency-list}_${dependency-id})
		if(NOT ${${dependency}._type} STREQUAL "object")
			message(FATAL_ERROR "The dependency array must only contain objects")
		endif()
		
		assert_dependency_json_valid(${dependency})
		check_dependency_exist(${dependency} "${cmake-flags}" dependency-${${dependency}.name}-exists)
	endforeach()
	
	foreach(dependency-id ${${dependency-list}})
		set(dependency ${dependency-list}_${dependency-id})
		
		dependency_has_local_source_dir(${dependency} is-local)
		if (NOT ${dependency-${${dependency}.name}-exists})
			message("${${dependency}.name} not found... installing")
			update_dependency(${dependency} "${cmake-flags}")
		elseif(is-local)
			dependency_current_revision(${dependency} current-revision)
			dependency_built_revision(${dependency} built-revision)
			dependency_built_options(${dependency} built-options)
			if(NOT "${built-options}" STREQUAL "${${dependency}.options};${cmake-flags}")
				message("${${dependency}.name} options changed... rebuilding")
				update_dependency(${dependency} "${cmake-flags}")
			elseif(NOT "${current-revision}" STREQUAL "${built-revision}")
				message("${${dependency}.name} build out of date... rebuilding")
				update_dependency(${dependency} "${cmake-flags}")
			else()
				message("Found ${${dependency}.name} ✔")
			endif()
		else()
			message("Found ${${dependency}.name} ✔")
		endif()
	endforeach()
endfunction()

function(update_local_dependency_list dependency-list cmake-flags)
	foreach(dependency-id ${${dependency-list}})
		set(dependency ${dependency-list}_${dependency-id})
		if(NOT ${${dependency}._type} STREQUAL "object")
			message(FATAL_ERROR "The dependency array must only contain objects")
		endif()
		
		assert_dependency_json_valid(${dependency})
		check_dependency_exist(${dependency} "${cmake-flags}" dependency-${${dependency}.name}-exists)
	endforeach()

	file(READ "${test-path}/${current-profile}/CMakeCache.txt" test-cache)

	foreach(dependency-id ${${dependency-list}})
		set(dependency ${dependency-list}_${dependency-id})
		if (${dependency-${${dependency}.name}-exists})
			update_local_dependency(${dependency} ${test-cache} "${cmake-flags}")
		endif()
	endforeach()
	
	update_dependency_list(${dependency-list} "${cmake-flags}")
endfunction()

function(dependency_current_revision dependency return-value)
	execute_process(
		COMMAND ${GIT_EXECUTABLE} rev-parse HEAD
		WORKING_DIRECTORY "${sources-path}/${${dependency}.name}"
		OUTPUT_VARIABLE revision-current
		RESULT_VARIABLE revision-current-result
		ERROR_VARIABLE revision-current-error
	)
	
	if ("${revision-current-result}" EQUAL 0)
		set(${return-value} "${revision-current}" PARENT_SCOPE)
	else()
		message(FATAL_ERROR "Git failed to retrieve current revision with output: ${revision-current-error}")
	endif()
endfunction()

function(dependency_built_options dependency return-value)
	if(EXISTS "${sources-path}/${${dependency}.name}/${build-directory-name}/${config-suffix}/${built-options-file-name}")
		file(READ "${sources-path}/${${dependency}.name}/${build-directory-name}/${config-suffix}/${built-options-file-name}" built-options-string)
		set(${return-value} "${built-options-string}" PARENT_SCOPE)
	else()
		set(${return-value} "" PARENT_SCOPE)
	endif()
endfunction()

function(dependency_built_revision dependency return-value)
	if(EXISTS "${sources-path}/${${dependency}.name}/${build-directory-name}/${config-suffix}/${built-revision-file-name}")
		file(READ "${sources-path}/${${dependency}.name}/${build-directory-name}/${config-suffix}/${built-revision-file-name}" built-revision-string)
		set(${return-value} "${built-revision-string}" PARENT_SCOPE)
	else()
		set(${return-value} "" PARENT_SCOPE)
	endif()
endfunction()

function(should_rebuild_dependency dependency test-build-cache cmake-flags return-value)
	if ("${test-build-cache}" STREQUAL "ASSUME_LOCAL")
		set(is-local-dependency ON)
	else()
		check_local_dependency(${dependency} ${test-build-cache} is-local-dependency)
	endif()
	
	if(is-local-dependency)
		dependency_current_revision(${dependency} current-revision)
		dependency_built_revision(${dependency} built-revision)
		dependency_built_options(${dependency} built-options)
		
		if("${current-revision}" STREQUAL "${built-revision}" AND "${built-options}" STREQUAL "${${dependency}.options};${cmake-flags}" AND EXISTS ${library-path}/${current-profile}/${${dependency}.name})
			set(${return-value} OFF PARENT_SCOPE)
		else()
			set(${return-value} ON PARENT_SCOPE)
		endif()
	else()
		set(${return-value} OFF PARENT_SCOPE)
	endif()
endfunction()

function(check_local_options test-build-cache return-value)
	check_local_dependency(${dependency} ${test-build-cache} is-local-package)
	set(check-local-options OFF)
	
	if(is-local-package)
		dependency_built_options(${dependency} built-options)
		
		if("${built-options}" STREQUAL "${${dependency}.options}")
			set(check-local-options OFF)
		else()
			set(check-local-options ON)
		endif()
	endif()
	
	if (${check-local-options})
		set(${return-value} ON PARENT_SCOPE)
	else()
		set(${return-value} OFF PARENT_SCOPE)
	endif()
endfunction()

function(check_local_dependency dependency test-build-cache return-value)
	set(check-local-package OFF)
	dependency_has_local_source_dir(${dependency} is-local)
	if(is-local)
		string(REGEX MATCH "${${dependency}.name}_DIR:PATH=[^\n]*" matched-path "${test-build-cache}")
		if ("${matched-path}" STREQUAL "")
			if(ARGC GREATER 3 AND "${ARGV3}" STREQUAL "SKIPPING_VERBOSE")
				message("${${dependency}.name} is not a cmake package... skipping")
			endif()
		else()
			string(LENGTH "${${dependency}.name}_DIR:PATH=" path-prefix-length)
			string(SUBSTRING "${matched-path}" ${path-prefix-length} -1 dependency-path)
			
			if ("${dependency-path}" MATCHES "${installation-path}/[^\n]*")
				set(check-local-package ON)
			endif()
		endif()
	endif()
	
	if (${check-local-package})
		set(${return-value} ON PARENT_SCOPE)
	else()
		set(${return-value} OFF PARENT_SCOPE)
	endif()
endfunction()

function(check_branch_status dependency return-value)
	set(check-branch-status OFF)
	
	if(DEFINED ${dependency}.branch)
		execute_process(
			COMMAND ${GIT_EXECUTABLE} symbolic-ref -q --short HEAD
			OUTPUT_VARIABLE branch-result
			WORKING_DIRECTORY "${sources-path}/${${dependency}.name}"
			ERROR_QUIET
		)
		
		string(REGEX REPLACE "\n$" "" branch-result "${branch-result}")
		
		if(NOT "${branch-result}" STREQUAL "${${dependency}.branch}")
			set(check-branch-status ON)
		endif()
	else()
		execute_process(
			COMMAND ${GIT_EXECUTABLE} describe --tags --exact-match
			OUTPUT_VARIABLE branch-result
			WORKING_DIRECTORY "${sources-path}/${${dependency}.name}"
			ERROR_QUIET
		)
		
		string(REGEX REPLACE "\n$" "" branch-result "${branch-result}")
		
		if(NOT "${branch-result}" STREQUAL "${${dependency}.tag}")
			set(check-branch-status ON)
		endif()
	endif()
	
	if (${check-branch-status})
		set(${return-value} ON PARENT_SCOPE)
	else()
		set(${return-value} OFF PARENT_SCOPE)
	endif()
endfunction()

function(update_local_dependency dependency test-build-cache cmake-flags)
	dependency_has_local_source_dir(${dependency} is-local-package)
	
	if(is-local-package)
		check_branch_status(${dependency} should-checkout)
		
		if(${should-checkout})
			if (DEFINED ${dependency}.tag)
				set(checkout-argument "${${dependency}.tag}")
				message("${${dependency}.name}: checkout tag ${${dependency}.tag}")
			else()
				set(checkout-argument "${${dependency}.branch}")
				message("${${dependency}.name}: checkout branch ${${dependency}.branch}")
			endif()
			
			execute_process(
				COMMAND ${GIT_EXECUTABLE} fetch
				WORKING_DIRECTORY "${sources-path}/${${dependency}.name}"
				OUTPUT_QUIET
			)
			
			execute_process(
				COMMAND ${GIT_EXECUTABLE} checkout ${checkout-argument}
				WORKING_DIRECTORY "${sources-path}/${${dependency}.name}"
				OUTPUT_QUIET
			)
			
			message("${${dependency}.name} HEAD changed... rebuilding")
		endif()
		
		if (DEFINED ${dependency}.branch)
			message("Pulling ${${dependency}.name}...")
			
			set(recurse-argument "")
			if (DEFINED ${dependency}.fetch-submodules)
				if (${${dependency}.fetch-submodules})
					set(recurse-argument "--recurse-submodules")
				endif()
			endif()
			
			execute_process(
				COMMAND ${GIT_EXECUTABLE} pull ${recurse-argument}
				OUTPUT_VARIABLE pull-result
				WORKING_DIRECTORY "${sources-path}/${${dependency}.name}"
				ERROR_QUIET
			)
			
			dependency_current_revision(${dependency} pulled-revision)
			dependency_built_revision(${dependency} built-revision)
			
			if(NOT "${pulled-revision}" STREQUAL "${built-revision}")
				message("${${dependency}.name} branch updated... rebuilding")
			endif()
		endif()
		
		check_local_options(${dependency} options-changed)
		if(options-changed)
			message("${${dependency}.name} options changed... rebuilding")
		endif()
		
		should_rebuild_dependency(${dependency} ${test-build-cache} "${cmake-flags}" should-build)
		if(should-build)
			build_dependency(${dependency} "${cmake-flags}")
		endif()
	endif()
	
	if(EXISTS "${sources-path}/${${dependency}.name}/sbg-manifest.json")
		file(READ "${sources-path}/${${dependency}.name}/sbg-manifest.json" manifest_content_${${dependency}.name})
		
		ParseJson(manifest_${${dependency}.name} "${manifest_content_${${dependency}.name}}")
		
		if(NOT "${manifest_${${dependency}.name}._type}" STREQUAL "object")
			message(FATAL_ERROR "The manifest for dependency \"${${dependency}.name}\" must contain a root object")
		endif()
		
		if (NOT DEFINED manifest_${${dependency}.name}.dependencies)
			message(FATAL_ERROR "The manifest for dependency \"${${dependency}.name}\" does not contains dependencies or is invalid")
		endif()
		
		update_local_dependency_list(manifest_${${dependency}.name}.dependencies "${cmake-flags}")
	endif()
endfunction()

function(current_cmake_arguments starts-at return-value)
	set(cmake-arguments "")
	math(EXPR cmake-arguments-end "${CMAKE_ARGC} - 1")
	foreach(arg RANGE ${cmake-arguments-starts} ${cmake-arguments-end})
		list(APPEND cmake-arguments "${CMAKE_ARGV${arg}}")
	endforeach()
	set(${return-value} ${cmake-arguments} PARENT_SCOPE)
endfunction()

function(list_to_absolute input-list return-value)
	set(adapted-list "")
	foreach(path ${input-list})
		if(IS_ABSOLUTE ${path})
			list(APPEND adapted-list "${path}")
		else()
			message("Warning: A prefix or a module path is containing a relative path\nThis can lead to disprancy between the path when building dependencies")
			list(APPEND adapted-list "\${PROJECT_SOURCE_DIR}/${path}")
		endif()
	endforeach()
	set(${return-value} "${adapted-list}" PARENT_SCOPE)
endfunction()

function(update_dependency_list_file dependency-list)
	set(dependency-names "")
	foreach(dependency-id ${${dependency-list}})
		set(dependency ${dependency-list}_${dependency-id})
		list(APPEND dependency-names "${${dependency}.name}")
	endforeach()
	
	
	if(EXISTS "${config-path}/${current-profile}-dependency-list.txt")
		file(READ "${config-path}/${current-profile}-dependency-list.txt" saved-dependency-list)
	else()
		set(saved-dependency-list "")
	endif()
	
	if(NOT "${dependency-names}" STREQUAL "${saved-dependency-list}")
		file(WRITE "${config-path}/${current-profile}-dependency-list.txt" "${dependency-names}")
	endif()
endfunction()

function(read_cmake_arguments return-value)
	file(READ "${config-path}/${current-profile}-arguments.txt" cmake-arguments)
	set(${return-value} "${cmake-arguments}" PARENT_SCOPE)
endfunction()

function(check_current_profile)
	if(NOT EXISTS "${installation-path}/${current-profile}-profile.cmake")
		if("${current-profile}" STREQUAL "default")
			setup_profile(manifest.dependencies "")
		else()
			message(FATAL_ERROR "Cannot read file profile configuration file. Run 'subgine-pkg setup ${current-profile}' to create the profile.")
		endif()
	endif()
endfunction()

function(setup_profile dependency-list cmake-arguments)
	argument_value(CMAKE_MODULE_PATH "${cmake-arguments}" argument-module-path)
	argument_value(CMAKE_PREFIX_PATH "${cmake-arguments}" argument-prefix-path)
	argument_value(CMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY "${cmake-arguments}" argument-no-package-registry)
	argument_value(CMAKE_FIND_USE_CMAKE_SYSTEM_PATH "${cmake-arguments}" argument-use-system-path)
	argument_value(CMAKE_FIND_PACKAGE_PREFER_CONFIG "${cmake-arguments}" argument-prefer-config)
	
	if(NOT "${argument-module-path}" STREQUAL "")
		list_to_absolute("${argument-module-path}" adapted-module-path)
		set(module-path-setup "list(APPEND CMAKE_MODULE_PATH \"${adapted-module-path}\")\n")
	else()
		set(module-path-setup "")
	endif()
	
	if(NOT "${argument-prefix-path}" STREQUAL "")
		list_to_absolute("${argument-prefix-path}" adapted-prefix-path)
		set(prefix-path-setup "list(APPEND CMAKE_PREFIX_PATH \"${adapted-prefix-path}\")")
	else()
		set(prefix-path-setup "")
	endif()
	
	if(NOT "${cmake-arguments}" STREQUAL "setup" AND "${current-profile}" STREQUAL "default")
		set(cmake-argument-help " ${cmake-arguments}")
	elseif(NOT "${cmake-arguments}" STREQUAL "setup")
		set(cmake-argument-help " ${current-profile} ${cmake-arguments}")
	else()
		set(cmake-argument-help "")
	endif()
		
	file(WRITE "${installation-path}/${current-profile}-profile.cmake" "# This file is generated by subgine-pkg please don't edit it.
# To regenerate this file, please use the following command:
#
#    $ subgine-pkg setup${cmake-argument-help}
#
# The arguments listed there are the one used by the last generation of this file.
#
# Please take a look at what we're doing there if you are curious!
# If you have feedback or improvements, please open an issue at our github tracker:
#
#    https://github.com/gracicot/subgine-pkg/issues
#

# These variables are for you!
# They are there for you to check if the project uses a profile and which one
set(subgine-pkg-\${PROJECT_NAME} ON)
set(subgine-pkg ON)
set(subgine-pkg-\${PROJECT_NAME}-profile \"${current-profile}\")
set(subgine-pkg-profile \"${current-profile}\")

# Tell CMake where to look or not to look packages. These can be overriden in the arguments passed to the profile.
set(CMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY ${argument-no-package-registry})
set(CMAKE_FIND_USE_CMAKE_SYSTEM_PATH ${argument-use-system-path})
set(CMAKE_FIND_PACKAGE_PREFER_CONFIG ${argument-prefer-config})

# Additional module and prefix paths specified by the subgine-pkg profile from command line
${module-path-setup}${prefix-path-setup}

# Prefix path for this project's subgine-pkg installation
list(APPEND CMAKE_PREFIX_PATH \"\${PROJECT_SOURCE_DIR}/${manifest.installation-path}/${library-directory-name}/${current-profile}/\")

# We scan the libraries to find what prefix path they need to be found
file(READ \"\${PROJECT_SOURCE_DIR}/${manifest.installation-path}/${config-directory-name}/${current-profile}-dependency-list.txt\" subgine-pkg-dependency-names)

foreach(dependency-name \${subgine-pkg-dependency-names})
	# For that dependency, find the generated file
	find_file(subgine-pkg-setup-file-\${dependency-name} subgine-pkg-\${dependency-name}-${current-profile}.cmake)
	
	# If the file is found, include it to read the prefix and module paths in there.
	# They may be required for that dependency to be found
	if(NOT \"\${subgine-pkg-setup-file-\${dependency-name}}\" STREQUAL \"subgine-pkg-setup-file-\${dependency-name}-NOTFOUND\")
		include(\"\${subgine-pkg-setup-file-\${dependency-name}}\")
		if(NOT \"\${found-pkg-\${dependency-name}-prefix-path}\" STREQUAL \"\")
			list(APPEND CMAKE_PREFIX_PATH \"\${found-pkg-\${dependency-name}-prefix-path}\")
		endif()
		if(NOT \"\${found-pkg-\${dependency-name}-module-path}\" STREQUAL \"\")
			list(APPEND CMAKE_MODULE_PATH \"\${found-pkg-\${dependency-name}-module-path}\")
		endif()
	endif()
	
	# Cleanup our mess
	unset(subgine-pkg-setup-file-\${dependency-name})
	unset(found-pkg-\${dependency-name}-prefix-path)
	unset(found-pkg-\${dependency-name}-module-path)
	unset(found-pkg-\${dependency-name}-manifest-path)
endforeach()

# We write a file that can be used with all the prefix paths this one needs
file(WRITE \"\${CMAKE_BINARY_DIR}/subgine-pkg-\${PROJECT_NAME}-${current-profile}.cmake\" \"
set(found-pkg-\${PROJECT_NAME}-prefix-path \\\"\${CMAKE_PREFIX_PATH}\\\")
set(found-pkg-\${PROJECT_NAME}-module-path \\\"\${CMAKE_MODULE_PATH}\\\")
set(found-pkg-\${PROJECT_NAME}-manifest-path \\\"\${CMAKE_SOURCE_DIR}/sbg-manifest.json\\\")\")

# Cleanup our mess
unset(subgine-pkg-dependency-names)
\n")
	file(WRITE "${config-path}/${current-profile}-arguments.txt" "${cmake-arguments}")
	file(WRITE "${config-path}/${current-profile}-add-prefix-path.cmake" "list(APPEND CMAKE_PREFIX_PATH \"\${CMAKE_SOURCE_DIR}/../../${library-directory-name}/${current-profile}/\")")
endfunction()

#
# Commands Implementation
#
if(NOT "${manifest.dependencies._type}" STREQUAL "array")
	message(FATAL_ERROR "The manifest must an an array 'dependencies' member of the root object")
endif()

select_profile("default")

if(${CMAKE_ARGV3} STREQUAL "setup")
	if(NOT "${CMAKE_ARGV4}" MATCHES "\\-.*")
		select_profile_from_arg(CMAKE_ARGV4)
		set(cmake-arguments-starts 5)
	else()
		set(cmake-arguments-starts 4)
	endif()
	
	current_cmake_arguments(${cmake-arguments-starts} cmake-arguments)
	setup_profile(manifest.dependencies "${cmake-arguments}")
	update_dependency_list_file(manifest.dependencies)
elseif(${CMAKE_ARGV3} STREQUAL "install")
	select_profile_from_arg(CMAKE_ARGV4)
	check_current_profile()
	read_cmake_arguments(cmake-arguments)
	
	update_dependency_list(manifest.dependencies "${cmake-arguments}")
	update_dependency_list_file(manifest.dependencies)
elseif(${CMAKE_ARGV3} STREQUAL "update")
	select_profile_from_arg(CMAKE_ARGV4)
	check_current_profile()
	read_cmake_arguments(cmake-arguments)
	
	update_local_dependency_list(manifest.dependencies "${cmake-arguments}")
	update_dependency_list_file(manifest.dependencies)
elseif(${CMAKE_ARGV3} STREQUAL "clean")
	foreach(dependency-id ${manifest.dependencies})
		if(NOT ${manifest.dependencies_${dependency-id}._type} STREQUAL "object")
			message(FATAL_ERROR "The dependency array must only contain objects")
		endif()
		
		if(IS_DIRECTORY "${sources-path}/${manifest.dependencies_${dependency-id}.name}/${build-directory-name}")
			file(REMOVE_RECURSE "${sources-path}/${manifest.dependencies_${dependency-id}.name}/${build-directory-name}")
		endif()
	endforeach()
	
	if (IS_DIRECTORY "${test-path}")
		file(REMOVE_RECURSE "${test-path}")
	endif()
	
elseif(${CMAKE_ARGV3} STREQUAL "prune")
	if (IS_DIRECTORY "${test-path}")
		file(REMOVE_RECURSE "${test-path}")
	endif()
	if(IS_DIRECTORY "${sources-path}")
		file(REMOVE_RECURSE "${sources-path}")
	endif()
	if(IS_DIRECTORY "${library-path}")
		file(REMOVE_RECURSE "${library-path}")
	endif()
elseif(${CMAKE_ARGV3} STREQUAL "remove")
	if("${CMAKE_ARGV4}" STREQUAL "")
		message("Usage: subgine-pkg remove <package-name>")
	else()
		foreach(dependency-id ${manifest.dependencies})
			if("${manifest.dependencies_${dependency-id}.name}" STREQUAL "${CMAKE_ARGV4}")
				set(dependency "manifest.dependencies_${dependency-id}")
			endif()
		endforeach()
		if(DEFINED dependency AND DEFINED ${dependency}.name)
			if(NOT IS_DIRECTORY "${sources-path}/${${dependency}.name}" AND NOT IS_DIRECTORY "${library-path}/${${dependency}.name}")
				message("Dependency \"${${dependency}.name}\" not installed locally... skipping")
			endif()
			
			if(IS_DIRECTORY "${sources-path}/${${dependency}.name}")
				file(REMOVE_RECURSE "${sources-path}/${${dependency}.name}")
			endif()
			
			file(GLOB profile-library-directories RELATIVE "${library-path}" "${library-path}/*")
			foreach(profile-library-directory ${profile-library-directories})
				if(IS_DIRECTORY "${library-path}/${profile-library-directory}")
					if(EXISTS "${config-path}/${profile-library-directory}-arguments.txt")
						if(IS_DIRECTORY "${library-path}/${profile-library-directory}/${${dependency}.name}")
							file(REMOVE_RECURSE "${library-path}/${profile-library-directory}/${${dependency}.name}")
						endif()
					endif()
				endif()
			endforeach()
		else()
			message(FATAL_ERROR "Dependency \"${CMAKE_ARGV4}\" does not exists, cannot remove")
		endif()
	endif()
endif()

endif()
endif()
