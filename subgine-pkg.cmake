cmake_policy(SET CMP0012 NEW)
cmake_policy(SET CMP0057 NEW)

#
# Help Printing
#

function(print_help)
	message("usage: subgine-pkg <command> [<args>]")
	message("")
	message("Avalable commands:")
	message("   setup    Create the subgine-pkg.cmake file")
	message("   install  Fetch and install dependencies")
	message("   update   Install and update local dependencies")
	message("   clean    Clean all build and cache directories")
	message("   prune    Delete all cache, installed packages and fetched sources")
	message("   help     Print this help")
endfunction()

set(command-list "update" "clean" "prune" "help" "setup" "install")

if(${CMAKE_ARGC} LESS 4)
	print_help()
elseif(${CMAKE_ARGC} EQUAL 4)

if(${CMAKE_ARGV3} STREQUAL "help")
	print_help()
elseif(NOT ${CMAKE_ARGV3} IN_LIST command-list)
	message(FATAL_ERROR "subgine-pkg: '${CMAKE_ARGV3}' is not a subgine-pkg command. See 'subgine-pkg help'")
else()

#
# Json Parser
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
# Environement Validation
#

set(current-directory "${CMAKE_CURRENT_SOURCE_DIR}")

if(NOT EXISTS "${current-directory}/lockfile.json")
	message(FATAL_ERROR "A lockfile.json file must be in the current working directory")
endif()

file(READ "lockfile.json" lockfile_content)

ParseJson(lockfile "${lockfile_content}")

if(NOT "${lockfile._type}" STREQUAL "object")
	message(FATAL_ERROR "The lockfile must contain a root object")
endif()

if(NOT DEFINED lockfile.installation-path)
	message(FATAL_ERROR "The lockfile must contain a string member installation-path")
endif()

set(installation-path "${current-directory}/${lockfile.installation-path}")
set(test-path "${installation-path}/.test")

set(library-directory-name "module")
set(sources-directory-name "sources")

set(sources-path "${installation-path}/${sources-directory-name}")
set(library-path "${installation-path}/${library-directory-name}")
set(build-directory-name "build")
set(options-file-name "subgine-pkg-options.txt")

if (WIN32)
	set(used-generator "Visual Studio 15 2017 Win64")
else()
	set(used-generator "Unix Makefiles")
endif()

#
# Dependency Functions
#

function(assert_dependency_json_valid dependency)
	if(NOT DEFINED ${dependency}.name)
		message(FATAL_ERROR "The dependency '${dependency}' must have a name")
	endif()
	if(NOT DEFINED ${dependency}.target)
		message(FATAL_ERROR "The dependency '${${dependency}.name}' must have a target specified")
	endif()
	if(NOT DEFINED ${dependency}.repository)
		message(FATAL_ERROR "The dependency '${${dependency}.name}' must have a repository specified")
	endif()
	if(NOT DEFINED ${dependency}.tag AND NOT DEFINED ${dependency}.branch)
		message(FATAL_ERROR "The dependency '${${dependency}.name}' must have a tag or branch specified")
	endif()
endfunction()

function(check_dependency_exist dependency)
	if (NOT IS_DIRECTORY "${installation-path}")
		file(MAKE_DIRECTORY "${installation-path}")
	endif()
	
	if (NOT IS_DIRECTORY "${test-path}")
		file(MAKE_DIRECTORY "${test-path}")
	endif()
	
	if(DEFINED lockfile.cmake-module-path)
		set(cmake-module-path-command "list(APPEND CMAKE_MODULE_PATH \"${current-directory}/${lockfile.cmake-module-path}\")")
	else()
		set(cmake-module-path-command "")
	endif()
	
	if(NOT "${${dependency}.ignore-version}" STREQUAL "true")
		if(DEFINED ${dependency}.version)
			set(version-string-validate "${${dependency}.version}")
		elseif(DEFINED ${dependency}.tag)
			string(REGEX MATCH "^v" matches "${${dependency}.tag}")
			
			if("${matches}" STREQUAL "v")
				string(SUBSTRING "${${dependency}.tag}" 1 -1 version-string-validate)
			else()
				set(version-string-validate "${${dependency}.tag}")
			endif()
		else()
			set(version-string-validate "")
		endif()
		
		if(NOT "${version-string-validate}" STREQUAL "")
			if(${${dependency}.strict})
				set(cmake-version-check "${version-string-validate} EXACT")
			else()
				set(cmake-version-check "${version-string-validate}")
			endif()
		else()
				set(cmake-version-check "")
		endif()
	else()
		set(cmake-version-check "")
	endif()
	
	
	file(WRITE "${test-path}/CMakeLists.txt" "cmake_minimum_required(VERSION 3.0)\nunset(${${dependency}.name}_DIR CACHE)\n${cmake-module-path-command}\nlist(APPEND CMAKE_PREFIX_PATH \"${library-path}\")\nfind_package(${${dependency}.name} ${cmake-version-check} REQUIRED)\nif(TARGET ${${dependency}.target})\nelse()\nmessage(SEND_ERROR \"Package ${${dependency}.name} not found\")\nendif()")
	execute_process(
		COMMAND cmake -G "${used-generator}" .
		WORKING_DIRECTORY "${test-path}"
		RESULT_VARIABLE result-check-dep
		OUTPUT_QUIET
		ERROR_QUIET
	)
	
	if (${result-check-dep} EQUAL 0)
		set(check-dependency-${${dependency}.name}-result ON PARENT_SCOPE)
	else()
		set(check-dependency-${${dependency}.name}-result OFF PARENT_SCOPE)
	endif()
