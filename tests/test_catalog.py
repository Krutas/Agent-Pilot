from agent_pilot.catalog import load_catalog, resolve_dependencies

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
