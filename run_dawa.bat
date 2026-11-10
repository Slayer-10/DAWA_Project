@echo off
echo ==============================================
echo        Starting DAWA Healthcare Platform
echo ==============================================

echo [1/2] Starting FastAPI Backend on http://127.0.0.1:8000 ...
start "DAWA Backend Server" cmd /k "title DAWA Backend && cd /d %~dp0 && "C:\Users\haree\AppData\Local\Programs\Python\Python312\python.exe" -m uvicorn app.main:app --app-dir backend --host 127.0.0.1 --port 8000"

echo Waiting for backend to initialize...
timeout /t 3 /nobreak >nul

echo [2/2] Launching DAWA Flutter App in Chrome...
start "DAWA Flutter App" cmd /k "title DAWA Flutter App && cd /d %~dp0 && "C:\Users\haree\OneDrive\Desktop\flutter\bin\flutter.bat" run -d chrome"

echo Both services launched in separate windows!

