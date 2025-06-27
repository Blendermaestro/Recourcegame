@echo off
echo Starting Flutter Calendar App...
echo.

REM Get the directory where this batch file is located
set SCRIPT_DIR=%~dp0

REM Navigate to the calendar_app directory
cd /d "%SCRIPT_DIR%calendar_app"

REM Check if we're in the right directory by looking for pubspec.yaml
if not exist "pubspec.yaml" (
    echo ERROR: pubspec.yaml not found!
    echo Current directory: %CD%
    echo Expected to be in: %SCRIPT_DIR%calendar_app
    echo.
    echo Make sure this batch file is placed in the CalendarApp root directory
    pause
    exit /b 1
)

echo Found pubspec.yaml - good!
echo Current directory: %CD%
echo.

REM Run flutter doctor first to check setup
echo Checking Flutter setup...
flutter doctor --version
echo.

REM Run the app with proper execution
echo Starting Flutter app in Chrome...
echo This may take a moment to compile and launch...
echo.
powershell -Command "flutter run -d chrome"

REM Keep window open regardless of result
echo.
echo Flutter app session ended.
pause 