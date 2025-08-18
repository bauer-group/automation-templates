@echo off
REM GitHub Repository Cleanup Tool - Windows Batch Wrapper
REM This script provides a convenient way to run the Python cleanup tool on Windows

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "PYTHON_SCRIPT=%SCRIPT_DIR%github_cleanup.py"

REM Check if Python is available
python --version >nul 2>&1
if %errorlevel% neq 0 (
    python3 --version >nul 2>&1
    if !errorlevel! neq 0 (
        echo ❌ Error: Python is not installed or not in PATH
        exit /b 1
    ) else (
        set "PYTHON_CMD=python3"
    )
) else (
    set "PYTHON_CMD=python"
)

REM Check if the Python script exists
if not exist "%PYTHON_SCRIPT%" (
    echo ❌ Error: Python script not found at %PYTHON_SCRIPT%
    exit /b 1
)

REM Install requirements if needed
if not exist "%SCRIPT_DIR%requirements_installed.flag" (
    echo 📦 Installing Python requirements...
    %PYTHON_CMD% -m pip install -r "%SCRIPT_DIR%requirements.txt"
    if !errorlevel! equ 0 (
        echo. > "%SCRIPT_DIR%requirements_installed.flag"
    )
)

REM Run the Python script with all passed arguments
echo 🚀 Starting GitHub Repository Cleanup Tool...
%PYTHON_CMD% "%PYTHON_SCRIPT%" %*
