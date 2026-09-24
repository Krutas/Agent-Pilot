from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Callable
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from .models import Component

DEFAULT_TIMEOUT_SECONDS = 3.0
DEFAULT_MAX_WORKERS = 8
USER_AGENT = "Agent-Pilot/0.1 (+https://github.com/Krutas/Agent-Pilot)"


def url_is_reachable(url: str, timeout: float = DEFAULT_TIMEOUT_SECONDS) -> bool:
    """Return True when a component's primary URL is reachable.

    HEAD keeps the startup probe light. Some servers reject HEAD while serving
    normal requests, so 403/405/501 responses are retried with GET.
    """
    if not url or not url.startswith(("https://", "http://")):
        return False

    def probe(method: str) -> bool:
        request = Request(url, method=method, headers={"User-Agent": USER_AGENT})
        with urlopen(request, timeout=timeout) as response:
            status = response.getcode()
            return status is None or 200 <= status < 400

    try:
        return probe("HEAD")
    except HTTPError as exc:
        if exc.code not in {403, 405, 501}:
            return False
    except (URLError, TimeoutError, OSError):
        return False

    try:
        return probe("GET")
    except (HTTPError, URLError, TimeoutError, OSError):
        return False


def filter_available_components(
    catalog: dict[str, Component],
    *,
    checker: Callable[[str], bool] = url_is_reachable,
    max_workers: int = DEFAULT_MAX_WORKERS,
) -> dict[str, Component]:
    """Keep only usable active/selectable components with reachable source URLs.

    Every named program is checked, including infrastructure. Archived or
    explicitly non-selectable entries remain as metadata. After URL filtering,
    any selectable component whose required dependency disappeared is also
    removed so the UI never offers an install plan that cannot be resolved.
    """
    probe_targets = {
        component_id: component
        for component_id, component in catalog.items()
        if component.status == "active" and component.selectable
    }
    if not probe_targets:
        return dict(catalog)

    reachable: set[str] = set()
    worker_count = max(1, min(max_workers, len(probe_targets)))
    with ThreadPoolExecutor(max_workers=worker_count) as pool:
        futures = {
            pool.submit(checker, component.source_url): component_id
            for component_id, component in probe_targets.items()
        }
        for future in as_completed(futures):
            component_id = futures[future]
            try:
                if future.result():
                    reachable.add(component_id)
            except Exception:
                # One bad upstream/check must not abort the whole installer.
                pass

    available = {
        component_id: component
        for component_id, component in catalog.items()
        if component_id not in probe_targets or component_id in reachable
    }

    # Dependency-aware pruning. Repeat because dependencies can be chained.
    changed = True
    while changed:
        changed = False
        for component_id, component in tuple(available.items()):
            if component_id not in probe_targets:
                continue
            if any(dep not in available for dep in component.requires):
                del available[component_id]
                changed = True

    return available
