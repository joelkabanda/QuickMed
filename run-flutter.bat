@echo off
REM QuickMed Flutter Development Launcher
REM This batch file launches PowerShell with the flutter command ready to use

powershell -NoExit -Command ". $PROFILE; Write-Host 'Flutter environment loaded. Type: flutter run -d chrome' -ForegroundColor Green"
