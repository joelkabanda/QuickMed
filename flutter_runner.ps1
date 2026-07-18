# Flutter runner script - bypasses batch file issues

$dartExe = "C:\src\flutter\flutter\bin\cache\dart-sdk\bin\dart.exe"
$flutterToolsDir = "C:\src\flutter\flutter\packages\flutter_tools"
$flutterRoot = "C:\src\flutter\flutter"

# Set up environment
$env:FLUTTER_ROOT = $flutterRoot

# Run flutter tools with all arguments passed through
$args_list = @("--packages=$flutterToolsDir\.dart_tool\package_config.json")
$args_list += "$flutterToolsDir\bin\flutter_tools.dart"
$args_list += $args

Write-Host "Running Flutter with args: $args_list" -ForegroundColor Cyan

& $dartExe @args_list
