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
set /p LOCAL_PORT="Local port to listen on (default: 8080): "
if "%LOCAL_PORT%"=="" set LOCAL_PORT=8080

:get_remote_server
set /p REMOTE_SERVER="Remote server URL (e.g., https://api.example.com): "
if "%REMOTE_SERVER%"=="" (
    echo Remote server URL cannot be empty.
    goto get_remote_server
)

:get_remote_port
set /p REMOTE_PORT="Remote server port (the current port your server is listening on): "
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

REM Validate port number
echo %LOCAL_PORT%| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo Invalid port number. Please enter a valid number.
    goto get_local_port
)

REM Extract hostname/IP from URL and add the specified port for dial configuration
set SERVER_PROTOCOL=http
echo %REMOTE_SERVER% | findstr /i "https://" >nul && set SERVER_PROTOCOL=https
echo Protocol detected: %SERVER_PROTOCOL%

REM Clean the URL to get just the hostname/IP
set DIAL_HOST=%REMOTE_SERVER%
set DIAL_HOST=%DIAL_HOST:https://=%
set DIAL_HOST=%DIAL_HOST:http://=%
if "%DIAL_HOST:~-1%"=="/" set DIAL_HOST=%DIAL_HOST:~0,-1%

REM Combine hostname with the specified port
set DIAL_ADDRESS=%DIAL_HOST%:%REMOTE_PORT%

:get_bearer_token
set /p BEARER_TOKEN="Bearer token: "
if "%BEARER_TOKEN%"=="" (
    echo Bearer token cannot be empty.
    goto get_bearer_token
)

echo.
echo Optional settings:
set /p CUSTOM_HEADERS="Additional custom headers (format: Header1:Value1,Header2:Value2) [optional]: "
set /p SKIP_TLS_VERIFY="Skip TLS certificate verification? (Y/N, default: Y): "
if "%SKIP_TLS_VERIFY%"=="" set SKIP_TLS_VERIFY=Y

echo.
echo Configuration Summary:
echo ----------------------
echo Local Port: %LOCAL_PORT%
echo Remote Server: %REMOTE_SERVER%
echo Remote Port: %REMOTE_PORT%
echo Protocol: %SERVER_PROTOCOL%
echo Dial Address: %DIAL_ADDRESS%
echo Bearer Token: %BEARER_TOKEN:~0,10%...
echo Skip TLS Verify: %SKIP_TLS_VERIFY%
if not "%CUSTOM_HEADERS%"=="" echo Custom Headers: %CUSTOM_HEADERS%
echo.

set /p CONFIRM="Is this configuration correct? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo Configuration cancelled.
    pause
    exit /b 0
)

REM Generate Caddy configuration with logging
echo.
echo Generating Caddy configuration...

(
echo {
echo   "logging": {
echo     "logs": {
echo       "default": {
echo         "level": "INFO",
echo         "writer": {
echo           "output": "stdout"
echo         }
echo       },
echo       "access": {
echo         "level": "INFO",
echo         "writer": {
echo           "output": "stdout"
echo         },
echo         "include": ["http.log.access"]
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
echo                 { "path": ["/*"] }
echo               ],
echo               "handle": [
echo                 {
echo                   "handler": "reverse_proxy",
echo                   "upstreams": [
echo                     { "dial": "%DIAL_ADDRESS%" }
echo                   ],
REM For HTTPS: add transport config
if "%SERVER_PROTOCOL%"=="https" (
    if /i "%SKIP_TLS_VERIFY%"=="Y" (
        echo                   "transport": {
        echo                     "protocol": "http",
        echo                     "tls": {
        echo                       "insecure_skip_verify": true
        echo                     }
        echo                   },
    ) else (
        echo                   "transport": {
        echo                     "protocol": "http",
        echo                     "tls": {}
        echo                   },
    )
)
echo                   "headers": {
echo                     "request": {
echo                       "add": {
echo                         "Authorization": ["Bearer %BEARER_TOKEN%"]
REM Insert custom headers
if not "%CUSTOM_HEADERS%"=="" (
    setlocal enabledelayedexpansion
    set HEADER_LIST=%CUSTOM_HEADERS%
    set HEADER_LIST=!HEADER_LIST:,=~!
    for %%h in (!HEADER_LIST!) do (
        for /f "tokens=1,2 delims=:" %%k in ("%%h") do (
            echo                         ,"%%k": ["%%l"]
        )
    )
    endlocal
)
echo                         ,"X-Forwarded-For": ["{http.request.remote.host}"],
echo                         "X-Real-IP": ["{http.request.remote.host}"]
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
) > caddy-config.json

echo Configuration saved to caddy-config.json
echo.

REM Stop any existing Caddy processes
echo Stopping any existing Caddy processes...
taskkill /f /im caddy_windows_amd64.exe >nul 2>&1
timeout /t 2 /nobreak >nul

REM Start Caddy with the generated configuration
echo Starting Caddy proxy server...
echo.
echo Proxy will be available at: http://localhost:%LOCAL_PORT%
echo Forwarding to: %REMOTE_SERVER%:%REMOTE_PORT%
echo.
echo ================================
echo Caddy Proxy Server is running!
echo ================================
echo Local endpoint: http://localhost:%LOCAL_PORT%
echo Remote target: %REMOTE_SERVER%:%REMOTE_PORT%
echo Authentication: Bearer token added automatically
echo.
echo Test your proxy with:
echo curl http://localhost:%LOCAL_PORT%/your-endpoint
echo.
echo Logs will appear below. Press Ctrl+C to stop the server...
echo ================================
echo.

REM Start Caddy in foreground to see logs in terminal
caddy_windows_amd64.exe run --config caddy-config.json

REM This will only execute if Caddy exits
echo.
echo Server stopped.
pause