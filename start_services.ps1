# Stop execution on errors
$ErrorActionPreference = "Stop"

# Запрос IP и установка переменной
$externalIp = Read-Host "Write IP, please (example 193.123.12.12)"
$env:EXTERNAL_ORIGIN = "http://${externalIp}:4200"

# Создание временного .env файла
$envContent = @"
EXTERNAL_ORIGIN=${env:EXTERNAL_ORIGIN}
"@
Set-Content -Path .\.env -Value $envContent

$composeBackendFile = ".\workchat-backend-docker-compose.yml"
$composeFrontendFile = ".\workchat-frontend-docker-compose.yml"

function Start-Service {
    param(
        [string]$composeFile,
        [string]$serviceName
    )
    docker-compose -f $composeFile up -d $serviceName
    Write-Output "Started $serviceName, waiting 1 second..."
    Start-Sleep -Seconds 1
}


try {
    Write-Output "Processing backend services..."
    $backendServices = @(
        "postgres",
        "wc-service-registration",
        "wc-service-emaildomains", 
        "wc-service-employees",
        "wc-service-personaldata",
        "wc-service-authentication",
        "chats-service",
        "messages-service",
        "wc-service-emaildomains-createdomain",
        "wc-service-employees-createposition",
        "wc-service-registration-createadmin",
        "wc-service-authentication-authorizationadmin"
    )

    Write-Output "Pulling backend images..."
    docker-compose -f $composeBackendFile pull
    
    Write-Output "Building backend images..."
    docker-compose -f $composeBackendFile build

    foreach ($service in $backendServices) {
        Start-Service -composeFile $composeBackendFile -serviceName $service
    }

    Write-Output "`nProcessing frontend services..."
    $frontendServices = @(
        "workchat-client"
    )

    Write-Output "Pulling frontend images..."
    docker-compose -f $composeFrontendFile pull
    
    Write-Output "Building frontend images..."
    docker-compose -f $composeFrontendFile build

    foreach ($service in $frontendServices) {
        Start-Service -composeFile $composeFrontendFile -serviceName $service
    }

    Write-Output "`nAll services have been started with CORS for: $env:EXTERNAL_ORIGIN"
}
finally {
    if (Test-Path .\.env) {
        Remove-Item -Path .\.env -Force
        Write-Output "Temporary .env file removed."
    }
}

Write-Output "`nPress Enter to stop all docker-compose services..."
[System.Console]::ReadLine() | Out-Null

Write-Output "Stopping all services..."
docker-compose -f $composeBackendFile stop
docker-compose -f $composeFrontendFile stop
Write-Output "Docker-compose services have been stopped."