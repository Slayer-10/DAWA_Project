@echo off
cd /d %~dp0
echo Starting DAWA FastAPI Backend...
"C:\Users\haree\AppData\Local\Programs\Python\Python312\python.exe" -m uvicorn app.main:app --app-dir backend --host 127.0.0.1 --port 8000 --reload
pause

