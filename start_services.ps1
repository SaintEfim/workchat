# Stop execution on errors
$ErrorActionPreference = "Stop"

# Define the path to your docker-compose file
$composeFile = ".\workchat-backend-docker-compose.yml"

# Pull docker-compose
docker-compose -f $composeFile pull
Start-Sleep -Second 1

# Start postgres
docker-compose -f $composeFile up -d postgres
Write-Output "Started postgres, waiting 1 seconds..."
Start-Sleep -Seconds 1

# Start wc-service-registration
docker-compose -f $composeFile up -d wc-service-registration
Write-Output "Started wc-service-registration, waiting 1 seconds..."
Start-Sleep -Seconds 1

# Start wc-service-emaildomains
docker-compose -f $composeFile up -d wc-service-emaildomains
Write-Output "Started wc-service-emaildomains, waiting 1 seconds..."
Start-Sleep -Seconds 1

# Start wc-service-employees
docker-compose -f $composeFile up -d wc-service-employees
Write-Output "Started wc-service-employees, waiting 1 seconds..."
Start-Sleep -Seconds 1

# Start wc-service-personaldata
docker-compose -f $composeFile up -d wc-service-personaldata
Write-Output "Started wc-service-personaldata, waiting 1 seconds..."
Start-Sleep -Seconds 1

# Start wc-service-authentication
docker-compose -f $composeFile up -d wc-service-authentication
Write-Output "Started wc-service-authentication, waiting 1 seconds..."
Start-Sleep -Seconds 1

# Start chats-service
docker-compose -f $composeFile up -d chats-service
Write-Output "Started chats-service, waiting 1 seconds..."
Start-Sleep -Seconds 1

# Start messages-service
docker-compose -f $composeFile up -d messages-service
Write-Output "Started messages-service, waiting 1 seconds..."
Start-Sleep -Seconds 1

# Start wc-service-emaildomains-createdomain
docker-compose -f $composeFile up -d wc-service-emaildomains-createdomain
Write-Output "Started wc-service-emaildomains-createdomain, waiting 1 seconds..."
Start-Sleep -Seconds 1

# Start wc-service-employees-createposition
docker-compose -f $composeFile up -d wc-service-employees-createposition
Write-Output "Started wc-service-employees-createposition, waiting 1 seconds..."
Start-Sleep -Seconds 1

# Start wc-service-registration-createadmin
docker-compose -f $composeFile up -d wc-service-registration-createadmin
Write-Output "Started wc-service-registration-createadmin, waiting 1 seconds..."
Start-Sleep -Seconds 1

# Start wc-service-authentication-authorizationadmin
docker-compose -f $composeFile up -d wc-service-authentication-authorizationadmin
Write-Output "Started wc-service-authentication-authorizationadmin."

Write-Output "All services have been started sequentially."