endfunction()

function(update_dependency dependency)
	if(NOT IS_DIRECTORY "${sources-path}")
		file(MAKE_DIRECTORY "${sources-path}")
	endif()
	if(IS_DIRECTORY "${sources-path}/${${dependency}.name}/.git")
		message("fetching updates for ${${dependency}.name}")
		execute_process(
			COMMAND git fetch
			WORKING_DIRECTORY "${sources-path}/${${dependency}.name}"
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
			COMMAND git clone ${${dependency}.repository} ${${dependency}.name} ${recurse-argument}
			WORKING_DIRECTORY ${sources-path}
		)
	endif()
	
	if (DEFINED ${dependency}.tag)
		set(checkout-argument "${${dependency}.tag}")
	else()
		set(checkout-argument "${${dependency}.branch}")
	endif()

	execute_process(
		COMMAND git checkout ${checkout-argument}
		WORKING_DIRECTORY "${sources-path}/${${dependency}.name}"
	)
	
	if (DEFINED ${dependency}.branch)
		execute_process(
			COMMAND git pull
			WORKING_DIRECTORY "${sources-path}/${${dependency}.name}"
		)
	endif()
	
	set(recursive-pkg-arg "")
	if(EXISTS "${sources-path}/${${dependency}.name}/lockfile.json")
		message("Reading ${${dependency}.name} dependencies...")
		file(READ "${sources-path}/${${dependency}.name}/lockfile.json" lockfile_content_${${dependency}.name})

		ParseJson(lockfile_${${dependency}.name} "${lockfile_content_${${dependency}.name}}")

		if(NOT "${lockfile_${${dependency}.name}._type}" STREQUAL "object")
			message(FATAL_ERROR "The lockfile for dependency \"${${dependency}.name}\" must contain a root object")
		endif()
		
		if (NOT DEFINED lockfile_${${dependency}.name}.dependencies)
			message(FATAL_ERROR "The lockfile for dependency \"${${dependency}.name}\" does not contains dependencies or is invalid")
		endif()
		
		update_dependency_list(lockfile_${${dependency}.name}.dependencies)
		set(recursive-pkg-arg "-DCMAKE_PREFIX_PATH=${library-path}")
		check_dependency_exist(${dependency})
	endif()
	
	if ("${recursive-pkg-arg}" STREQUAL "" OR NOT ${check-dependency-${${dependency}.name}-result})
		build_dependency(${dependency})
	endif()
endfunction()

function(build_dependency dependency)
	if(NOT IS_DIRECTORY "${sources-path}/${${dependency}.name}/${build-directory-name}")
		file(MAKE_DIRECTORY "${sources-path}/${${dependency}.name}/${build-directory-name}")
	endif()
	
	if(DEFINED ${dependency}.options)
		file(WRITE "${sources-path}/${${dependency}.name}/${build-directory-name}/${options-file-name}" "${${dependency}.options}")
	else()
		file(REMOVE "${sources-path}/${${dependency}.name}/${build-directory-name}/${options-file-name}")
	endif()
	
	set(options-set ${${dependency}.options})
	separate_arguments(options-set)
	execute_process(
		COMMAND cmake -G "${used-generator}"  .. ${recursive-pkg-arg} -DCMAKE_INSTALL_PREFIX=${library-path} ${options-set}
		WORKING_DIRECTORY "${sources-path}/${${dependency}.name}/${build-directory-name}"
	)
	
	if(WIN32)
		set(additional-flags "")
	else()
		include(ProcessorCount)
		ProcessorCount(cores)
		if(NOT ${cores} EQUAL 0)
			set(additional-flags "-- -j${cores}")
			separate_arguments(additional-flags)
		else()
			set(additional-flags "")
		endif()
	endif()
	
	execute_process(
		COMMAND cmake --build . ${additional-flags}
		WORKING_DIRECTORY "${sources-path}/${${dependency}.name}/${build-directory-name}"
	)
	
	check_dependency_exist(${dependency})
	
	if (NOT ${check-dependency-${${dependency}.name}-result})
		execute_process(
			COMMAND cmake --build . --target install ${additional-flags}
			WORKING_DIRECTORY "${sources-path}/${${dependency}.name}/${build-directory-name}"
		)
	endif()
