# Postman Testing Guide for Process API

Complete guide for testing the Secure Process API using Postman.

## Quick Setup

### 1. Environment Variables in Postman

Create a new Postman Environment with these variables:

| Variable Name | Initial Value | Current Value |
|--------------|---------------|---------------|
| `base_url` | `http://localhost:8899` | `http://localhost:8899` |
| `api_key` | `5gWwsAC7v7gnxVcVohu1YZCcj6PsTlEtC5zezAbN6OE` | |
| `jwt_secret` | `ZyPzGzKoyt7Mh2eVUEUWztwYvrlUV7uRs4gPYDVMGO7D4FKrdgEgQcxvY5TqeuEQHVFX15O8wdTj0QVz861neg` | |
| `jwt_token` | *(leave empty - will be auto-filled)* | |

### 2. Generate JWT Token

**Option A: Using Python Script**

Create a Pre-request Script in Postman Collection:

```javascript
// Generate JWT token using CryptoJS (built into Postman)
const header = {
    "alg": "HS256",
    "typ": "JWT"
};

const payload = {
    "sub": "testuser",
    "exp": Math.floor(Date.now() / 1000) + 3600  // Expires in 1 hour
};

function base64url(source) {
    let encodedSource = CryptoJS.enc.Base64.stringify(source);
    encodedSource = encodedSource.replace(/=+$/, '');
    encodedSource = encodedSource.replace(/\+/g, '-');
    encodedSource = encodedSource.replace(/\//g, '_');
    return encodedSource;
}

const stringifiedHeader = CryptoJS.enc.Utf8.parse(JSON.stringify(header));
const encodedHeader = base64url(stringifiedHeader);

const stringifiedPayload = CryptoJS.enc.Utf8.parse(JSON.stringify(payload));
const encodedPayload = base64url(stringifiedPayload);

const token = encodedHeader + "." + encodedPayload;

const secret = pm.environment.get("jwt_secret");
const signature = base64url(CryptoJS.HmacSHA256(token, secret));

const jwt = token + "." + signature;

pm.environment.set("jwt_token", jwt);
console.log("JWT Token generated: " + jwt);
```

**Option B: Using External Tool**

