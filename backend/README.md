# WhereIsMyBus - Backend

FastAPI backend server for the WhereIsMyBus college bus tracking system.

## Setup

### 1. Install dependencies
```bash
pip install -r requirements.txt
```

### 2. Configure environment variables
Copy `.env.example` to `.env` and fill in your values:
```bash
cp .env.example .env
```

| Variable | Description |
|---|---|
| `SMTP_EMAIL` | Gmail address to send OTPs from |
| `SMTP_PASSWORD` | Gmail App Password (not your real password) |
| `DB_HOST` | MySQL host (e.g. `127.0.0.1` or cloud DB URL) |
| `DB_USER` | MySQL username |
| `DB_PASS` | MySQL password |
| `DB_NAME` | MySQL database name (default: `college_bus`) |
| `DB_PORT` | MySQL port (default: `3307`) |
| `GEMINI_API_KEY` | Google Gemini API key (for voice assistant) |
| `REDIS_URL` | Redis URL (default: `redis://127.0.0.1:6379`) |

### 3. Initialize the database
Start the server, then visit:
```
http://localhost:8000/init_db
```

### 4. Seed sample data (optional)
```bash
python seed_data.py
```

### 5. Run the server
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

## Deployment (Render / Railway)

- **Build command:** `pip install -r requirements.txt`
- **Start command:** `uvicorn main:app --host 0.0.0.0 --port $PORT`
- Set all environment variables in your platform's dashboard — **do NOT commit `.env` to GitHub**

## Key Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/` | Health check |
| `POST` | `/login` | User login |
| `POST` | `/send_otp` | Send OTP email |
| `POST` | `/verify_otp` | Verify OTP |
| `GET` | `/api/routes/search` | Search buses by stop |
| `GET` | `/api/gps/live` | Live vehicle positions |
| `WS` | `/ws/gps` | WebSocket GPS stream |