endfunction()

function(update_dependency_list dependency-list)
	foreach(dependency-id ${${dependency-list}})
		set(dependency ${dependency-list}_${dependency-id})
		if(NOT ${${dependency}._type} STREQUAL "object")
			message(FATAL_ERROR "The dependency array must only contain objects")
		endif()
		
		assert_dependency_json_valid(${dependency})
		check_dependency_exist(${dependency})
	endforeach()
	
	file(READ "${test-path}/CMakeCache.txt" test-cache)
	
	foreach(dependency-id ${${dependency-list}})
		set(dependency ${dependency-list}_${dependency-id})
		
		if (${check-dependency-${${dependency}.name}-result})
			if(IS_DIRECTORY "${sources-path}/${${dependency}.name}")
				check_local_options(${dependency})
				
				if(check-local-options-${${dependency}.name}-result)
					message("${${dependency}.name} options changed... rebuilding")
					build_dependency(${dependency})
				else()
					message("${${dependency}.name} found")
				endif()
			else()
				message("${${dependency}.name} found")
			endif()
		else()
			message("${${dependency}.name} not found... installing")
			update_dependency(${dependency})
		endif()
	endforeach()
endfunction()

function(update_local_dependency_list dependency-list)
	foreach(dependency-id ${${dependency-list}})
		set(dependency ${dependency-list}_${dependency-id})
		if(NOT ${${dependency}._type} STREQUAL "object")
			message(FATAL_ERROR "The dependency array must only contain objects")
		endif()
		
		assert_dependency_json_valid(${dependency})
		check_dependency_exist(${dependency})
	endforeach()

	file(READ "${test-path}/CMakeCache.txt" test-cache)

	foreach(dependency-id ${${dependency-list}})
		set(dependency ${dependency-list}_${dependency-id})
		if (${check-dependency-${${dependency}.name}-result})
			update_local_dependency(${dependency})
		endif()
	endforeach()
	
	update_dependency_list(${dependency-list})
endfunction()

function(check_local_options)
	check_local_dependency(${dependency})
	set(check-local-options OFF)
	
	if(check-local-dependency-${${dependency}.name}-result)
		if(DEFINED ${dependency}.options)
			if(EXISTS "${sources-path}/${${dependency}.name}/${build-directory-name}/${options-file-name}")
				file(READ "${sources-path}/${${dependency}.name}/${build-directory-name}/${options-file-name}" options-string)
				
				if("${options-string}" STREQUAL "${${dependency}.options}")
					set(check-local-options OFF)
				else()
					set(check-local-options ON)
				endif()
			else()
				set(check-local-options ON)
			endif()
		else()
			if(EXISTS "${sources-path}/${${dependency}.name}/${build-directory-name}/${options-file-name}")
				set(check-local-options ON)
			else()
				set(check-local-options OFF)
			endif()
		endif()
	endif()
	if (${check-local-options})
		set(check-local-options-${${dependency}.name}-result ON PARENT_SCOPE)
	else()
		set(check-local-options-${${dependency}.name}-result OFF PARENT_SCOPE)
	endif()
endfunction()

function(check_local_dependency dependency)
	set(check-local-package OFF)
	if(IS_DIRECTORY "${sources-path}/${${dependency}.name}")
		string(REGEX MATCH "${${dependency}.name}_DIR:PATH=[^\n]*" matched-path "${test-cache}")
		if ("${matched-path}" STREQUAL "")
			if(ARGC GREATER 1 AND "${ARGV1}" STREQUAL "SKIPPING_VERBOSE")
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
		set(check-local-dependency-${${dependency}.name}-result ON PARENT_SCOPE)
	else()
		set(check-local-dependency-${${dependency}.name}-result OFF PARENT_SCOPE)
	endif()
endfunction()

