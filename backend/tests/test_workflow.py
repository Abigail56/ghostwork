from tests.helpers import create_workflow, edge, node


def test_create_list_get_update_delete(client, auth):
    created = create_workflow(client, auth, name="Daily report")
    assert created["status"] == "draft"
    assert created["validation"]  # empty workflow is not yet valid

    listing = client.get("/api/v1/workflows", headers=auth).json()
    assert listing["total"] == 1 and listing["items"][0]["name"] == "Daily report"

    updated = client.patch(
        f"/api/v1/workflows/{created['id']}",
        headers=auth,
        json={"name": "Nightly report", "expected_version": created["version"]},
    )
    assert updated.status_code == 200 and updated.json()["name"] == "Nightly report"

    stale = client.patch(
        f"/api/v1/workflows/{created['id']}", headers=auth, json={"name": "x", "expected_version": created["version"]}
    )
    assert stale.status_code == 409

    assert client.delete(f"/api/v1/workflows/{created['id']}", headers=auth).status_code == 200
    assert client.get(f"/api/v1/workflows/{created['id']}", headers=auth).status_code == 404


def test_search_filter_sort_paginate(client, auth):
    for name in ["Alpha sync", "Beta monitor", "Gamma sync", "100%_literal"]:
        create_workflow(client, auth, name=name)
    search = client.get("/api/v1/workflows", headers=auth, params={"q": "sync"}).json()
    assert {w["name"] for w in search["items"]} == {"Alpha sync", "Gamma sync"}
    literal = client.get("/api/v1/workflows", headers=auth, params={"q": "%_"}).json()
    assert [w["name"] for w in literal["items"]] == ["100%_literal"]
    by_name = client.get("/api/v1/workflows", headers=auth, params={"sort": "name"}).json()
    assert [w["name"] for w in by_name["items"]][0] == "100%_literal"
    page = client.get("/api/v1/workflows", headers=auth, params={"page": 2, "page_size": 3}).json()
    assert page["total"] == 4 and len(page["items"]) == 1
    drafts = client.get("/api/v1/workflows", headers=auth, params={"status": "active"}).json()
    assert drafts["total"] == 0


def test_ownership_is_enforced(client, auth, other_auth):
    workflow = create_workflow(client, auth)
    wid = workflow["id"]
    assert client.get(f"/api/v1/workflows/{wid}", headers=other_auth).status_code == 404
    assert client.patch(f"/api/v1/workflows/{wid}", headers=other_auth, json={"name": "pwned"}).status_code == 404
    assert client.delete(f"/api/v1/workflows/{wid}", headers=other_auth).status_code == 404
    assert client.post(f"/api/v1/workflows/{wid}/run", headers=other_auth, json={}).status_code == 404
    assert client.post(f"/api/v1/workflows/{wid}/duplicate", headers=other_auth).status_code == 404
    assert client.get("/api/v1/workflows", headers=other_auth).json()["total"] == 0


def test_structural_validation_on_save(client, auth):
    bad_type = {"nodes": [node("a", "action.shell_exec")], "edges": []}
    response = client.post("/api/v1/workflows", headers=auth, json={"name": "x", "definition": bad_type})
    assert response.status_code == 422
    assert "Unsupported node type" in str(response.json())

    dangling = {"nodes": [node("a", "trigger.manual")], "edges": [edge("a", "missing")]}
    assert client.post("/api/v1/workflows", headers=auth, json={"name": "x", "definition": dangling}).status_code == 422

    secret_header = {
        "nodes": [node("h", "action.http_request", config={"url": "https://x.io", "headers": [{"key": "Authorization", "value": "Bearer abc"}]})],
        "edges": [],
    }
    response = client.post("/api/v1/workflows", headers=auth, json={"name": "x", "definition": secret_header})
    assert response.status_code == 422 and "HTTP credential" in str(response.json())


