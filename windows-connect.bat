@echo off
REM RCCR Windows Auto-Connect Wrapper
REM Double-click this file to auto-connect to Control node

powershell.exe -ExecutionPolicy Bypass -File "%~dp0windows-connect.ps1"
pause
