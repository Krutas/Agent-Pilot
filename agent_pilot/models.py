from dataclasses import dataclass, field
from pathlib import Path

@dataclass(frozen=True)
class Component:
    id: str
    name: str
    category: str
    kind: str
    description: str
    installer: Path
    source_url: str
    docs_url: str = ""
    license: str = ""
    interface: tuple[str, ...] = field(default_factory=tuple)
    protocols: tuple[str, ...] = field(default_factory=tuple)
    roles: tuple[str, ...] = field(default_factory=tuple)
    recommended: bool = False
    requires: tuple[str, ...] = field(default_factory=tuple)
    model_integration: str = "user-managed"
    status: str = "active"
    selectable: bool = True
    availability_urls: tuple[str, ...] = field(default_factory=tuple)

@dataclass(frozen=True)
class InstallPlan:
    role: str
    components: tuple[Component, ...]
    dry_run: bool
