"""
FastAPI endpoint with API Key + JWT authentication and durable JSON logging.
Port: 8899
Author: Generated for security testing/educational purposes
"""

import os
import sys
import time
import uuid
import json
import sqlite3
from datetime import datetime, timezone
from typing import Optional, Dict, Any
from contextlib import asynccontextmanager
from pathlib import Path

import jwt
import aiosqlite
from fastapi import FastAPI, HTTPException, Header, Query, Request, status, Depends
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from dotenv import load_dotenv


# ============================================================================
# Load environment variables from .env file
# ============================================================================

# Look for .env file in current directory
env_path = Path(__file__).parent / '.env'
if env_path.exists():
    print(f"[CONFIG] Loading environment from: {env_path}")
    load_dotenv(dotenv_path=env_path)
else:
    print("[CONFIG] No .env file found, using system environment variables")


# ============================================================================
# Configuration - Read from environment variables
# ============================================================================

API_KEY = os.getenv("API_KEY")
JWT_SECRET = os.getenv("JWT_SECRET")

if not API_KEY or not JWT_SECRET:
    print("ERROR: Missing required environment variables API_KEY and/or JWT_SECRET")
    print("Please set them before starting the server:")
    print("  export API_KEY='your-api-key-here'")
    print("  export JWT_SECRET='your-jwt-secret-here'")
    sys.exit(1)

# Logging configuration
LOG_FILE = "logs/requests.log"
DB_FILE = "logs/logs.db"

# Ensure logs directory exists
os.makedirs("logs", exist_ok=True)


# ============================================================================
# Data Models
# ============================================================================

class ProcessRequest(BaseModel):
    """Request body for /process endpoint"""
    dataset_id: str = Field(..., description="Unique identifier for the dataset")
    action: str = Field(..., description="Action to perform: summarize, count, etc.")
    payload: Dict[str, Any] = Field(..., description="Action-specific data")


class APIResponse(BaseModel):
    """Standardized API response"""
    request_id: str
    status: str  # "success" or "failure"
    data: Optional[Dict[str, Any]] = None
    error: Optional[str] = None


# ============================================================================
# Database Setup
# ============================================================================

async def init_database():
    """Initialize SQLite database with requests table"""
    async with aiosqlite.connect(DB_FILE) as db:
        await db.execute("""
            CREATE TABLE IF NOT EXISTS requests (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                request_id TEXT UNIQUE NOT NULL,
                dataset_id TEXT NOT NULL,
                action TEXT NOT NULL,
                status TEXT NOT NULL,
                duration_ms INTEGER NOT NULL,
                output TEXT NOT NULL,
                http_status INTEGER NOT NULL,
                client TEXT
            )
        """)
        await db.execute("CREATE INDEX IF NOT EXISTS idx_request_id ON requests(request_id)")
        await db.execute("CREATE INDEX IF NOT EXISTS idx_timestamp ON requests(timestamp)")
        await db.commit()


# ============================================================================
# Lifecycle Management
# ============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup and shutdown logic"""
    # Startup
    print(f"[STARTUP] Initializing database at {DB_FILE}")
    await init_database()
    print(f"[STARTUP] Server ready on port 8899")
    print(f"[STARTUP] API Key authentication enabled")
    print(f"[STARTUP] JWT authentication enabled (HS256)")
    yield
    # Shutdown
    print("[SHUTDOWN] Server shutting down")


app = FastAPI(
    title="Secure Process API",
    description="API endpoint with API Key + JWT auth and durable logging",
    version="1.0.0",
    lifespan=lifespan
)


# ============================================================================
# Authentication Helpers
# ============================================================================

def validate_api_key(
    api_key_query: Optional[str] = Query(None, alias="api_key"),
    x_api_key_header: Optional[str] = Header(None, alias="X-API-Key")
) -> bool:
    """
    Validate API key from either query parameter or header.
    Supports both ?api_key=XXX and X-API-Key: XXX
    """
    provided_key = api_key_query or x_api_key_header

    if not provided_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="API key required (query param 'api_key' or header 'X-API-Key')"
        )

    if provided_key != API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key"
        )

    return True


def validate_jwt(authorization: Optional[str] = Header(None)) -> Dict[str, Any]:
    """
    Validate JWT from Authorization: Bearer <token> header.
    Returns decoded JWT payload if valid.
    """
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header required"
        )

    # Extract Bearer token
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header format. Use: Bearer <token>"
        )

    token = parts[1]

    try:
        # Decode and validate JWT
        payload = jwt.decode(
            token,
            JWT_SECRET,
            algorithms=["HS256"]
        )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="JWT token has expired"
        )
    except jwt.InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid JWT token: {str(e)}"
        )


# ============================================================================
# Logging Functions
# ============================================================================

