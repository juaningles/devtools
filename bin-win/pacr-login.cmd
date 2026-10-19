@echo pacr-login %*

@echo off
setlocal

if "%~1"=="" (
    echo Usage: %~nx0 ^<acr-name^>
    exit /b 1
)

set "ACR=%~1"

for /f "usebackq delims=" %%t in (`az acr login -n %ACR% --expose-token --output tsv --query accessToken`) do set "acrtoken=%%t"

if not defined acrtoken (
    echo Failed to retrieve ACR access token for %ACR%
    exit /b 1
)

podman login %ACR%.azurecr.io -u "00000000-0000-0000-0000-000000000000" -p "%acrtoken%"

endlocal