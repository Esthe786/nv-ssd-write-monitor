@echo off
rem NVIDIA SSD write monitor - double-click to run. Optional: nvwatch.bat -IntervalSec 60 -Hours 6
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0nvwatch.ps1" %*
pause
