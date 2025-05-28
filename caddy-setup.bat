@echo off
setlocal enabledelayedexpansion

echo ================================
echo    Caddy Proxy Setup Script
echo ================================
echo.

REM Check if caddy executable exists
if not exist "caddy_windows_amd64.exe" (
    echo ERROR: caddy_windows_amd64.exe not found in current directory
    echo Please download Caddy from https://caddyserver.com/download
    pause
    exit /b 1
)

REM Get user input for configuration
echo Please provide the following information:
echo.

:get_local_port
set /p LOCAL_PORT="Local port to listen on (default: 3000): "
if "%LOCAL_PORT%"=="" set LOCAL_PORT=3000

REM Validate port number
echo %LOCAL_PORT%| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo Invalid port number. Please enter a valid number.
    goto get_local_port
)

:get_remote_host
set /p REMOTE_HOST="Remote server host/IP (e.g., localhost, 192.168.1.100): "
if "%REMOTE_HOST%"=="" (
    echo Remote server host cannot be empty.
    goto get_remote_host
)

:get_remote_port
set /p REMOTE_PORT="Remote server port (internal port where Ollama is running): "
if "%REMOTE_PORT%"=="" (
    echo Remote server port cannot be empty.
    goto get_remote_port
)

REM Validate remote port number
echo %REMOTE_PORT%| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo Invalid port number. Please enter a valid number.
    goto get_remote_port
)

REM Construct the dial address
set DIAL_ADDRESS=%REMOTE_HOST%:%REMOTE_PORT%

:get_bearer_token
set /p BEARER_TOKEN="Bearer token: "
if "%BEARER_TOKEN%"=="" (
    echo Bearer token cannot be empty.
    goto get_bearer_token
)

echo.
echo Configuration Summary:
echo ----------------------
echo Public Port (Listen): %LOCAL_PORT%
echo Remote Host: %REMOTE_HOST%
echo Internal Port (Ollama): %REMOTE_PORT%
echo Dial Address: %DIAL_ADDRESS%
echo Bearer Token: %BEARER_TOKEN:~0,10%...
echo.

set /p CONFIRM="Is this configuration correct? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo Configuration cancelled.
    pause
    exit /b 0
)

REM Generate Caddy configuration matching the provided caddy.json structure
echo.
echo Generating Caddy configuration...

(
echo {
echo   "logging": {
echo     "logs": {
echo       "default": {
echo         "level": "INFO"
echo       }
echo     }
echo   },
echo   "apps": {
echo     "http": {
echo       "servers": {
echo         "proxy_server": {
echo           "listen": [":%LOCAL_PORT%"],
echo           "logs": {
echo             "default_logger_name": "access"
echo           },
echo           "routes": [
echo             {
echo               "match": [
echo                 {
echo                   "method": ["OPTIONS"]
echo                 }
echo               ],
echo               "handle": [
echo                 {
echo                   "handler": "headers",
echo                   "response": {
echo                     "set": {
echo                       "Access-Control-Allow-Origin": ["*"],
echo                       "Access-Control-Allow-Methods": ["GET, POST, PUT, DELETE, OPTIONS"],
echo                       "Access-Control-Allow-Headers": ["Content-Type, Authorization, X-Requested-With, Accept"],
echo                       "Access-Control-Max-Age": ["86400"]
echo                     }
echo                   }
echo                 },
echo                 {
echo                   "handler": "static_response",
echo                   "status_code": 200,
echo                   "body": ""
echo                 }
echo               ]
echo             },
echo             {
echo               "handle": [
echo                 {
echo                   "handler": "headers",
echo                   "response": {
echo                     "set": {
echo                       "Access-Control-Allow-Origin": ["*"],
echo                       "Access-Control-Allow-Methods": ["GET, POST, PUT, DELETE, OPTIONS"],
echo                       "Access-Control-Allow-Headers": ["Content-Type, Authorization, X-Requested-With, Accept"]
echo                     }
echo                   }
echo                 },
echo                 {
echo                   "handler": "reverse_proxy",
echo                   "upstreams": [
echo                     {
echo                       "dial": "%DIAL_ADDRESS%"
echo                     }
echo                   ],
echo                   "headers": {
echo                     "request": {
echo                       "set": {
echo                         "Authorization": ["Bearer %BEARER_TOKEN%"]
echo                       }
echo                     }
echo                   }
echo                 }
echo               ]
echo             }
echo           ]
echo         }
echo       }
echo     }
echo   }
echo }
) > caddy.json

echo Configuration saved to caddy.json
echo.

REM Stop any existing Caddy processes
echo Stopping any existing Caddy processes...
taskkill /f /im caddy_windows_amd64.exe >nul 2>&1
timeout /t 2 /nobreak >nul

REM Start Caddy with the generated configuration
echo Starting Caddy proxy server...
echo.
echo Proxy will be available at: http://localhost:%LOCAL_PORT%
echo Forwarding to: %REMOTE_HOST%:%REMOTE_PORT% (internal)
echo.
echo ================================
echo Caddy Proxy Server is running!
echo ================================
echo Public endpoint: http://localhost:%LOCAL_PORT%
echo Internal target: %REMOTE_HOST%:%REMOTE_PORT% (Ollama)
echo Authentication: Bearer token added automatically
echo CORS: Enabled for all origins
echo.
echo Security: Public port %LOCAL_PORT% -> Internal port %REMOTE_PORT%
echo.
echo Test your proxy with:
echo curl http://localhost:%LOCAL_PORT%/your-endpoint
echo.
echo Logs will appear below. Press Ctrl+C to stop the server...
echo ================================
echo.

REM Start Caddy in foreground to see logs in terminal
caddy_windows_amd64.exe run --config caddy.json

REM This will only execute if Caddy exits
echo.
echo Server stopped.
pause