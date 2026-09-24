from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import re
from typing import Callable
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from .models import Component

DEFAULT_TIMEOUT_SECONDS = 3.0
DEFAULT_MAX_WORKERS = 8
USER_AGENT = "Agent-Pilot/0.1 (+https://github.com/Krutas/Agent-Pilot)"
_URL_RE = re.compile(r"https?://[^\s\"'<>]+")


def url_is_reachable(url: str, timeout: float = DEFAULT_TIMEOUT_SECONDS) -> bool:
    """Return True when an HTTP(S) endpoint responds successfully."""
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
        # A number of installer/CDN endpoints intentionally reject HEAD.
        if exc.code not in {403, 405, 501}:
            return False
    except (URLError, TimeoutError, OSError):
        return False

    try:
        return probe("GET")
    except (HTTPError, URLError, TimeoutError, OSError):
        return False


def component_urls(component: Component) -> tuple[str, ...]:
    """Collect the component's primary URL and static installer URLs.

    Installer scripts are part of Agent Pilot's trusted repository. Extracting
    literal HTTP(S) endpoints here means a broken install.sh/release endpoint is
    caught before that program is offered to the user. Package-manager installs
    without a literal URL still get their source_url checked.
    """
    urls: list[str] = []
    if component.source_url:
        urls.append(component.source_url)

    try:
        installer_text = Path(component.installer).read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        installer_text = ""

    for match in _URL_RE.findall(installer_text):
        # Strip common sentence/shell punctuation that can trail a literal URL.
        url = match.rstrip(".,);]}")
        if url and url not in urls:
            urls.append(url)
    return tuple(urls)


def filter_available_components(
    catalog: dict[str, Component],
    *,
    checker: Callable[[str], bool] = url_is_reachable,
    max_workers: int = DEFAULT_MAX_WORKERS,
) -> dict[str, Component]:
    """Keep only usable active/selectable components whose URLs are reachable.

    Every named program is checked, including infrastructure. Each candidate
    must pass its source URL plus any static HTTP(S) URL embedded in its installer
    script. Archived/non-selectable entries stay as metadata and remain hidden by
    the UI. Components whose required dependency disappears are pruned too.
    """
    probe_targets = {
        component_id: component
        for component_id, component in catalog.items()
        if component.status == "active" and component.selectable
    }
    if not probe_targets:
        return dict(catalog)

    jobs: dict[object, tuple[str, str]] = {}
    results: dict[str, list[bool]] = {
        component_id: [] for component_id in probe_targets
    }
    worker_count = max(1, min(max_workers, sum(max(1, len(component_urls(c))) for c in probe_targets.values())))

    with ThreadPoolExecutor(max_workers=worker_count) as pool:
        for component_id, component in probe_targets.items():
            urls = component_urls(component)
            if not urls:
                results[component_id].append(False)
                continue
            for url in urls:
                jobs[pool.submit(checker, url)] = (component_id, url)

        for future in as_completed(jobs):
            component_id, _url = jobs[future]
            try:
                results[component_id].append(bool(future.result()))
            except Exception:
                results[component_id].append(False)

    reachable = {
        component_id
        for component_id, checks in results.items()
        if checks and all(checks)
    }

    available = {
        component_id: component
        for component_id, component in catalog.items()
        if component_id not in probe_targets or component_id in reachable
    }

    # Dependency-aware pruning. Repeat because dependency chains may be nested.
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
