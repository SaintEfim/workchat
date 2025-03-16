# Stop execution on errors
$ErrorActionPreference = "Stop"

# Запрос IP и установка переменной
$externalIp = Read-Host "Write IP, please (example 193.123.12.12)"
$env:EXTERNAL_ORIGIN = "http://${externalIp}:4200"

# Пути к конфигурационным файлам
$configFiles = @(
    ".\configs\chats\config.yaml",
    ".\configs\messages\config.yaml"
)

# Обновление конфигурационных файлов
foreach ($configFile in $configFiles) {
    if (Test-Path $configFile) {
        try {
            # Создаем бэкап файла
            $backupFile = "$configFile.bak"
            Copy-Item $configFile $backupFile -Force
            
            # Читаем и изменяем содержимое
            $content = Get-Content $configFile -Raw
            $pattern = '(AllowedOrigins:\s*\[)[^\]]*'
            $replacement = "`$1`"$env:EXTERNAL_ORIGIN`", `"http://localhost:4200`""
            
            $newContent = $content -replace $pattern, $replacement
            
            # Проверяем что изменения применились
            if ($newContent -ne $content) {
                Set-Content $configFile -Value $newContent
                Write-Output "Updated CORS in $configFile"
            }
            else {
                Write-Warning "No changes made to $configFile"
            }
        }
        catch {
            Write-Error "Failed to update $configFile : $_"
            # Восстанавливаем файл из бэкапа при ошибке
            if (Test-Path $backupFile) {
                Copy-Item $backupFile $configFile -Force
            }
            throw
        }
    }
    else {
        Write-Warning "Config file not found: $configFile"
    }
}

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
    # Удаление временного .env файла
    if (Test-Path .\.env) {
        Remove-Item -Path .\.env -Force
        Write-Output "Temporary .env file removed."
    }
    
    # Очистка бэкапов конфигов
    foreach ($configFile in $configFiles) {
        $backupFile = "$configFile.bak"
        if (Test-Path $backupFile) {
            Remove-Item -Path $backupFile -Force -ErrorAction SilentlyContinue
            Write-Output "Removed backup file: $backupFile"
        }
    }
}

Write-Output "`nPress Enter to stop all docker-compose services..."
[System.Console]::ReadLine() | Out-Null

Write-Output "Stopping all services..."
docker-compose -f $composeBackendFile down
docker-compose -f $composeFrontendFile down
Write-Output "Docker-compose services have been stopped."