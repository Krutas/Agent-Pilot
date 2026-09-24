from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor, as_completed
from enum import Enum
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


class ProbeStatus(str, Enum):
    AVAILABLE = "available"
    UNAVAILABLE = "unavailable"
    UNKNOWN = "unknown"


def probe_url(url: str, timeout: float = DEFAULT_TIMEOUT_SECONDS) -> ProbeStatus:
    """Probe an endpoint while avoiding false negatives.

    HEAD is only an optimization. A non-successful HEAD is always verified with
    a real GET because CDNs/WAFs may return 403/404/405 to HEAD while GET works.
    Only a GET-confirmed 404/410 is considered a hard failure. Auth/rate-limit,
    5xx, DNS, timeout, and other transport failures are UNKNOWN and stay visible.
    """
    if not url or not url.startswith(("https://", "http://")):
        return ProbeStatus.UNAVAILABLE

    def request(method: str) -> ProbeStatus:
        req = Request(url, method=method, headers={"User-Agent": USER_AGENT})
        try:
            with urlopen(req, timeout=timeout) as response:
                status = response.getcode()
                if status is None or 200 <= status < 400:
                    return ProbeStatus.AVAILABLE
                if status in {404, 410}:
                    return ProbeStatus.UNAVAILABLE
                return ProbeStatus.UNKNOWN
        except HTTPError as exc:
            if exc.code in {404, 410}:
                return ProbeStatus.UNAVAILABLE
            return ProbeStatus.UNKNOWN
        except (URLError, TimeoutError, OSError):
            return ProbeStatus.UNKNOWN

    head = request("HEAD")
    if head is ProbeStatus.AVAILABLE:
        return head

    # Confirm every HEAD failure with GET before hiding anything.
    return request("GET")


def url_is_reachable(url: str, timeout: float = DEFAULT_TIMEOUT_SECONDS) -> bool:
    """Compatibility helper for callers that need a strict boolean."""
    return probe_url(url, timeout=timeout) is ProbeStatus.AVAILABLE


def component_urls(component: Component) -> tuple[str, ...]:
    """Collect the component's primary URL and literal installer URLs.

    Dynamic shell URLs containing variables are deliberately skipped: probing a
    template such as .../${asset} would create a fake 404 and a false negative.
    """
    urls: list[str] = []
    if component.source_url:
        urls.append(component.source_url)

    try:
        installer_text = Path(component.installer).read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        installer_text = ""

    for match in _URL_RE.findall(installer_text):
        url = match.rstrip(".,);]}")
        if "$" in url or "{" in url or "}" in url:
            continue
        if url and url not in urls:
            urls.append(url)
    return tuple(urls)


def _normalise_result(result: ProbeStatus | bool) -> ProbeStatus:
    if isinstance(result, ProbeStatus):
        return result
    return ProbeStatus.AVAILABLE if result else ProbeStatus.UNAVAILABLE


def filter_available_components(
    catalog: dict[str, Component],
    *,
    checker: Callable[[str], ProbeStatus | bool] = probe_url,
    max_workers: int = DEFAULT_MAX_WORKERS,
) -> dict[str, Component]:
    """Hide only components with a confirmed hard URL failure.

    Every named program is checked, including infrastructure. UNKNOWN results
    remain visible to avoid false negatives from WAFs, rate limits, temporary
    server errors, DNS problems, and checker-network timeouts.
    """
    probe_targets = {
        component_id: component
        for component_id, component in catalog.items()
        if component.status == "active" and component.selectable
    }
    if not probe_targets:
        return dict(catalog)

    jobs: dict[object, tuple[str, str]] = {}
    results: dict[str, list[ProbeStatus]] = {
        component_id: [] for component_id in probe_targets
    }
    worker_count = max(
        1,
        min(
            max_workers,
            sum(max(1, len(component_urls(c))) for c in probe_targets.values()),
        ),
    )

    with ThreadPoolExecutor(max_workers=worker_count) as pool:
        for component_id, component in probe_targets.items():
            urls = component_urls(component)
            if not urls:
                results[component_id].append(ProbeStatus.UNAVAILABLE)
                continue
            for url in urls:
                jobs[pool.submit(checker, url)] = (component_id, url)

        for future in as_completed(jobs):
            component_id, _url = jobs[future]
            try:
                results[component_id].append(_normalise_result(future.result()))
            except Exception:
                # A checker failure is not evidence that the upstream is dead.
                results[component_id].append(ProbeStatus.UNKNOWN)

    hard_failed = {
        component_id
        for component_id, checks in results.items()
        if any(status is ProbeStatus.UNAVAILABLE for status in checks)
    }

    available = {
        component_id: component
        for component_id, component in catalog.items()
        if component_id not in hard_failed
    }

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
