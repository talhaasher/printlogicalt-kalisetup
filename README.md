# Secure Process API

A production-ready FastAPI endpoint with dual authentication (API Key + JWT) and durable JSON logging to both file and SQLite database.

## Features

- **Dual Authentication**: API Key (query param or header) + JWT Bearer token
- **Durable Logging**: Newline-delimited JSON file + SQLite database
- **Async/Await**: High-performance async endpoints
- **Type Safety**: Full Pydantic models and type hints
- **Observability**: Request IDs, timing, structured logs
- **Security**: No hardcoded secrets, environment-based config

## Quick Start

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Set Environment Variables

**IMPORTANT**: Do NOT commit `.env` files with real secrets to version control!

```bash
# Linux/Mac
export API_KEY="my-secret-api-key-12345"
export JWT_SECRET="my-jwt-signing-secret-67890"

# Windows (PowerShell)
$env:API_KEY="my-secret-api-key-12345"
$env:JWT_SECRET="my-jwt-signing-secret-67890"

# Windows (CMD)
set API_KEY=my-secret-api-key-12345
set JWT_SECRET=my-jwt-signing-secret-67890
```

Or create a `.env` file (see `.env.example`) and use `python-dotenv` or similar.

### 3. Initialize Database (Optional)

The server auto-creates the database on startup, but you can pre-initialize:

```bash
python scripts/init_db.py
```

### 4. Run the Server

```bash
python main.py
```

Or use uvicorn directly:

```bash
uvicorn main:app --host 0.0.0.0 --port 8899
```

Server will be available at: **http://localhost:8899**

API Documentation (auto-generated): **http://localhost:8899/docs**

## Authentication

### API Key

Provide your API key in **one** of these ways:

1. **Query parameter**: `?api_key=YOUR_API_KEY`
2. **Header**: `X-API-Key: YOUR_API_KEY`

### JWT Token

Must provide a valid JWT in the `Authorization` header:

```
Authorization: Bearer <YOUR_JWT_TOKEN>
```

**JWT Requirements**:
- Algorithm: HS256
- Secret: value of `JWT_SECRET` environment variable
- Must not be expired (`exp` claim checked)

### Generate a Test JWT

```bash
# Using Python
python -c "import jwt, os, time; print(jwt.encode({'sub': 'user1', 'exp': int(time.time()) + 3600}, os.environ['JWT_SECRET'], algorithm='HS256'))"
```