def test_semantic_validation(client, auth):
    cyclic = {
        "nodes": [node("t", "trigger.manual"), node("a", "action.transform", config={"fields": [{"key": "x", "value": "1"}]}),
                  node("b", "action.transform", config={"fields": [{"key": "y", "value": "2"}]})],
        "edges": [edge("t", "a"), edge("a", "b"), edge("b", "a")],
    }
    workflow = create_workflow(client, auth, cyclic)
    result = client.post(f"/api/v1/workflows/{workflow['id']}/validate", headers=auth).json()
    assert not result["valid"] and "loop" in result["issues"][0]["message"]

    bad_reference = {
        "nodes": [node("t", "trigger.manual"),
                  node("a", "action.transform", config={"fields": [{"key": "x", "value": "{{ steps.later.value }}"}]}),
                  node("later", "action.transform", config={"fields": [{"key": "y", "value": "1"}]})],
        "edges": [edge("t", "a"), edge("a", "later")],
    }
    workflow = create_workflow(client, auth, bad_reference)
    issues = client.post(f"/api/v1/workflows/{workflow['id']}/validate", headers=auth).json()["issues"]
    assert any("doesn't run before" in i["message"] and i["node_id"] == "a" for i in issues)

    orphan = {
        "nodes": [node("t", "trigger.manual"), node("a", "action.transform", config={"fields": [{"key": "x", "value": "1"}]})],
        "edges": [],
    }
    workflow = create_workflow(client, auth, orphan)
    issues = client.post(f"/api/v1/workflows/{workflow['id']}/validate", headers=auth).json()["issues"]
    assert any("isn't connected" in i["message"] for i in issues)


def test_activation_requires_valid_definition(client, auth):
    workflow = create_workflow(client, auth)
    response = client.post(f"/api/v1/workflows/{workflow['id']}/status", headers=auth, json={"status": "active"})
    assert response.status_code == 422

    valid = {
        "nodes": [node("t", "trigger.schedule", config={"every": 1, "unit": "hours"}),
                  node("a", "action.transform", config={"fields": [{"key": "x", "value": "1"}]})],
        "edges": [edge("t", "a")],
    }
    workflow = create_workflow(client, auth, valid)
    active = client.post(f"/api/v1/workflows/{workflow['id']}/status", headers=auth, json={"status": "active"}).json()
    assert active["status"] == "active" and active["next_run_at"] is not None

    # Active workflows cannot be saved into an invalid state.
    broken = client.patch(f"/api/v1/workflows/{workflow['id']}", headers=auth, json={"definition": {"nodes": [], "edges": []}})
    assert broken.status_code == 422

    paused = client.post(f"/api/v1/workflows/{workflow['id']}/status", headers=auth, json={"status": "paused"}).json()
    assert paused["status"] == "paused" and paused["next_run_at"] is None


def test_schedule_minimum_interval(client, auth):
    definition = {
        "nodes": [node("t", "trigger.schedule", config={"every": 1, "unit": "minutes"}),
                  node("a", "action.transform", config={"fields": [{"key": "x", "value": "1"}]})],
        "edges": [edge("t", "a")],
    }
    workflow = create_workflow(client, auth, definition)
    assert any("5 minutes" in i["message"] for i in workflow["validation"])


def test_duplicate(client, auth):
    definition = {"nodes": [node("t", "trigger.manual")], "edges": []}
    workflow = create_workflow(client, auth, definition, name="Original")
    copy = client.post(f"/api/v1/workflows/{workflow['id']}/duplicate", headers=auth).json()
    assert copy["name"] == "Original (copy)" and copy["id"] != workflow["id"] and copy["status"] == "draft"
    assert copy["definition"] == workflow["definition"]


def test_templates_are_valid_definitions(client, auth):
    from app.services.templates import TEMPLATES
    from app.services.workflow_definition import validate_definition
    import uuid

    for template in TEMPLATES:
        fake = {}
        definition = template.definition
        for n in definition["nodes"]:
            if n["type"] in ("action.email", "action.slack"):
                fake_id = uuid.uuid4()
                fake[fake_id] = "smtp" if n["type"] == "action.email" else "slack"
                n = {**n, "config": {**n["config"], "integration_id": str(fake_id)}}
        patched = {
            **definition,
            "nodes": [
                {**n, "config": {**n["config"], "integration_id": str(next(k for k, v in fake.items() if v == ("smtp" if n["type"] == "action.email" else "slack")))}}
                if n["type"] in ("action.email", "action.slack") else n
                for n in definition["nodes"]
            ],
        }
        result = validate_definition(patched, fake)
        assert result.valid, (template.slug, [i.message for i in result.issues])

    used = client.post("/api/v1/templates/scheduled-data-pull/use", headers=auth, json={}).json()
    assert used["name"] == "Scheduled data retrieval" and used["validation"] == []


def test_node_catalog(client):
    types = {n["type"] for n in client.get("/api/v1/node-types").json()}
    assert types == {"trigger.manual", "trigger.schedule", "trigger.webhook", "action.http_request",
                     "action.transform", "action.email", "action.slack", "condition.if"}
