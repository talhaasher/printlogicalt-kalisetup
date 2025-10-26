#!/bin/bash
# Simple curl commands - copy/paste individual commands

# Configuration
BASE_URL="http://localhost:8899"
API_KEY="5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE"
JWT_SECRET="ZyPzGzKoyt7Mh2eVUEUWztwYvrlUV7uRs4gPYDVMGO7D4FKrdgEgQcxvY5TqeuEQHVFX15O8wdTj0QVz861neg"

# Generate JWT token (run this first!)
JWT_TOKEN=$(python -c "import jwt, time; print(jwt.encode({'sub': 'testuser', 'exp': int(time.time()) + 3600}, '$JWT_SECRET', algorithm='HS256'))")
echo "JWT Token: $JWT_TOKEN"
echo ""

# ============================================================================
# COPY/PASTE INDIVIDUAL COMMANDS BELOW
# ============================================================================

# 1. Health Check (No Auth)
curl -X GET "http://localhost:8899/health"

# 2. Successful Request - Summarize (Query Param API Key)
curl -X POST "http://localhost:8899/process?api_key=5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dataset_id":"sales_2025_q3","action":"summarize","payload":{"rows":[1,2,3,4,5]}}'

# 3. Successful Request - Count (Header API Key)
curl -X POST "http://localhost:8899/process" \
  -H "X-API-Key: 5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dataset_id":"inventory_2025","action":"count","payload":{"items":["A","B","C","D","E","F"]}}'

# 4. Validate Action
curl -X POST "http://localhost:8899/process?api_key=5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dataset_id":"user_data_2025","action":"validate","payload":{"schema_version":"v2.1","record_count":1000}}'

# 5. Custom Action (Archive)
curl -X POST "http://localhost:8899/process?api_key=5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dataset_id":"logs_2025","action":"archive","payload":{"start_date":"2025-01-01","end_date":"2025-03-31","compression":"gzip"}}'

# 6. Forced Failure (400 Error)
curl -X POST "http://localhost:8899/process?api_key=5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dataset_id":"test_failure","action":"summarize","payload":{"force_fail":true}}'

# 7. Missing API Key (401 Error)
curl -X POST "http://localhost:8899/process" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dataset_id":"test","action":"summarize","payload":{}}'

# 8. Invalid API Key (401 Error)
curl -X POST "http://localhost:8899/process?api_key=wrong-key-12345" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dataset_id":"test","action":"summarize","payload":{}}'

# 9. Missing JWT Token (401 Error)
curl -X POST "http://localhost:8899/process?api_key=5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE" \
  -H "Content-Type: application/json" \
  -d '{"dataset_id":"test","action":"summarize","payload":{}}'

# 10. Invalid JWT Token (401 Error)
curl -X POST "http://localhost:8899/process?api_key=5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE" \
  -H "Authorization: Bearer invalid.jwt.token" \
  -H "Content-Type: application/json" \
  -d '{"dataset_id":"test","action":"summarize","payload":{}}'

# 11. Expired JWT Token (401 Error)
EXPIRED_JWT=$(python -c "import jwt, time; print(jwt.encode({'sub': 'testuser', 'exp': int(time.time()) - 3600}, '$JWT_SECRET', algorithm='HS256'))")
curl -X POST "http://localhost:8899/process?api_key=5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE" \
  -H "Authorization: Bearer $EXPIRED_JWT" \
  -H "Content-Type: application/json" \
  -d '{"dataset_id":"test","action":"summarize","payload":{}}'

# ============================================================================
# View Logs
# ============================================================================

# View log file (if jq is installed)
cat logs/requests.log | jq .

# View log file (without jq)
cat logs/requests.log

# Query database
python scripts/init_db.py query