1. Go to [https://jwt.io/](https://jwt.io/)
2. In the **PAYLOAD** section, paste:
```json
{
  "sub": "testuser",
  "exp": 1735228800
}
```
3. Replace `exp` with current timestamp + 3600 seconds (use: https://www.unixtimestamp.com/)
4. In **VERIFY SIGNATURE** section, paste your JWT secret: `ZyPzGzKoyt7Mh2eVUEUWztwYvrlUV7uRs4gPYDVMGO7D4FKrdgEgQcxvY5TqeuEQHVFX15O8wdTj0QVz861neg`
5. Copy the generated token from the left panel
6. Paste it into Postman environment variable `jwt_token`

**Option C: Generate via Command Line (Easiest)**

```bash
# Run this in PowerShell
python -c "import jwt, time; print(jwt.encode({'sub': 'testuser', 'exp': int(time.time()) + 3600}, 'ZyPzGzKoyt7Mh2eVUEUWztwYvrlUV7uRs4gPYDVMGO7D4FKrdgEgQcxvY5TqeuEQHVFX15O8wdTj0QVz861neg', algorithm='HS256'))"
```

Copy the output and save it to `jwt_token` environment variable in Postman.

---

## API Requests Collection

### Request 1: Health Check (No Auth Required)

**Purpose:** Verify server is running

- **Method:** `GET`
- **URL:** `{{base_url}}/health`
- **Headers:** *(none required)*
- **Body:** *(none)*

**Expected Response (200 OK):**
```json
{
  "status": "healthy",
  "service": "process-api",
  "port": 8899
}
```

---

### Request 2: Successful Request with Query Param API Key

**Purpose:** Test successful processing with summarize action

- **Method:** `POST`
- **URL:** `{{base_url}}/process?api_key={{api_key}}`
- **Headers:**
  - `Authorization`: `Bearer {{jwt_token}}`
  - `Content-Type`: `application/json`
- **Body (raw JSON):**
```json
{
  "dataset_id": "sales_2025_q3",
  "action": "summarize",
  "payload": {
    "rows": [1, 2, 3, 4, 5]
  }
}
```

**Expected Response (200 OK):**
```json
{
  "request_id": "a3f1e2b8-4a2f-4d6a-9c2a-1b2c3d4e5f60",
  "status": "success",
  "data": {
    "summary": "5 records processed",
    "rows_processed": 5,
    "dataset": "sales_2025_q3"
  },
  "error": null
}
```

---

### Request 3: Successful Request with Header API Key

**Purpose:** Test API key authentication via header

- **Method:** `POST`
- **URL:** `{{base_url}}/process`
- **Headers:**
  - `X-API-Key`: `{{api_key}}`
  - `Authorization`: `Bearer {{jwt_token}}`
  - `Content-Type`: `application/json`
- **Body (raw JSON):**
```json
{
  "dataset_id": "inventory_2025",
  "action": "count",
  "payload": {
    "items": ["A", "B", "C", "D", "E", "F"]
  }
}
```

**Expected Response (200 OK):**
```json
{
  "request_id": "b4c5d3e2-1f2a-3d4b-5c6d-7e8f9a0b1c2d",
  "status": "success",
  "data": {
    "count": 6,
    "dataset": "inventory_2025"
  },
  "error": null
}
```

---

### Request 4: Validate Action

**Purpose:** Test the validate action type

- **Method:** `POST`
- **URL:** `{{base_url}}/process?api_key={{api_key}}`
- **Headers:**
  - `Authorization`: `Bearer {{jwt_token}}`
  - `Content-Type`: `application/json`
- **Body (raw JSON):**
```json
{
  "dataset_id": "user_data_2025",
  "action": "validate",
  "payload": {
    "schema_version": "v2.1",
    "record_count": 1000
  }
}
```

**Expected Response (200 OK):**
```json
{
  "request_id": "...",
  "status": "success",
  "data": {
    "valid": true,
    "dataset": "user_data_2025",
    "checks_passed": ["schema", "constraints", "duplicates"]
  },
  "error": null
}
```

---

### Request 5: Custom Action

**Purpose:** Test generic action handling

- **Method:** `POST`
- **URL:** `{{base_url}}/process?api_key={{api_key}}`
- **Headers:**
  - `Authorization`: `Bearer {{jwt_token}}`
  - `Content-Type`: `application/json`
- **Body (raw JSON):**
```json
{
  "dataset_id": "logs_2025",
  "action": "archive",
  "payload": {
    "start_date": "2025-01-01",
    "end_date": "2025-03-31",
    "compression": "gzip"
  }
}
```

**Expected Response (200 OK):**
```json
{
  "request_id": "...",
  "status": "success",
  "data": {
    "message": "Action 'archive' executed successfully",
    "dataset": "logs_2025",
    "payload_keys": ["start_date", "end_date", "compression"]
  },
  "error": null
}
```

---

## Error Test Cases

### Request 6: Forced Failure

**Purpose:** Test error handling and logging

- **Method:** `POST`
- **URL:** `{{base_url}}/process?api_key={{api_key}}`
- **Headers:**
  - `Authorization`: `Bearer {{jwt_token}}`
  - `Content-Type`: `application/json`
- **Body (raw JSON):**
```json
{
  "dataset_id": "test_failure",
  "action": "summarize",
  "payload": {
    "force_fail": true
  }
}
```

**Expected Response (400 Bad Request):**
```json
{
  "detail": "forced failure requested: payload.force_fail=true"
}
```

---

### Request 7: Missing API Key

**Purpose:** Test API key validation

- **Method:** `POST`
- **URL:** `{{base_url}}/process`
- **Headers:**
  - `Authorization`: `Bearer {{jwt_token}}`
  - `Content-Type`: `application/json`
- **Body (raw JSON):**
```json
{
  "dataset_id": "test",
  "action": "summarize",
  "payload": {}
}
```

**Expected Response (401 Unauthorized):**
```json
{
  "detail": "API key required (query param 'api_key' or header 'X-API-Key')"
}
```

---

### Request 8: Invalid API Key

**Purpose:** Test API key verification

- **Method:** `POST`
- **URL:** `{{base_url}}/process?api_key=wrong-key-12345`
- **Headers:**
  - `Authorization`: `Bearer {{jwt_token}}`
  - `Content-Type`: `application/json`
- **Body (raw JSON):**
```json
{
  "dataset_id": "test",
  "action": "summarize",
  "payload": {}
}
```

**Expected Response (401 Unauthorized):**
```json
{
  "detail": "Invalid API key"
}
```

---

### Request 9: Missing JWT Token

**Purpose:** Test JWT requirement

- **Method:** `POST`
- **URL:** `{{base_url}}/process?api_key={{api_key}}`
- **Headers:**
  - `Content-Type`: `application/json`
- **Body (raw JSON):**
```json
{
  "dataset_id": "test",
  "action": "summarize",
  "payload": {}
}
```

**Expected Response (401 Unauthorized):**
```json
{
  "detail": "Authorization header required"
}
```

---

### Request 10: Invalid JWT Token

**Purpose:** Test JWT validation

- **Method:** `POST`
- **URL:** `{{base_url}}/process?api_key={{api_key}}`
- **Headers:**
  - `Authorization`: `Bearer invalid.jwt.token`
  - `Content-Type`: `application/json`
- **Body (raw JSON):**
```json
{
  "dataset_id": "test",
  "action": "summarize",
  "payload": {}
}
```

**Expected Response (401 Unauthorized):**
```json
{
  "detail": "Invalid JWT token: ..."
}
```

---

### Request 11: Expired JWT Token

**Purpose:** Test JWT expiration

- **Method:** `POST`
- **URL:** `{{base_url}}/process?api_key={{api_key}}`
- **Headers:**
  - `Authorization`: `Bearer <expired-token>`
  - `Content-Type`: `application/json`
- **Body (raw JSON):**
```json
{
  "dataset_id": "test",
  "action": "summarize",
  "payload": {}
}
```

**Generate expired token:**
```bash
python -c "import jwt, time; print(jwt.encode({'sub': 'testuser', 'exp': int(time.time()) - 3600}, 'ZyPzGzKoyt7Mh2eVUEUWztwYvrlUV7uRs4gPYDVMGO7D4FKrdgEgQcxvY5TqeuEQHVFX15O8wdTj0QVz861neg', algorithm='HS256'))"
```

**Expected Response (401 Unauthorized):**
```json
{
  "detail": "JWT token has expired"
}
```

---

## Postman Collection JSON (Import This)

Save this as `Process_API.postman_collection.json` and import into Postman:

```json
{
  "info": {
    "name": "Secure Process API",
    "description": "API with dual authentication (API Key + JWT)",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Health Check",
      "request": {
        "method": "GET",
        "header": [],
        "url": {
          "raw": "{{base_url}}/health",
          "host": ["{{base_url}}"],
          "path": ["health"]
        }
      }
    },
    {
      "name": "Process - Summarize (Query Param Auth)",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Authorization",
            "value": "Bearer {{jwt_token}}"
          },
          {
            "key": "Content-Type",
            "value": "application/json"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"dataset_id\": \"sales_2025_q3\",\n  \"action\": \"summarize\",\n  \"payload\": {\n    \"rows\": [1, 2, 3, 4, 5]\n  }\n}"
        },
        "url": {
          "raw": "{{base_url}}/process?api_key={{api_key}}",
          "host": ["{{base_url}}"],
          "path": ["process"],
          "query": [
            {
              "key": "api_key",
              "value": "{{api_key}}"
            }
          ]
        }
      }
    },
    {
      "name": "Process - Count (Header Auth)",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "X-API-Key",
            "value": "{{api_key}}"
          },
          {
            "key": "Authorization",
            "value": "Bearer {{jwt_token}}"
          },
          {
            "key": "Content-Type",
            "value": "application/json"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"dataset_id\": \"inventory_2025\",\n  \"action\": \"count\",\n  \"payload\": {\n    \"items\": [\"A\", \"B\", \"C\", \"D\"]\n  }\n}"
        },
        "url": {
          "raw": "{{base_url}}/process",
          "host": ["{{base_url}}"],
          "path": ["process"]
        }
      }
    },
    {
      "name": "Process - Forced Failure",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Authorization",
            "value": "Bearer {{jwt_token}}"
          },
          {
            "key": "Content-Type",
            "value": "application/json"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"dataset_id\": \"test_failure\",\n  \"action\": \"summarize\",\n  \"payload\": {\n    \"force_fail\": true\n  }\n}"
        },
        "url": {
          "raw": "{{base_url}}/process?api_key={{api_key}}",
          "host": ["{{base_url}}"],
          "path": ["process"],
          "query": [
            {
              "key": "api_key",
              "value": "{{api_key}}"
            }
          ]
        }
      }
    },
    {
      "name": "Error - Missing API Key",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Authorization",
            "value": "Bearer {{jwt_token}}"
          },
          {
            "key": "Content-Type",
            "value": "application/json"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"dataset_id\": \"test\",\n  \"action\": \"summarize\",\n  \"payload\": {}\n}"
        },
        "url": {
          "raw": "{{base_url}}/process",
          "host": ["{{base_url}}"],
          "path": ["process"]
        }
      }
    },
    {
      "name": "Error - Invalid JWT",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Authorization",
            "value": "Bearer invalid.jwt.token"
          },
          {
            "key": "Content-Type",
            "value": "application/json"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"dataset_id\": \"test\",\n  \"action\": \"summarize\",\n  \"payload\": {}\n}"
        },
        "url": {
          "raw": "{{base_url}}/process?api_key={{api_key}}",
          "host": ["{{base_url}}"],
          "path": ["process"],
          "query": [
            {
              "key": "api_key",
              "value": "{{api_key}}"
            }
          ]
        }
      }
    }
  ]
}
```

---

## Tips for Postman Testing

1. **Auto-generate JWT:** Add the Pre-request Script (from Option A above) to your Collection so all requests automatically get a fresh JWT token

2. **Test Runner:** Use Postman's Collection Runner to execute all requests sequentially

3. **Add Tests:** Add these to the "Tests" tab of each request:

```javascript
// For successful requests
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});

pm.test("Response has request_id", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property('request_id');
});

pm.test("Status is success", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData.status).to.eql('success');
});
```

```javascript
// For error requests (401)
pm.test("Status code is 401", function () {
    pm.response.to.have.status(401);
});

pm.test("Has error detail", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property('detail');
});
```

4. **Monitor Logs:** Check `logs/requests.log` after each test to verify logging is working

5. **Database Verification:** Run `python scripts/init_db.py query` to see logged requests in the database

---

## Quick Start Checklist

- [ ] Start the server: `python main.py`
- [ ] Import environment variables in Postman
- [ ] Generate JWT token (use Option C command line method)
- [ ] Import the collection JSON above
- [ ] Run "Health Check" first to verify server
- [ ] Test successful requests (Requests 2-5)
- [ ] Test error cases (Requests 6-11)
- [ ] Check logs in `logs/requests.log`
- [ ] Query database: `python scripts/init_db.py query`

Happy testing! 🚀
