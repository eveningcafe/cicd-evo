import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from app import app  # noqa: E402


def test_index_returns_expected_shape():
    client = app.test_client()
    response = client.get("/")
    assert response.status_code == 200
    body = response.get_json()
    assert {"message", "environment", "version", "host"} <= set(body)


def test_healthz_ok():
    client = app.test_client()
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_readyz_ok():
    client = app.test_client()
    response = client.get("/readyz")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ready"}
