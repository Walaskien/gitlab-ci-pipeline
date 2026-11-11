import pytest

from server import MAX_NOTES, MAX_TEXT, create_app


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "1.2.3")
    monkeypatch.setenv("APP_ENV", "test")
    return create_app().test_client()


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_index_reports_version_and_environment(client):
    body = client.get("/").get_json()
    assert body["service"] == "notes"
    assert body["version"] == "1.2.3"
    assert body["environment"] == "test"


def test_add_and_read_note(client):
    created = client.post("/notes", json={"text": "  buy milk "})
    assert created.status_code == 201
    note = created.get_json()
    assert note == {"id": 1, "text": "buy milk"}

    assert client.get("/notes/1").get_json() == note
    assert client.get("/notes").get_json() == {"notes": [note]}


@pytest.mark.parametrize(
    "payload",
    [{}, {"text": ""}, {"text": "   "}, {"text": 5}, {"text": "x" * (MAX_TEXT + 1)}],
)
def test_bad_note_is_rejected(client, payload):
    assert client.post("/notes", json=payload).status_code == 400


def test_missing_note_is_404(client):
    assert client.get("/notes/99").status_code == 404


def test_note_limit(client):
    for i in range(MAX_NOTES):
        assert client.post("/notes", json={"text": f"n{i}"}).status_code == 201
    assert client.post("/notes", json={"text": "one more"}).status_code == 409


def test_metrics_count_requests_by_route(client):
    client.get("/health")
    client.get("/no-such-page")
    text = client.get("/metrics").get_data(as_text=True)
    assert 'http_requests_total{method="GET",route="/health",status="200"}' in text
    # unknown paths share one label value
    assert 'route="unmatched"' in text
    assert "no-such-page" not in text
    assert "notes_stored" in text
