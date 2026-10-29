def node(id, type, name=None, config=None, x=0, y=0):
    return {"id": id, "type": type, "name": name or id, "position": {"x": x, "y": y}, "config": config or {}}


def edge(source, target, handle="out"):
    return {"id": f"{source}-{target}-{handle}", "source": source, "target": target, "source_handle": handle}


def create_workflow(client, headers, definition=None, name="Test workflow"):
    response = client.post("/api/v1/workflows", headers=headers, json={"name": name, "definition": definition})
    assert response.status_code == 201, response.text
    return response.json()


def http_workflow(base_url, path="/data", extra_nodes=(), extra_edges=(), **http_config):
    return {
        "nodes": [
            node("start", "trigger.manual"),
            node("fetch", "action.http_request", "Fetch", {"method": "GET", "url": f"{base_url}{path}", **http_config}),
            *extra_nodes,
        ],
        "edges": [edge("start", "fetch"), *extra_edges],
    }
