from pathlib import Path
import yaml
from .models import Component

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "manifests" / "components.yaml"

class CatalogError(RuntimeError):
    pass

def load_catalog(path: Path = MANIFEST) -> dict[str, Component]:
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict) or "components" not in raw:
        raise CatalogError("manifest must contain a top-level components mapping")
    result = {}
    for component_id, item in raw["components"].items():
        result[component_id] = Component(
            id=component_id,
            name=item["name"],
            category=item["category"],
            kind=item.get("kind", "infrastructure"),
            description=item["description"],
            installer=ROOT / item["installer"],
            source_url=item["source_url"],
            docs_url=item.get("docs_url", ""),
            license=item.get("license", ""),
            interface=tuple(item.get("interface", [])),
            protocols=tuple(item.get("protocols", [])),
            roles=tuple(item.get("roles", [])),
            recommended=bool(item.get("recommended", False)),
            requires=tuple(item.get("requires", [])),
            model_integration=item.get("model_integration", "user-managed"),
            status=item.get("status", "active"),
            selectable=bool(item.get("selectable", True)),
            availability_urls=tuple(item.get("availability_urls", [])),
        )
    validate_catalog(result)
    return result

def validate_catalog(catalog: dict[str, Component]) -> None:
    for cid, component in catalog.items():
        if not component.installer.exists():
            raise CatalogError(f"missing installer for {cid}: {component.installer}")
        missing = [dep for dep in component.requires if dep not in catalog]
        if missing:
            raise CatalogError(f"{cid} requires unknown components: {missing}")

def resolve_dependencies(selected: list[str], catalog: dict[str, Component]) -> list[str]:
    ordered, visiting, done = [], set(), set()
    def visit(cid: str) -> None:
        if cid not in catalog:
            raise CatalogError(f"unknown component: {cid}")
        if cid in done:
            return
        if cid in visiting:
            raise CatalogError(f"dependency cycle detected at {cid}")
        visiting.add(cid)
        for dep in catalog[cid].requires:
            visit(dep)
        visiting.remove(cid)
        done.add(cid)
        ordered.append(cid)
    for cid in selected:
        visit(cid)
    return ordered
