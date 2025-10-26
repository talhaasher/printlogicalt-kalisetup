# Simple PowerShell test script for Secure Process API
# Uses curl.exe (the actual curl binary, not PowerShell's Invoke-WebRequest)

# Configuration
$BaseUrl = "http://localhost:8899"
$ApiKey = "5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE"
$JwtSecret = "ZyPzGzKoyt7Mh2eVUEUWztwYvrlUV7uRs4gPYDVMGO7D4FKrdgEgQcxvY5TqeuEQHVFX15O8wdTj0QVz861neg"

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Secure Process API - Test Suite" -ForegroundColor Blue
Write-Host "========================================`n" -ForegroundColor Blue

# Generate JWT token
Write-Host "[SETUP] Generating JWT token..." -ForegroundColor Yellow
$JwtToken = python -c "import jwt, time; print(jwt.encode({'sub': 'testuser', 'exp': int(time.time()) + 3600}, '$JwtSecret', algorithm='HS256'))"
Write-Host "✓ JWT Token generated`n" -ForegroundColor Green

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host "[TEST 1] Health Check (No Auth)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
curl.exe -X GET "$BaseUrl/health"
Write-Host "`n"

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host "[TEST 2] Process - Summarize (Query Param API Key)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
curl.exe -X POST "$BaseUrl/process?api_key=$ApiKey" `
  -H "Authorization: Bearer $JwtToken" `
  -H "Content-Type: application/json" `
  -d '{\"dataset_id\":\"sales_2025_q3\",\"action\":\"summarize\",\"payload\":{\"rows\":[1,2,3,4,5]}}'
Write-Host "`n"

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host "[TEST 3] Process - Count (Header API Key)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
curl.exe -X POST "$BaseUrl/process" `
  -H "X-API-Key: $ApiKey" `
  -H "Authorization: Bearer $JwtToken" `
  -H "Content-Type: application/json" `
  -d '{\"dataset_id\":\"inventory_2025\",\"action\":\"count\",\"payload\":{\"items\":[\"A\",\"B\",\"C\",\"D\",\"E\",\"F\"]}}'
Write-Host "`n"

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host "[TEST 4] Process - Validate Action" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
curl.exe -X POST "$BaseUrl/process?api_key=$ApiKey" `
  -H "Authorization: Bearer $JwtToken" `
  -H "Content-Type: application/json" `
  -d '{\"dataset_id\":\"user_data_2025\",\"action\":\"validate\",\"payload\":{\"schema_version\":\"v2.1\",\"record_count\":1000}}'
Write-Host "`n"

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host "[TEST 5] Process - Custom Action (Archive)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
curl.exe -X POST "$BaseUrl/process?api_key=$ApiKey" `
  -H "Authorization: Bearer $JwtToken" `
  -H "Content-Type: application/json" `
  -d '{\"dataset_id\":\"logs_2025\",\"action\":\"archive\",\"payload\":{\"start_date\":\"2025-01-01\",\"end_date\":\"2025-03-31\",\"compression\":\"gzip\"}}'
Write-Host "`n"

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host "[TEST 6] Process - Forced Failure (400 Error)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
curl.exe -X POST "$BaseUrl/process?api_key=$ApiKey" `
  -H "Authorization: Bearer $JwtToken" `
  -H "Content-Type: application/json" `
  -d '{\"dataset_id\":\"test_failure\",\"action\":\"summarize\",\"payload\":{\"force_fail\":true}}'
Write-Host "`n"

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host "[TEST 7] Error - Missing API Key (401)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
curl.exe -X POST "$BaseUrl/process" `
  -H "Authorization: Bearer $JwtToken" `
  -H "Content-Type: application/json" `
  -d '{\"dataset_id\":\"test\",\"action\":\"summarize\",\"payload\":{}}'
Write-Host "`n"

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host "[TEST 8] Error - Invalid API Key (401)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
curl.exe -X POST "$BaseUrl/process?api_key=wrong-key-12345" `
  -H "Authorization: Bearer $JwtToken" `
  -H "Content-Type: application/json" `
  -d '{\"dataset_id\":\"test\",\"action\":\"summarize\",\"payload\":{}}'
Write-Host "`n"

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host "[TEST 9] Error - Missing JWT Token (401)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
curl.exe -X POST "$BaseUrl/process?api_key=$ApiKey" `
  -H "Content-Type: application/json" `
  -d '{\"dataset_id\":\"test\",\"action\":\"summarize\",\"payload\":{}}'
Write-Host "`n"

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host "[TEST 10] Error - Invalid JWT Token (401)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
curl.exe -X POST "$BaseUrl/process?api_key=$ApiKey" `
  -H "Authorization: Bearer invalid.jwt.token" `
  -H "Content-Type: application/json" `
  -d '{\"dataset_id\":\"test\",\"action\":\"summarize\",\"payload\":{}}'
Write-Host "`n"

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host "[TEST 11] Error - Expired JWT Token (401)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host "[SETUP] Generating expired JWT token..." -ForegroundColor Yellow
$ExpiredJwt = python -c "import jwt, time; print(jwt.encode({'sub': 'testuser', 'exp': int(time.time()) - 3600}, '$JwtSecret', algorithm='HS256'))"
curl.exe -X POST "$BaseUrl/process?api_key=$ApiKey" `
  -H "Authorization: Bearer $ExpiredJwt" `
  -H "Content-Type: application/json" `
  -d '{\"dataset_id\":\"test\",\"action\":\"summarize\",\"payload\":{}}'
Write-Host "`n"

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  All tests completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Blue
Write-Host "`nCheck logs:" -ForegroundColor Yellow
Write-Host "  - File: Get-Content logs/requests.log | ConvertFrom-Json"
Write-Host "  - Database: python scripts/init_db.py query`n"
