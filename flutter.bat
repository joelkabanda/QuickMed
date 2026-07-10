@echo off
REM Flutter workaround batch file
setlocal enabledelayedexpansion

set DART_EXE=C:\src\flutter\flutter\bin\cache\dart-sdk\bin\dart.exe
set FLUTTER_TOOLS_DIR=C:\src\flutter\flutter\packages\flutter_tools
set FLUTTER_ROOT=C:\src\flutter\flutter

set FLUTTER_TOOL_ARGS=%*

"%DART_EXE%" --packages="%FLUTTER_TOOLS_DIR%\.dart_tool\package_config.json" "%FLUTTER_TOOLS_DIR%\bin\flutter_tools.dart" %FLUTTER_TOOL_ARGS%
