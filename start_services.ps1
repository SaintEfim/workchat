# Stop execution on errors
$ErrorActionPreference = "Stop"

# Function to get the system's IP address
function Get-SystemIP {
    # Get all IPv4 addresses, excluding loopback and inactive interfaces
    $networkAdapters = Get-NetIPAddress -AddressFamily IPv4 | 
                       Where-Object { $_.InterfaceAlias -notmatch "Loopback" -and $_.PrefixOrigin -eq "Dhcp" }

    if ($networkAdapters) {
        # Return the first found IPv4 address
        return $networkAdapters[0].IPAddress
    }

    # If no DHCP address is found, look for any IPv4 address (excluding loopback)
    $fallbackAdapters = Get-NetIPAddress -AddressFamily IPv4 | 
                        Where-Object { $_.InterfaceAlias -notmatch "Loopback" }

    if ($fallbackAdapters) {
        return $fallbackAdapters[0].IPAddress
    }

    # If nothing is found, return localhost
    return "127.0.0.1"
}

# Function to validate an IP address
function Test-ValidIP {
    param([string]$ip)
    return $ip -match '^\d{1,3}(\.\d{1,3}){3}$'
}

# Get the system's default IP address
$defaultIP = Get-SystemIP
Write-Output "Detected system IP: $defaultIP"

# Prompt for IP with validation
do {
    $externalIp = Read-Host "Enter IP (default is $defaultIP, press Enter to use it)"
    if ([string]::IsNullOrEmpty($externalIp)) {
        $externalIp = $defaultIP
    }
    if (-not (Test-ValidIP $externalIp)) {
        Write-Warning "Invalid IP address. Please enter a valid IPv4 address."
    }
} until (Test-ValidIP $externalIp)

# Set the environment variable
$env:EXTERNAL_ORIGIN = "http://${externalIp}:4200"

# Paths to configuration files
$configFiles = @(
    ".\configs\chats\config.yaml",
    ".\configs\messages\config.yaml"
)

# Update configuration files
foreach ($configFile in $configFiles) {
    if (Test-Path $configFile) {
        try {
            # Create a backup of the file
            $backupFile = "$configFile.bak"
            Copy-Item $configFile $backupFile -Force
            
            # Read and modify the content
            $content = Get-Content $configFile -Raw
            $pattern = '(AllowedOrigins:\s*\[)[^\]]*'
            $replacement = "`$1`"$env:EXTERNAL_ORIGIN`", `"http://localhost:4200`""
            
            $newContent = $content -replace $pattern, $replacement
            
            # Verify that changes were applied
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
            # Restore the file from backup in case of error
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

# Create a temporary .env file
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
    # Remove the temporary .env file
    if (Test-Path .\.env) {
        Remove-Item -Path .\.env -Force
        Write-Output "Temporary .env file removed."
    }
    
    # Clean up config backups
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