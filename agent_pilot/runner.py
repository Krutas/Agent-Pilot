import os
from pathlib import Path
import subprocess
from .models import InstallPlan

class InstallError(RuntimeError):
    pass

def load_env_file(path: Path) -> dict[str, str]:
    values = {}
    if not path.exists(): return values
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line: continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values

def render_plan(plan: InstallPlan) -> str:
    lines = ["", "Agent Pilot installation plan", "=============================", f"Role: {plan.role}", f"Mode: {'DRY RUN' if plan.dry_run else 'INSTALL'}", "", "Components:"]
    lines += [f"  - {c.name:<20} {c.source_url}" for c in plan.components]
    return "\n".join(lines)

def execute_plan(plan: InstallPlan, root: Path, env_file: Path | None = None) -> None:
    env = os.environ.copy()
    if env_file: env.update(load_env_file(env_file))
    env["AGENT_PILOT_ROLE"] = plan.role
    env["AGENT_PILOT_DRY_RUN"] = "true" if plan.dry_run else "false"
    env["AGENT_PILOT_ROOT"] = str(root)
    for c in plan.components:
        print(f"\n>>> {c.name}")
        result = subprocess.run(["bash", str(c.installer)], env=env, cwd=root)
        if result.returncode != 0:
            raise InstallError(f"installer failed for {c.name}: {result.returncode}")
