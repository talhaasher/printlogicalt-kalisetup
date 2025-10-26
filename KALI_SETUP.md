# Kali Linux Setup Guide

Complete setup and testing guide for running the Secure Process API on Kali Linux.

## Quick Setup

### 1. Install Dependencies

```bash
# Update package lists
sudo apt update

# Install Python 3 and pip (usually pre-installed on Kali)
sudo apt install python3 python3-pip -y

# Install curl (usually pre-installed)
sudo apt install curl -y

# Install jq for JSON formatting (optional but recommended)
sudo apt install jq -y

# Install SQLite (usually pre-installed)
sudo apt install sqlite3 -y
```

### 2. Install Python Packages

```bash
# Install required Python packages
pip3 install -r requirements.txt

# Or install individually:
pip3 install fastapi uvicorn pyjwt python-multipart pydantic aiosqlite python-dotenv
```

### 3. Setup Environment

```bash
# Copy this project to your Kali machine
# If you're testing locally on Kali, you're already set!

# Make scripts executable
chmod +x test_api_kali.sh
chmod +x test_api.sh
chmod +x test_api_simple.sh
chmod +x scripts/init_db.py
```

### 4. Start the Server

```bash
# The .env file is already configured with your secrets
python3 main.py
```

You should see:
```
[CONFIG] Loading environment from: /path/to/.env
============================================================
Starting Secure Process API on port 8899
============================================================
API Key: 5gWwsAC7v... (truncated)
JWT Secret: ********** (hidden)
============================================================
INFO:     Started server process [12345]
INFO:     Waiting for application startup.
[STARTUP] Initializing database at logs/logs.db
[STARTUP] Server ready on port 8899
[STARTUP] API Key authentication enabled
[STARTUP] JWT authentication enabled (HS256)
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8899 (Press CTRL+C to quit)
```

### 5. Run Tests (In Another Terminal)

```bash
# Run the full Kali-optimized test suite
./test_api_kali.sh
```

## Testing from Kali to Remote Server

If your API is running on Windows and you want to test from Kali:

### 1. Update the BASE_URL in the script

Edit `test_api_kali.sh`:

```bash
# Change this line:
BASE_URL="http://localhost:8899"

# To your Windows machine IP:
BASE_URL="http://192.168.1.100:8899"  # Replace with actual IP
```

### 2. Ensure Windows Firewall Allows Port 8899

On Windows PowerShell (as Administrator):

```powershell
# Allow inbound traffic on port 8899
New-NetFirewallRule -DisplayName "Process API" -Direction Inbound -Protocol TCP -LocalPort 8899 -Action Allow
```

### 3. Run Tests from Kali

```bash
./test_api_kali.sh
```

## Individual Test Commands (Kali)

```bash
# Generate JWT token
JWT_TOKEN=$(python3 -c "import jwt, time; print(jwt.encode({'sub': 'kali-user', 'exp': int(time.time()) + 3600}, 'ZyPzGzKoyt7Mh2eVUEUWztwYvrlUV7uRs4gPYDVMGO7D4FKrdgEgQcxvY5TqeuEQHVFX15O8wdTj0QVz861neg', algorithm='HS256'))")

# Health check
curl -X GET "http://localhost:8899/health"

# Successful request
curl -X POST "http://localhost:8899/process?api_key=5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dataset_id":"sales_2025_q3","action":"summarize","payload":{"rows":[1,2,3,4,5]}}'

# Test failure
curl -X POST "http://localhost:8899/process?api_key=5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dataset_id":"test_failure","action":"summarize","payload":{"force_fail":true}}'
```

## Analyzing Logs on Kali

### View All Logs (Pretty Print)

```bash
cat logs/requests.log | jq .
```

### Filter by Status

```bash
# Show only failures
cat logs/requests.log | jq 'select(.status=="failure")'

# Show only successes
cat logs/requests.log | jq 'select(.status=="success")'
```

### Filter by Dataset

```bash
cat logs/requests.log | jq 'select(.dataset_id=="sales_2025_q3")'
```

### Show Request IDs and Duration

```bash
cat logs/requests.log | jq '{request_id, duration_ms, status}'
```

### Calculate Average Duration

```bash
cat logs/requests.log | jq -s 'map(.duration_ms) | add / length'
```

## Database Queries on Kali

### View Recent Requests

