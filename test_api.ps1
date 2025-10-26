# PowerShell script for testing Secure Process API with curl
# Windows PowerShell / PowerShell Core

# Configuration
$BaseUrl = "http://localhost:8899"
$ApiKey = "5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE"
$JwtSecret = "ZyPzGzKoyt7Mh2eVUEUWztwYvrlUV7uRs4gPYDVMGO7D4FKrdgEgQcxvY5TqeuEQHVFX15O8wdTj0QVz861neg"

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Secure Process API - curl Test Suite" -ForegroundColor Blue
Write-Host "========================================`n" -ForegroundColor Blue

# Generate JWT token
Write-Host "[SETUP] Generating JWT token..." -ForegroundColor Yellow
$JwtToken = python -c "import jwt, time; print(jwt.encode({'sub': 'testuser', 'exp': int(time.time()) + 3600}, '$JwtSecret', algorithm='HS256'))"
Write-Host "✓ JWT Token: $($JwtToken.Substring(0, [Math]::Min(50, $JwtToken.Length)))...`n" -ForegroundColor Green

# Helper function to run tests
function Run-Test {
    param(
        [string]$TestName,
        [string]$ExpectedStatus,
        [string]$Method,
        [string]$Url,
        [hashtable]$Headers = @{},
        [string]$Body = $null
    )

    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host "[TEST] $TestName" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue

    try
    {
        # Build curl command
        $curlArgs = @("-s", "-w", "`n%{http_code}", "-X", $Method)

        foreach ($key in $Headers.Keys)
        {
            $curlArgs += "-H"
            $curlArgs += "$key`: $($Headers[$key])"
        }

        if ($Body)
        {
            $curlArgs += "-d"
            $curlArgs += $Body
        }

        $curlArgs += $Url

        # Execute curl
        $response = & curl $curlArgs

        # Parse response
        $httpCode = $response[-1]
        $responseBody = $response[0..($response.Count - 2)] -join "`n"

        # Pretty print JSON
        try
        {
            $jsonObj = $responseBody | ConvertFrom-Json
            $responseBody | ConvertFrom-Json | ConvertTo-Json -Depth 10
        }
        catch
        {
            Write-Host $responseBody
        }

        # Check status code
        if ($httpCode -eq $ExpectedStatus)
        {
            Write-Host "`n✓ Status: $httpCode (Expected: $ExpectedStatus)`n" -ForegroundColor Green
        }
        else
        {
            Write-Host "`n✗ Status: $httpCode (Expected: $ExpectedStatus)`n" -ForegroundColor Red
        }
    }
    catch
    {
        Write-Host "Error running test: $_" -ForegroundColor Red
    }
}

# Test 1: Health Check
Run-Test -TestName "Health Check (No Auth)" -ExpectedStatus "200" `
    -Method "GET" `
    -Url "$BaseUrl/health"

# Test 2: Successful Request - Summarize (Query Param Auth)
Run-Test -TestName "Process - Summarize (Query Param API Key)" -ExpectedStatus "200" `
    -Method "POST" `
    -Url "$BaseUrl/process?api_key=$ApiKey" `
    -Headers @{
        "Authorization" = "Bearer $JwtToken"
        "Content-Type" = "application/json"
    } `
    -Body '{"dataset_id":"sales_2025_q3","action":"summarize","payload":{"rows":[1,2,3,4,5]}}'

# Test 3: Successful Request - Count (Header Auth)
Run-Test -TestName "Process - Count (Header API Key)" -ExpectedStatus "200" `
    -Method "POST" `
    -Url "$BaseUrl/process" `
    -Headers @{
        "X-API-Key" = $ApiKey
        "Authorization" = "Bearer $JwtToken"
        "Content-Type" = "application/json"
    } `
    -Body '{"dataset_id":"inventory_2025","action":"count","payload":{"items":["A","B","C","D","E","F"]}}'

