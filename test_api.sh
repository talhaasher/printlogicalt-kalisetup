#!/bin/bash
# Bash script for testing Secure Process API with curl
# Works on Linux/Mac/Git Bash on Windows

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="http://localhost:8899"
API_KEY="5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE"
JWT_SECRET="ZyPzGzKoyt7Mh2eVUEUWztwYvrlUV7uRs4gPYDVMGO7D4FKrdgEgQcxvY5TqeuEQHVFX15O8wdTj0QVz861neg"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Secure Process API - curl Test Suite${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Generate JWT token
echo -e "${YELLOW}[SETUP] Generating JWT token...${NC}"
JWT_TOKEN=$(python -c "import jwt, time; print(jwt.encode({'sub': 'testuser', 'exp': int(time.time()) + 3600}, '$JWT_SECRET', algorithm='HS256'))")
echo -e "${GREEN}✓ JWT Token: ${JWT_TOKEN:0:50}...${NC}\n"

# Helper function to run tests
run_test() {
    local test_name="$1"
    local expected_status="$2"
    shift 2

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}[TEST] $test_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Run curl and capture response
    response=$(curl -s -w "\n%{http_code}" "$@")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    # Pretty print JSON
    echo "$body" | python -m json.tool 2>/dev/null || echo "$body"

    # Check status code
    if [ "$http_code" == "$expected_status" ]; then
        echo -e "\n${GREEN}✓ Status: $http_code (Expected: $expected_status)${NC}\n"
    else
        echo -e "\n${RED}✗ Status: $http_code (Expected: $expected_status)${NC}\n"
    fi
}

# Test 1: Health Check
run_test "Health Check (No Auth)" "200" \
    -X GET "$BASE_URL/health"

# Test 2: Successful Request - Summarize (Query Param Auth)
run_test "Process - Summarize (Query Param API Key)" "200" \
    -X POST "$BASE_URL/process?api_key=$API_KEY" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "dataset_id": "sales_2025_q3",
        "action": "summarize",
        "payload": {
            "rows": [1, 2, 3, 4, 5]
        }
    }'

# Test 3: Successful Request - Count (Header Auth)
run_test "Process - Count (Header API Key)" "200" \
    -X POST "$BASE_URL/process" \
    -H "X-API-Key: $API_KEY" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "dataset_id": "inventory_2025",
        "action": "count",
        "payload": {
            "items": ["A", "B", "C", "D", "E", "F"]
        }
    }'

# Test 4: Validate Action
run_test "Process - Validate Action" "200" \
    -X POST "$BASE_URL/process?api_key=$API_KEY" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "dataset_id": "user_data_2025",
        "action": "validate",
        "payload": {
            "schema_version": "v2.1",
            "record_count": 1000
        }
    }'

# Test 5: Custom Action
run_test "Process - Custom Action (Archive)" "200" \
    -X POST "$BASE_URL/process?api_key=$API_KEY" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "dataset_id": "logs_2025",
        "action": "archive",
        "payload": {
            "start_date": "2025-01-01",
            "end_date": "2025-03-31",
            "compression": "gzip"
        }
    }'

# Test 6: Forced Failure
run_test "Process - Forced Failure (400 Error)" "400" \
    -X POST "$BASE_URL/process?api_key=$API_KEY" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "dataset_id": "test_failure",
        "action": "summarize",
        "payload": {
            "force_fail": true
        }
    }'

# Test 7: Missing API Key
run_test "Error - Missing API Key (401)" "401" \
    -X POST "$BASE_URL/process" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "dataset_id": "test",
        "action": "summarize",
        "payload": {}
    }'

# Test 8: Invalid API Key
run_test "Error - Invalid API Key (401)" "401" \
    -X POST "$BASE_URL/process?api_key=wrong-key-12345" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "dataset_id": "test",
        "action": "summarize",
        "payload": {}
    }'

# Test 9: Missing JWT Token
run_test "Error - Missing JWT Token (401)" "401" \
    -X POST "$BASE_URL/process?api_key=$API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
        "dataset_id": "test",
        "action": "summarize",
        "payload": {}
    }'

# Test 10: Invalid JWT Token
run_test "Error - Invalid JWT Token (401)" "401" \
    -X POST "$BASE_URL/process?api_key=$API_KEY" \
    -H "Authorization: Bearer invalid.jwt.token" \
    -H "Content-Type: application/json" \
    -d '{
        "dataset_id": "test",
        "action": "summarize",
        "payload": {}
    }'

# Test 11: Expired JWT Token
echo -e "${YELLOW}[SETUP] Generating expired JWT token...${NC}"
EXPIRED_JWT=$(python -c "import jwt, time; print(jwt.encode({'sub': 'testuser', 'exp': int(time.time()) - 3600}, '$JWT_SECRET', algorithm='HS256'))")

run_test "Error - Expired JWT Token (401)" "401" \
    -X POST "$BASE_URL/process?api_key=$API_KEY" \
    -H "Authorization: Bearer $EXPIRED_JWT" \
    -H "Content-Type: application/json" \
    -d '{
        "dataset_id": "test",
        "action": "summarize",
        "payload": {}
    }'

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  All tests completed!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "\n${YELLOW}Check logs:${NC}"
echo -e "  - File: cat logs/requests.log | jq ."
echo -e "  - Database: python scripts/init_db.py query\n"