function(check_branch_status dependency)
	set(check-branch-status OFF)
	
	if(DEFINED ${dependency}.branch)
		execute_process(
			COMMAND git symbolic-ref -q --short HEAD
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
			COMMAND git describe --tags --exact-match
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
		set(check-branch-status-${${dependency}.name}-result ON PARENT_SCOPE)
	else()
		set(check-branch-status-${${dependency}.name}-result OFF PARENT_SCOPE)
	endif()
endfunction()

function(update_local_dependency dependency)
	check_local_dependency(${dependency} SKIPPING_VERBOSE)
	
	if(check-local-dependency-${${dependency}.name}-result)
		check_branch_status(${dependency})
		
		set(should-build OFF)
		if(check-branch-status-${${dependency}.name}-result)
			if (DEFINED ${dependency}.tag)
				set(checkout-argument "${${dependency}.tag}")
				message("${${dependency}.name}: checkout tag ${${dependency}.tag}")
			else()
				set(checkout-argument "${${dependency}.branch}")
				message("${${dependency}.name}: checkout branch ${${dependency}.branch}")
			endif()
			
			execute_process(
				COMMAND git fetch
				WORKING_DIRECTORY "${sources-path}/${${dependency}.name}"
				OUTPUT_QUIET
			)
			
			execute_process(
				COMMAND git checkout ${checkout-argument}
				WORKING_DIRECTORY "${sources-path}/${${dependency}.name}"
				OUTPUT_QUIET
			)
			
			message("${${dependency}.name} HEAD changed... rebuilding")
			set(should-build ON)
		endif()
		
		if (DEFINED ${dependency}.branch)
			message("pulling ${${dependency}.name}...")
			execute_process(
				COMMAND git pull
				OUTPUT_VARIABLE pull-result
				WORKING_DIRECTORY "${sources-path}/${${dependency}.name}"
			)
			
			if(NOT "${pull-result}" MATCHES "Already up")
				set(should-build ON)
			endif()
		endif()
		
		check_local_options(${dependency})
		
		if(check-local-options-${${dependency}.name}-result)
			message("${${dependency}.name} options changed... rebuilding")
			set(should-build ON)
		endif()
		
		if(should-build)
			build_dependency(${dependency})
		endif()
	endif()
	
	if(EXISTS "${sources-path}/${${dependency}.name}/lockfile.json")
		file(READ "${sources-path}/${${dependency}.name}/lockfile.json" lockfile_content_${${dependency}.name})
		
		ParseJson(lockfile_${${dependency}.name} "${lockfile_content_${${dependency}.name}}")
		
		if(NOT "${lockfile_${${dependency}.name}._type}" STREQUAL "object")
			message(FATAL_ERROR "The lockfile for dependency \"${${dependency}.name}\" must contain a root object")
		endif()
		
		if (NOT DEFINED lockfile_${${dependency}.name}.dependencies)
			message(FATAL_ERROR "The lockfile for dependency \"${${dependency}.name}\" does not contains dependencies or is invalid")
		endif()
		
		update_local_dependency_list(lockfile_${${dependency}.name}.dependencies)
	endif()
endfunction()

#
# Commands Implementation
#

if(${CMAKE_ARGV3} STREQUAL "setup")
	if(DEFINED lockfile.cmake-module-path)
		set(module-path-setup "list(APPEND CMAKE_MODULE_PATH \"\${CMAKE_CURRENT_SOURCE_DIR}/${lockfile.cmake-module-path}\")")
	else()
		set(module-path-setup "")
	endif()
	
	file(WRITE "${current-directory}/subgine-pkg.cmake" "list(APPEND CMAKE_PREFIX_PATH \"\${CMAKE_CURRENT_SOURCE_DIR}/${lockfile.installation-path}/${library-directory-name}/\")\n${module-path-setup}\n")
elseif(${CMAKE_ARGV3} STREQUAL "install")
	update_dependency_list(lockfile.dependencies)
elseif(${CMAKE_ARGV3} STREQUAL "update")
	update_local_dependency_list(lockfile.dependencies)
elseif(${CMAKE_ARGV3} STREQUAL "clean")
	if(NOT "${lockfile.dependencies._type}" STREQUAL "array")
		message(FATAL_ERROR "The lockfile must an an array 'dependencies' member of the root object")
	endif()
	
	foreach(dependency-id ${lockfile.dependencies})
		if(NOT ${lockfile.dependencies_${dependency-id}._type} STREQUAL "object")
			message(FATAL_ERROR "The dependency array must only contain objects")
		endif()
		
		if(IS_DIRECTORY "${sources-path}/${lockfile.dependencies_${dependency-id}.name}/${build-directory-name}")
			file(REMOVE_RECURSE "${sources-path}/${lockfile.dependencies_${dependency-id}.name}/${build-directory-name}")
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
	
endif()
endif()
endif()
