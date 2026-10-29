def test_health(client):
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_security_headers(client):
    response = client.get("/api/v1/health")
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["x-frame-options"] == "DENY"


def test_openapi_lists_core_routes(client):
    paths = client.get("/openapi.json").json()["paths"]
    for path in ["/api/v1/auth/login", "/api/v1/workflows", "/api/v1/executions", "/api/v1/dashboard/summary"]:
        assert path in paths
