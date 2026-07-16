# Project-level configuration file for Flutter Windows.
#
# This file should be version-controlled and should not be manually edited.

cmake_minimum_required(VERSION 3.15)
project(windows LANGUAGES CXX)

# The Flutter tooling requires that developers have CMake 3.15 or later
# installed. You should not increase this version, as doing so will cause
# the install step to fail on machines using older toolchain versions.

# Configuration provided via flutter tool, do not edit.
include(config.cmake)

# Configuration provided by the Flutter app, do not edit.
include(generated_plugins.cmake)

# Now that we have the Flutter metadata and the generated plugins, we have
# enough information to restructure the project.
enable_testing()

add_subdirectory(flutter)
add_subdirectory(runner)