```bash
python3 scripts/init_db.py query
```

### Custom SQL Queries

```bash
# Success rate
sqlite3 logs/logs.db "SELECT status, COUNT(*) as count FROM requests GROUP BY status"

# Average duration by action
sqlite3 logs/logs.db "SELECT action, AVG(duration_ms) as avg_duration FROM requests GROUP BY action"

# Recent failures
sqlite3 logs/logs.db "SELECT timestamp, dataset_id, output FROM requests WHERE status='failure' ORDER BY timestamp DESC LIMIT 5"

# Requests by client IP
sqlite3 logs/logs.db "SELECT client, COUNT(*) as count FROM requests GROUP BY client"
```

## Penetration Testing Notes

### Fuzzing the API

```bash
# Install wfuzz if not already available
sudo apt install wfuzz -y

# Fuzz dataset_id parameter
wfuzz -c -z file,/usr/share/wordlists/wfuzz/general/common.txt \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dataset_id":"FUZZ","action":"summarize","payload":{}}' \
  "http://localhost:8899/process?api_key=5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE"
```

### Brute Force API Key (Educational)

```bash
# Using hydra (demonstration only - this API key is for testing)
# Create a wordlist first
cat > api_keys.txt << EOF
wrong-key-1
wrong-key-2
5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE
wrong-key-3
EOF

# Note: Standard tools may not work directly - you'd need custom scripts
```

### Monitor with tcpdump

```bash
# Capture traffic on port 8899
sudo tcpdump -i any -n port 8899 -A

# Save to pcap file
sudo tcpdump -i any -n port 8899 -w api_traffic.pcap

# Analyze with Wireshark
wireshark api_traffic.pcap
```

### Use Burp Suite

1. Set Burp as proxy in your terminal:
```bash
export http_proxy=http://127.0.0.1:8080
export https_proxy=http://127.0.0.1:8080
```

2. Run curl commands - they'll go through Burp
3. Analyze/modify requests in Burp Suite Repeater

## Performance Testing

### Using Apache Bench (ab)

```bash
# Install if needed
sudo apt install apache2-utils -y

# 100 requests, 10 concurrent
ab -n 100 -c 10 \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -p test_payload.json \
  "http://localhost:8899/process?api_key=5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE"
```

Create `test_payload.json`:
```json
{"dataset_id":"perf_test","action":"summarize","payload":{"rows":[1,2,3]}}
```

### Using wrk (Advanced)

```bash
# Install wrk
sudo apt install wrk -y

# Run benchmark
wrk -t4 -c100 -d30s \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -s post.lua \
  "http://localhost:8899/process?api_key=5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE"
```

Create `post.lua`:
```lua
wrk.method = "POST"
wrk.body = '{"dataset_id":"wrk_test","action":"summarize","payload":{"rows":[1,2,3]}}'
wrk.headers["Content-Type"] = "application/json"
```

## Troubleshooting on Kali

### Port Already in Use

```bash
# Check what's using port 8899
sudo netstat -tulpn | grep 8899

# Kill the process
sudo kill -9 <PID>
```

### Permission Denied on Logs

```bash
# Fix permissions
chmod 755 logs/
chmod 644 logs/requests.log
chmod 644 logs/logs.db
```

### Python Module Not Found

```bash
# Install missing module
pip3 install <module-name>

# Or reinstall all requirements
pip3 install -r requirements.txt --force-reinstall
```

### Cannot Connect to Server

```bash
# Check if server is running
ps aux | grep python3

# Check if port is listening
sudo netstat -tulpn | grep 8899

# Test local connectivity
curl http://127.0.0.1:8899/health
```

## Security Considerations

⚠️ **For Educational/Testing Purposes Only**

- This setup is for authorized penetration testing and security research
- Always get written authorization before testing any system
- Use in isolated lab environments only
- Never deploy with these credentials in production
- Rotate all secrets before any production use

## Next Steps

1. ✅ Run the test suite: `./test_api_kali.sh`
2. ✅ Review logs: `cat logs/requests.log | jq .`
3. ✅ Query database: `python3 scripts/init_db.py query`
4. ✅ Try individual requests with different payloads
5. ✅ Experiment with invalid tokens and keys
6. ✅ Monitor with tcpdump or Wireshark
7. ✅ Performance test with ab or wrk

Happy testing! 🔒🐉
