from pathlib import Path
from urllib.error import HTTPError

import agent_pilot.availability as availability
from agent_pilot.availability import ProbeStatus, component_urls, filter_available_components
from agent_pilot.catalog import load_catalog, resolve_dependencies
from agent_pilot.models import Component


def test_catalog_loads_core_infrastructure():
    catalog = load_catalog(); assert {"agentgateway", "tailscale", "headscale"} <= set(catalog)


def test_catalog_contains_active_agents():
    catalog = load_catalog(); expected = {"hermes","opencode","codex","aider","cline","goose","openhands","gemini-cli","qwen-code"}; assert expected <= set(catalog); assert all(catalog[x].status == "active" for x in expected)


def test_model_configuration_is_user_managed():
    agents = [c for c in load_catalog().values() if c.kind == "agent-app"]; assert agents and all(c.model_integration == "user-managed" for c in agents)


def test_installers_exist():
    assert all(c.installer.exists() for c in load_catalog().values())


def test_archived_agent_is_not_selectable():
    c = load_catalog()["roo-code"]; assert c.status == "archived" and c.selectable is False


def test_dependency_resolution():
    catalog = load_catalog(); assert resolve_dependencies(["tailscale","opencode"], catalog) == ["tailscale","opencode"]


def _component(component_id: str, installer: Path, *, requires=()) -> Component:
    return Component(
        id=component_id,
        name=component_id,
        category="test",
        kind="infrastructure",
        description="test component",
        installer=installer,
        source_url=f"https://example.test/{component_id}",
        requires=tuple(requires),
    )


def test_component_urls_include_installer_links(tmp_path):
    installer = tmp_path / "install.sh"
    installer.write_text(
        '#!/bin/sh\nrun_downloaded_script "https://downloads.example.test/install.sh"\n',
        encoding="utf-8",
    )
    component = _component("demo", installer)
    assert component_urls(component) == (
        "https://example.test/demo",
        "https://downloads.example.test/install.sh",
    )


def test_dynamic_installer_urls_are_not_probed(tmp_path):
    installer = tmp_path / "install.sh"
    installer.write_text(
        'asset="demo.tar.gz"\nurl="https://downloads.example.test/${asset}"\n',
        encoding="utf-8",
    )
    component = _component("demo", installer)
    assert component_urls(component) == ("https://example.test/demo",)


def test_unreachable_component_is_hidden(tmp_path):
    good_script = tmp_path / "good.sh"; good_script.write_text("#!/bin/sh\n", encoding="utf-8")
    bad_script = tmp_path / "bad.sh"; bad_script.write_text("#!/bin/sh\n", encoding="utf-8")
    catalog = {
        "good": _component("good", good_script),
        "bad": _component("bad", bad_script),
    }
    filtered = filter_available_components(
        catalog,
        checker=lambda url: not url.endswith("/bad"),
    )
    assert set(filtered) == {"good"}


def test_unknown_probe_keeps_component_visible(tmp_path):
    installer = tmp_path / "demo.sh"; installer.write_text("#!/bin/sh\n", encoding="utf-8")
    catalog = {"demo": _component("demo", installer)}
    filtered = filter_available_components(
        catalog,
        checker=lambda _url: ProbeStatus.UNKNOWN,
    )
    assert "demo" in filtered


def test_component_with_broken_installer_url_is_hidden(tmp_path):
    installer = tmp_path / "install.sh"
    installer.write_text(
        '#!/bin/sh\nrun_downloaded_script "https://downloads.example.test/broken.sh"\n',
        encoding="utf-8",
    )
    catalog = {"demo": _component("demo", installer)}
    filtered = filter_available_components(
        catalog,
        checker=lambda url: "broken.sh" not in url,
    )
    assert "demo" not in filtered


def test_component_with_missing_dependency_is_hidden(tmp_path):
    base_script = tmp_path / "base.sh"; base_script.write_text("#!/bin/sh\n", encoding="utf-8")
    child_script = tmp_path / "child.sh"; child_script.write_text("#!/bin/sh\n", encoding="utf-8")
    catalog = {
        "base": _component("base", base_script),
        "child": _component("child", child_script, requires=("base",)),
    }
    filtered = filter_available_components(
        catalog,
        checker=lambda url: not url.endswith("/base"),
    )
    assert "base" not in filtered
    assert "child" not in filtered


def test_head_404_is_confirmed_with_get_before_hard_failure(monkeypatch):
    calls = []

    class Response:
        def __enter__(self): return self
        def __exit__(self, *_args): return False
        def getcode(self): return 200

    def fake_urlopen(request, timeout):
        del timeout
        method = request.get_method()
        calls.append(method)
        if method == "HEAD":
            raise HTTPError(request.full_url, 404, "not found", None, None)
        return Response()

    monkeypatch.setattr(availability, "urlopen", fake_urlopen)
    assert availability.probe_url("https://example.test/install.sh") is ProbeStatus.AVAILABLE
    assert calls == ["HEAD", "GET"]