async def log_request(
    request_id: str,
    dataset_id: str,
    action: str,
    status_str: str,
    duration_ms: int,
    output: Any,
    http_status: int,
    client: Optional[str] = None
):
    """
    Durably persist log entry to both file and SQLite database.
    Each log is a JSON object with standardized fields.
    """
    timestamp = datetime.now(timezone.utc).isoformat()

    log_entry = {
        "timestamp": timestamp,
        "request_id": request_id,
        "dataset_id": dataset_id,
        "action": action,
        "status": status_str,
        "duration_ms": duration_ms,
        "output": output,
        "http_status": http_status,
        "client": client
    }

    # Write to file (newline-delimited JSON)
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(json.dumps(log_entry) + "\n")
            f.flush()
            os.fsync(f.fileno())  # Ensure durability
    except Exception as e:
        print(f"[ERROR] Failed to write to log file: {e}")

    # Write to SQLite
    try:
        async with aiosqlite.connect(DB_FILE) as db:
            await db.execute("""
                INSERT INTO requests (
                    timestamp, request_id, dataset_id, action, status,
                    duration_ms, output, http_status, client
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                timestamp,
                request_id,
                dataset_id,
                action,
                status_str,
                duration_ms,
                json.dumps(output),
                http_status,
                client
            ))
            await db.commit()
    except Exception as e:
        print(f"[ERROR] Failed to write to database: {e}")


# ============================================================================
# Business Logic
# ============================================================================

def process_action(action: str, dataset_id: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    """
    Simulated business logic based on action type.
    Returns result dictionary.
    Raises ValueError for forced failures.
    """
    # Check for forced failure
    if payload.get("force_fail"):
        raise ValueError("forced failure requested: payload.force_fail=true")

    # Simulate different actions
    if action == "summarize":
        rows = payload.get("rows", [])
        return {
            "summary": f"{len(rows)} records processed",
            "rows_processed": len(rows),
            "dataset": dataset_id
        }

    elif action == "count":
        items = payload.get("items", [])
        return {
            "count": len(items),
            "dataset": dataset_id
        }

    elif action == "validate":
        return {
            "valid": True,
            "dataset": dataset_id,
            "checks_passed": ["schema", "constraints", "duplicates"]
        }

    else:
        return {
            "message": f"Action '{action}' executed successfully",
            "dataset": dataset_id,
            "payload_keys": list(payload.keys())
        }


# ============================================================================
# API Endpoints
# ============================================================================

@app.post("/process", response_model=APIResponse)
async def process_endpoint(
    request: Request,
    body: ProcessRequest,
    api_key_valid: bool = Depends(validate_api_key),
    jwt_payload: Dict[str, Any] = Depends(validate_jwt)
):
    """
    Main processing endpoint with dual authentication.

    Authentication required:
    - API Key (query param or header)
    - JWT Bearer token

    Request body:
    - dataset_id: string
    - action: string (summarize, count, validate, etc.)
    - payload: object (action-specific data)

    Special payload keys:
    - force_fail: true - simulates a processing failure
    """
    request_id = str(uuid.uuid4())
    start_time = time.time()
    client_ip = request.client.host if request.client else None

    try:
        # Process the action
        result = process_action(body.action, body.dataset_id, body.payload)

        # Calculate duration
        duration_ms = int((time.time() - start_time) * 1000)

        # Log success
        await log_request(
            request_id=request_id,
            dataset_id=body.dataset_id,
            action=body.action,
            status_str="success",
            duration_ms=duration_ms,
            output=result,
            http_status=200,
            client=client_ip
        )

        return APIResponse(
            request_id=request_id,
            status="success",
            data=result
        )

    except ValueError as e:
        # Business logic failure (e.g., forced fail)
        duration_ms = int((time.time() - start_time) * 1000)
        error_msg = str(e)

        await log_request(
            request_id=request_id,
            dataset_id=body.dataset_id,
            action=body.action,
            status_str="failure",
            duration_ms=duration_ms,
            output=error_msg,
            http_status=400,
            client=client_ip
        )

        raise HTTPException(
            status_code=400,
            detail=error_msg
        )

    except Exception as e:
        # Unexpected error
        duration_ms = int((time.time() - start_time) * 1000)
        error_msg = f"Unexpected error: {str(e)}"

        await log_request(
            request_id=request_id,
            dataset_id=body.dataset_id,
            action=body.action,
            status_str="failure",
            duration_ms=duration_ms,
            output=error_msg,
            http_status=500,
            client=client_ip
        )

        raise HTTPException(
            status_code=500,
            detail=error_msg
        )


@app.get("/health")
async def health_check():
    """Simple health check endpoint (no auth required)"""
    return {"status": "healthy", "service": "process-api", "port": 8899}


# ============================================================================
# Main Entry Point
# ============================================================================

if __name__ == "__main__":
    import uvicorn

    print("=" * 60)
    print("Starting Secure Process API on port 8899")
    print("=" * 60)
    print(f"API Key: {API_KEY[:10]}... (truncated)")
    print(f"JWT Secret: {'*' * len(JWT_SECRET)} (hidden)")
    print("=" * 60)

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8899,
        reload=False,
        log_level="info"
    )
