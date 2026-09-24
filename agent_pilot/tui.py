from __future__ import annotations
import questionary
from .models import Component

def choose_role() -> str:
    role = questionary.select("Select this machine's role:", choices=[
        questionary.Choice("Gateway node", value="gateway"),
        questionary.Choice("Worker / agent node", value="worker"),
        questionary.Choice("Headscale control-plane node", value="headscale"),
    ]).ask()
    if not role:
        raise KeyboardInterrupt
    return role

def _label(c: Component) -> str:
    badges = [x for x in [c.license, "/".join(c.interface), "+".join(c.protocols)] if x]
    suffix = f"  [{' · '.join(badges)}]" if badges else ""
    return f"{c.name}  ·  {c.description}{suffix}"

def choose_components(role: str, catalog: dict[str, Component]) -> list[str]:
    infra, agents = [], []
    for c in catalog.values():
        if c.roles and role not in c.roles:
            continue
        if not c.selectable or c.status != "active":
            continue
        choice = questionary.Choice(_label(c), value=c.id, checked=c.recommended and role in c.roles)
        (agents if c.kind == "agent-app" else infra).append(choice)
    selected = []
    if infra:
        picked = questionary.checkbox("Infrastructure (Space toggles, Enter confirms):", choices=infra).ask()
        if picked is None: raise KeyboardInterrupt
        selected.extend(picked)
    if role in {"worker", "gateway"} and agents:
        picked = questionary.checkbox("Open-source agent apps (select any number):", choices=agents).ask()
        if picked is None: raise KeyboardInterrupt
        selected.extend(picked)
    return selected

def confirm_install(summary: str) -> bool:
    print(summary)
    return bool(questionary.confirm("Run this plan?", default=False).ask())