Or use [jwt.io](https://jwt.io/) with your secret.

## API Endpoints

### POST /process

Main processing endpoint.

**Request Body**:
```json
{
  "dataset_id": "sales_2025_q3",
  "action": "summarize",
  "payload": {
    "rows": [1, 2, 3]
  }
}
```

**Response (Success)**:
```json
{
  "request_id": "a3f1e2b8-4a2f-4d6a-9c2a-1b2c3d4e5f60",
  "status": "success",
  "data": {
    "summary": "3 records processed",
    "rows_processed": 3,
    "dataset": "sales_2025_q3"
  }
}
```

**Supported Actions**:
- `summarize`: Returns summary of rows
- `count`: Returns count of items
- `validate`: Simulates validation checks
- Any other action: Returns generic success message

**Special Payload Keys**:
- `"force_fail": true` - Forces a 400 error for testing

### GET /health

Simple health check (no authentication required).

```bash
curl http://localhost:8899/health
```

## Test Commands

### 1. Generate JWT Token

```bash
# Save token to variable (Linux/Mac)
export JWT_TOKEN=$(python -c "import jwt, os, time; print(jwt.encode({'sub': 'testuser', 'exp': int(time.time()) + 3600}, os.environ['JWT_SECRET'], algorithm='HS256'))")

# Windows PowerShell
$JWT_TOKEN = python -c "import jwt, os, time; print(jwt.encode({'sub': 'testuser', 'exp': int(time.time()) + 3600}, os.environ['JWT_SECRET'], algorithm='HS256'))"
```

### 2. Successful Request (Query Param API Key)

```bash
curl -X POST "http://localhost:8899/process?api_key=my-secret-api-key-12345" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "dataset_id": "sales_2025_q3",
    "action": "summarize",
    "payload": {"rows": [1, 2, 3]}
  }'
```

**Expected Response**:
```json
{
  "request_id": "...",
  "status": "success",
  "data": {
    "summary": "3 records processed",
    "rows_processed": 3,
    "dataset": "sales_2025_q3"
  }
}
```

### 3. Successful Request (Header API Key)

```bash
curl -X POST "http://localhost:8899/process" \
  -H "X-API-Key: my-secret-api-key-12345" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "dataset_id": "inventory_2025",
    "action": "count",
    "payload": {"items": ["A", "B", "C", "D"]}
  }'
```

### 4. Forced Failure Request

```bash
curl -X POST "http://localhost:8899/process?api_key=my-secret-api-key-12345" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "dataset_id": "sales_2025_q3",
    "action": "summarize",
    "payload": {"force_fail": true}
  }'
```

**Expected Response** (HTTP 400):
```json
{
  "detail": "forced failure requested: payload.force_fail=true"
}
```

### 5. Missing API Key (Should Fail)

```bash
curl -X POST "http://localhost:8899/process" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dataset_id": "test", "action": "summarize", "payload": {}}'
```

**Expected Response** (HTTP 401):
```json
{
  "detail": "API key required (query param 'api_key' or header 'X-API-Key')"
}
```

### 6. Invalid JWT (Should Fail)

```bash
curl -X POST "http://localhost:8899/process?api_key=my-secret-api-key-12345" \
  -H "Authorization: Bearer invalid.jwt.token" \
  -H "Content-Type: application/json" \
  -d '{"dataset_id": "test", "action": "summarize", "payload": {}}'
```

**Expected Response** (HTTP 401):
```json
{
  "detail": "Invalid JWT token: ..."
}
```

## Log Examples

### Success Log Entry

```json
{
  "timestamp": "2025-10-26T12:34:56.789123+00:00",
  "request_id": "a3f1e2b8-4a2f-4d6a-9c2a-1b2c3d4e5f60",
  "dataset_id": "sales_2025_q3",
  "action": "summarize",
  "status": "success",
  "duration_ms": 42,
  "output": {
    "summary": "3 records processed",
    "rows_processed": 3,
    "dataset": "sales_2025_q3"
  },
  "http_status": 200,
  "client": "127.0.0.1"
}
```

### Failure Log Entry

```json
{
  "timestamp": "2025-10-26T12:35:01.123456+00:00",
  "request_id": "d7e8f1a2-9b3c-4e1f-8d6a-2b3c4d5e6f70",
  "dataset_id": "sales_2025_q3",
  "action": "summarize",
  "status": "failure",
  "duration_ms": 15,
  "output": "forced failure requested: payload.force_fail=true",
  "http_status": 400,
  "client": "127.0.0.1"
}
```

## Querying Logs

### File Logs

```bash
# View all logs (newline-delimited JSON)
cat logs/requests.log

# Pretty-print logs
cat logs/requests.log | jq .

# Filter by status
cat logs/requests.log | jq 'select(.status == "failure")'

# Show only request_id and duration
cat logs/requests.log | jq '{request_id, duration_ms}'
```

### Database Logs

```bash
# Using the provided script
python scripts/init_db.py query

# Using SQLite CLI
sqlite3 logs/logs.db "SELECT * FROM requests ORDER BY timestamp DESC LIMIT 10"

# Get failure count
sqlite3 logs/logs.db "SELECT COUNT(*) FROM requests WHERE status='failure'"

# Average duration by action
sqlite3 logs/logs.db "SELECT action, AVG(duration_ms) FROM requests GROUP BY action"
```

## Project Structure

```
.
├── main.py                 # FastAPI application
├── requirements.txt        # Python dependencies
├── README.md              # This file
├── .env.example           # Environment variable template
├── scripts/
│   └── init_db.py         # Database initialization script
└── logs/                  # Created on first run
    ├── requests.log       # Newline-delimited JSON logs
    └── logs.db            # SQLite database
```

## Security Notes

1. **Never commit secrets**: Add `.env` to `.gitignore`
2. **Rotate credentials regularly**: Change `API_KEY` and `JWT_SECRET` periodically
3. **Use strong secrets**: Generate random strings (min 32 characters)
4. **HTTPS in production**: Always use TLS/SSL in production deployments
5. **Rate limiting**: Consider adding rate limiting for production use
6. **IP allowlisting**: Restrict access by IP if possible

### Generate Strong Secrets

```bash
# API Key
python -c "import secrets; print(secrets.token_urlsafe(32))"

# JWT Secret
python -c "import secrets; print(secrets.token_urlsafe(64))"
```

## Production Deployment

### Using systemd (Linux)

Create `/etc/systemd/system/process-api.service`:

```ini
[Unit]
Description=Secure Process API
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/process-api
Environment="API_KEY=your-key-here"
Environment="JWT_SECRET=your-secret-here"
ExecStart=/usr/bin/python3 main.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable process-api
sudo systemctl start process-api
```

### Using Docker

Create `Dockerfile`:

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8899
CMD ["python", "main.py"]
```

Run:

```bash
docker build -t process-api .
docker run -p 8899:8899 \
  -e API_KEY="your-key" \
  -e JWT_SECRET="your-secret" \
  process-api
```

## Troubleshooting

**Server won't start**: Check that `API_KEY` and `JWT_SECRET` environment variables are set.

**401 errors**: Verify your API key and JWT token are correct and not expired.

**Database locked**: If using SQLite with high concurrency, consider PostgreSQL for production.

**Logs not appearing**: Check file permissions in `logs/` directory.

## License

This project is for educational and authorized security testing purposes only.
