import argparse
from pathlib import Path
from .catalog import load_catalog, resolve_dependencies
from .models import InstallPlan
from .runner import execute_plan, render_plan
from .tui import choose_components, choose_role, confirm_install

ROOT = Path(__file__).resolve().parents[1]

def parse_args():
    p = argparse.ArgumentParser(prog="agent-pilot")
    p.add_argument("--role", choices=["gateway", "worker", "headscale"])
    p.add_argument("--components", help="comma-separated component ids")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--yes", action="store_true")
    p.add_argument("--env-file", default=str(ROOT / ".env"))
    p.add_argument("--list-components", action="store_true")
    return p.parse_args()

def main() -> int:
    args = parse_args()
    catalog = load_catalog()
    if args.list_components:
        for c in catalog.values():
            print(f"{c.id:16} {c.name:24} {c.status:10} {c.description}")
        return 0
    try:
        role = args.role or choose_role()
        selected = [x.strip() for x in args.components.split(",") if x.strip()] if args.components else choose_components(role, catalog)
        selected = resolve_dependencies(selected, catalog)
        components = tuple(catalog[x] for x in selected)
        illegal = [c.id for c in components if c.roles and role not in c.roles]
        if illegal: raise SystemExit(f"Components not valid for role {role}: {', '.join(illegal)}")
        plan = InstallPlan(role=role, components=components, dry_run=args.dry_run)
        summary = render_plan(plan)
        if args.dry_run:
            print(summary); execute_plan(plan, ROOT, Path(args.env_file)); return 0
        if not args.yes and not confirm_install(summary):
            print("Cancelled. No changes made."); return 0
        execute_plan(plan, ROOT, Path(args.env_file))
        print("\nAgent Pilot finished successfully.")
        return 0
    except KeyboardInterrupt:
        print("\nCancelled. No changes made.")
        return 130

if __name__ == "__main__":
    raise SystemExit(main())
