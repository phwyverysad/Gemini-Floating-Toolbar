@echo off
echo Installing Gemini Desktop Trusted Certificate...
certutil -addstore -user My "%~dp0Gemini_Certificate.cer"
echo [SUCCESS] Certificate added.
pause