# Test 4: Validate Action
Run-Test -TestName "Process - Validate Action" -ExpectedStatus "200" `
    -Method "POST" `
    -Url "$BaseUrl/process?api_key=$ApiKey" `
    -Headers @{
        "Authorization" = "Bearer $JwtToken"
        "Content-Type" = "application/json"
    } `
    -Body '{"dataset_id":"user_data_2025","action":"validate","payload":{"schema_version":"v2.1","record_count":1000}}'

# Test 5: Custom Action
Run-Test -TestName "Process - Custom Action (Archive)" -ExpectedStatus "200" `
    -Method "POST" `
    -Url "$BaseUrl/process?api_key=$ApiKey" `
    -Headers @{
        "Authorization" = "Bearer $JwtToken"
        "Content-Type" = "application/json"
    } `
    -Body '{"dataset_id":"logs_2025","action":"archive","payload":{"start_date":"2025-01-01","end_date":"2025-03-31","compression":"gzip"}}'

# Test 6: Forced Failure
Run-Test -TestName "Process - Forced Failure (400 Error)" -ExpectedStatus "400" `
    -Method "POST" `
    -Url "$BaseUrl/process?api_key=$ApiKey" `
    -Headers @{
        "Authorization" = "Bearer $JwtToken"
        "Content-Type" = "application/json"
    } `
    -Body '{"dataset_id":"test_failure","action":"summarize","payload":{"force_fail":true}}'

# Test 7: Missing API Key
Run-Test -TestName "Error - Missing API Key (401)" -ExpectedStatus "401" `
    -Method "POST" `
    -Url "$BaseUrl/process" `
    -Headers @{
        "Authorization" = "Bearer $JwtToken"
        "Content-Type" = "application/json"
    } `
    -Body '{"dataset_id":"test","action":"summarize","payload":{}}'

# Test 8: Invalid API Key
Run-Test -TestName "Error - Invalid API Key (401)" -ExpectedStatus "401" `
    -Method "POST" `
    -Url "$BaseUrl/process?api_key=wrong-key-12345" `
    -Headers @{
        "Authorization" = "Bearer $JwtToken"
        "Content-Type" = "application/json"
    } `
    -Body '{"dataset_id":"test","action":"summarize","payload":{}}'

# Test 9: Missing JWT Token
Run-Test -TestName "Error - Missing JWT Token (401)" -ExpectedStatus "401" `
    -Method "POST" `
    -Url "$BaseUrl/process?api_key=$ApiKey" `
    -Headers @{
        "Content-Type" = "application/json"
    } `
    -Body '{"dataset_id":"test","action":"summarize","payload":{}}'

# Test 10: Invalid JWT Token
Run-Test -TestName "Error - Invalid JWT Token (401)" -ExpectedStatus "401" `
    -Method "POST" `
    -Url "$BaseUrl/process?api_key=$ApiKey" `
    -Headers @{
        "Authorization" = "Bearer invalid.jwt.token"
        "Content-Type" = "application/json"
    } `
    -Body '{"dataset_id":"test","action":"summarize","payload":{}}'

# Test 11: Expired JWT Token
Write-Host "[SETUP] Generating expired JWT token..." -ForegroundColor Yellow
$ExpiredJwt = python -c "import jwt, time; print(jwt.encode({'sub': 'testuser', 'exp': int(time.time()) - 3600}, '$JwtSecret', algorithm='HS256'))"

Run-Test -TestName "Error - Expired JWT Token (401)" -ExpectedStatus "401" `
    -Method "POST" `
    -Url "$BaseUrl/process?api_key=$ApiKey" `
    -Headers @{
        "Authorization" = "Bearer $ExpiredJwt"
        "Content-Type" = "application/json"
    } `
    -Body '{"dataset_id":"test","action":"summarize","payload":{}}'

# Summary
Write-Host "========================================" -ForegroundColor Blue
Write-Host "  All tests completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Blue
Write-Host "`nCheck logs:" -ForegroundColor Yellow
Write-Host "  - File: Get-Content logs/requests.log | ConvertFrom-Json"
Write-Host "  - Database: python scripts/init_db.py query`n"
