@echo off
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Start-Process -WindowStyle Hidden -FilePath powershell -ArgumentList '-ExecutionPolicy Bypass -File \"%~dp0traffic_light.ps1\"'"
