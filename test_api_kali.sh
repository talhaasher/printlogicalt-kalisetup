#!/bin/bash
# API Testing Script for Kali Linux
# Secure Process API - curl Test Suite
# Works on any Linux distribution including Kali

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="http://localhost:8899"
API_KEY="5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE"
JWT_SECRET="ZyPzGzKoyt7Mh2eVUEUWztwYvrlUV7uRs4gPYDVMGO7D4FKrdgEgQcxvY5TqeuEQHVFX15O8wdTj0QVz861neg"

# Banner
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ${CYAN}Secure Process API - Test Suite${BLUE}   ║${NC}"
echo -e "${BLUE}║  ${CYAN}Kali Linux Edition${BLUE}                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}\n"

# Check dependencies
echo -e "${YELLOW}[*] Checking dependencies...${NC}"
command -v curl >/dev/null 2>&1 || { echo -e "${RED}[!] curl is required but not installed. Install it with: sudo apt install curl${NC}"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo -e "${RED}[!] python3 is required but not installed. Install it with: sudo apt install python3${NC}"; exit 1; }
command -v jq >/dev/null 2>&1 || echo -e "${YELLOW}[!] jq not found (optional). Install for better JSON formatting: sudo apt install jq${NC}"
echo -e "${GREEN}[✓] All required dependencies found${NC}\n"

# Check if PyJWT is installed
echo -e "${YELLOW}[*] Checking Python dependencies...${NC}"
python3 -c "import jwt" 2>/dev/null || {
    echo -e "${YELLOW}[!] PyJWT not found. Installing...${NC}"
    pip3 install pyjwt 2>/dev/null || { echo -e "${RED}[!] Failed to install PyJWT. Install manually: pip3 install pyjwt${NC}"; exit 1; }
}
echo -e "${GREEN}[✓] PyJWT is installed${NC}\n"

# Generate JWT token
echo -e "${YELLOW}[*] Generating JWT token...${NC}"
JWT_TOKEN=$(python3 -c "import jwt, time; print(jwt.encode({'sub': 'kali-user', 'exp': int(time.time()) + 3600}, '$JWT_SECRET', algorithm='HS256'))")
echo -e "${GREEN}[✓] JWT Token: ${JWT_TOKEN:0:50}...${NC}\n"

