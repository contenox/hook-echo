import httpx

BASE_URL = "http://localhost:8000"

HEADERS = {}

def test_echo_successful_request():
    test_input = {"input": "Hello FastAPI"}
    expected_output = {"output": "Echo: Hello FastAPI"}

    response = httpx.post(f"{BASE_URL}/echo", json=test_input, headers=HEADERS)
    assert response.status_code == 200
    assert response.json() == expected_output

def test_health_check_get():
    response = httpx.get(f"{BASE_URL}/health", headers=HEADERS)
    assert response.status_code == 200

def test_ready_check():
    response = httpx.get(f"{BASE_URL}/ready", headers=HEADERS)
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}

def test_health_check_head():
    response = httpx.head(f"{BASE_URL}/health", headers=HEADERS)
    assert response.status_code == 200
