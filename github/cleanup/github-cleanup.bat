@echo off
chcp 65001 >nul
REM GitHub Repository Cleanup Tool - Batch Wrapper
REM This script provides a convenient way to run the Python cleanup tool on Windows

setlocal enabledelayedexpansion

REM Check for minimum arguments
if "%~2"=="" (
    echo Usage: %~nx0 ^<owner^> ^<repo^> [--dry-run] [--verbose]
    echo.
    echo Arguments:
    echo   owner        GitHub repository owner/organization
    echo   repo         GitHub repository name
    echo.
    echo Options:
    echo   --dry-run    Show what would be deleted without actually deleting
    echo   --verbose    Enable verbose output
    echo.
    echo Examples:
    echo   %~nx0 bauer-group automation-templates --dry-run
    echo   %~nx0 myorg myrepo
    exit /b 1
)

set "OWNER=%~1"
set "REPO=%~2"
set "DRY_RUN="
set "VERBOSE="

REM Process optional arguments
shift
shift
:parse_args
if "%~1"=="" goto :end_parse
if "%~1"=="--dry-run" (
    set "DRY_RUN=--dry-run"
    shift
    goto :parse_args
)
if "%~1"=="--verbose" (
    set "VERBOSE=--verbose"
    shift
    goto :parse_args
)
echo ❌ Unknown option: %~1
exit /b 1

:end_parse

echo 🧹 GitHub Repository Cleanup Tool
echo =================================

REM Check if Python is available
echo 🔍 Checking Python installation...
python --version >nul 2>&1
if !errorlevel! equ 0 (
    set "PYTHON_CMD=python"
    echo ✅ Python found: python
) else (
    python3 --version >nul 2>&1
    if !errorlevel! equ 0 (
        set "PYTHON_CMD=python3"
        echo ✅ Python found: python3
    ) else (
        py --version >nul 2>&1
        if !errorlevel! equ 0 (
            set "PYTHON_CMD=py"
            echo ✅ Python found: py
        ) else (
            echo ❌ Python not found!
            echo 💡 Please install Python from https://python.org
            exit /b 1
        )
    )
)

REM Check if requirements.txt exists
if not exist "%~dp0requirements.txt" (
    echo ❌ requirements.txt not found!
    exit /b 1
)

REM Install dependencies
echo 📦 Installing Python dependencies...
%PYTHON_CMD% -m pip install --upgrade pip --quiet
if !errorlevel! neq 0 (
    echo ❌ Failed to upgrade pip
    exit /b 1
)

%PYTHON_CMD% -m pip install -r "%~dp0requirements.txt" --quiet --user
if !errorlevel! neq 0 (
    echo ❌ Failed to install dependencies
    echo 💡 Try running: %PYTHON_CMD% -m pip install -r requirements.txt
    exit /b 1
)

echo ✅ Dependencies installed successfully

REM Check if main script exists
if not exist "%~dp0github_cleanup.py" (
    echo ❌ github_cleanup.py not found!
    exit /b 1
)

REM Run the cleanup tool
echo 🚀 Starting GitHub Cleanup Tool...
echo 📂 Repository: %OWNER%/%REPO%

if defined DRY_RUN (
    echo 🔍 DRY-RUN mode - no changes will be made
)

%PYTHON_CMD% "%~dp0github_cleanup.py" --owner "%OWNER%" --repo "%REPO%" %DRY_RUN% %VERBOSE%

if !errorlevel! equ 0 (
    echo ✅ Cleanup completed successfully!
) else (
    echo ❌ Cleanup completed with errors
    exit /b !errorlevel!
)

echo 🎉 Done!