# Helper function for pretty output
print_test() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[TEST $1] $2${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_result() {
    local http_code=$1
    local expected=$2
    if [ "$http_code" == "$expected" ]; then
        echo -e "${GREEN}[✓] Status: $http_code (Expected: $expected)${NC}\n"
    else
        echo -e "${RED}[✗] Status: $http_code (Expected: $expected)${NC}\n"
    fi
}

# Function to make requests and show results
make_request() {
    local response=$(curl -s -w "\n%{http_code}" "$@")
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    # Pretty print JSON if jq is available
    if command -v jq >/dev/null 2>&1; then
        echo "$body" | jq . 2>/dev/null || echo "$body"
    else
        echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
    fi

    echo "$http_code"
}

# Test 1: Health Check
print_test "1" "Health Check (No Authentication Required)"
http_code=$(make_request -X GET "$BASE_URL/health")
print_result "$http_code" "200"

# Test 2: Successful Request - Summarize (Query Param Auth)
print_test "2" "Process - Summarize (Query Param API Key)"
http_code=$(make_request \
    -X POST "$BASE_URL/process?api_key=$API_KEY" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"dataset_id":"sales_2025_q3","action":"summarize","payload":{"rows":[1,2,3,4,5]}}')
print_result "$http_code" "200"

# Test 3: Successful Request - Count (Header Auth)
print_test "3" "Process - Count (Header API Key)"
http_code=$(make_request \
    -X POST "$BASE_URL/process" \
    -H "X-API-Key: $API_KEY" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"dataset_id":"inventory_2025","action":"count","payload":{"items":["A","B","C","D","E","F"]}}')
print_result "$http_code" "200"

# Test 4: Validate Action
print_test "4" "Process - Validate Action"
http_code=$(make_request \
    -X POST "$BASE_URL/process?api_key=$API_KEY" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"dataset_id":"user_data_2025","action":"validate","payload":{"schema_version":"v2.1","record_count":1000}}')
print_result "$http_code" "200"

# Test 5: Custom Action
print_test "5" "Process - Custom Action (Archive)"
http_code=$(make_request \
    -X POST "$BASE_URL/process?api_key=$API_KEY" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"dataset_id":"logs_2025","action":"archive","payload":{"start_date":"2025-01-01","end_date":"2025-03-31","compression":"gzip"}}')
print_result "$http_code" "200"

# Test 6: Forced Failure
print_test "6" "Process - Forced Failure (Expected 400 Error)"
http_code=$(make_request \
    -X POST "$BASE_URL/process?api_key=$API_KEY" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"dataset_id":"test_failure","action":"summarize","payload":{"force_fail":true}}')
print_result "$http_code" "400"

# Test 7: Missing API Key
print_test "7" "Error Test - Missing API Key (Expected 401)"
http_code=$(make_request \
    -X POST "$BASE_URL/process" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"dataset_id":"test","action":"summarize","payload":{}}')
print_result "$http_code" "401"

# Test 8: Invalid API Key
print_test "8" "Error Test - Invalid API Key (Expected 401)"
http_code=$(make_request \
    -X POST "$BASE_URL/process?api_key=wrong-key-12345" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"dataset_id":"test","action":"summarize","payload":{}}')
print_result "$http_code" "401"

# Test 9: Missing JWT Token
print_test "9" "Error Test - Missing JWT Token (Expected 401)"
http_code=$(make_request \
    -X POST "$BASE_URL/process?api_key=$API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"dataset_id":"test","action":"summarize","payload":{}}')
print_result "$http_code" "401"

# Test 10: Invalid JWT Token
print_test "10" "Error Test - Invalid JWT Token (Expected 401)"
http_code=$(make_request \
    -X POST "$BASE_URL/process?api_key=$API_KEY" \
    -H "Authorization: Bearer invalid.jwt.token" \
    -H "Content-Type: application/json" \
    -d '{"dataset_id":"test","action":"summarize","payload":{}}')
print_result "$http_code" "401"

# Test 11: Expired JWT Token
print_test "11" "Error Test - Expired JWT Token (Expected 401)"
echo -e "${YELLOW}[*] Generating expired JWT token...${NC}"
EXPIRED_JWT=$(python3 -c "import jwt, time; print(jwt.encode({'sub': 'kali-user', 'exp': int(time.time()) - 3600}, '$JWT_SECRET', algorithm='HS256'))")
http_code=$(make_request \
    -X POST "$BASE_URL/process?api_key=$API_KEY" \
    -H "Authorization: Bearer $EXPIRED_JWT" \
    -H "Content-Type: application/json" \
    -d '{"dataset_id":"test","action":"summarize","payload":{}}')
print_result "$http_code" "401"

# Summary
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ${GREEN}All Tests Completed Successfully!${BLUE}   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}[*] Log Verification:${NC}"
echo -e "${YELLOW}View log file:${NC}"
echo -e "    cat logs/requests.log | jq ."
echo -e "    ${MAGENTA}# or without jq:${NC}"
echo -e "    cat logs/requests.log | python3 -m json.tool\n"

echo -e "${YELLOW}Query database:${NC}"
echo -e "    python3 scripts/init_db.py query\n"

echo -e "${YELLOW}Filter logs by status:${NC}"
echo -e "    cat logs/requests.log | jq 'select(.status==\"failure\")'\n"

echo -e "${YELLOW}Get success rate:${NC}"
echo -e "    sqlite3 logs/logs.db \"SELECT status, COUNT(*) as count FROM requests GROUP BY status\"\n"

echo -e "${GREEN}[✓] Testing complete!${NC}"
