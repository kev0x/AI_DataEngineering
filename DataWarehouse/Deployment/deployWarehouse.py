from pathlib import Path
import argparse

import duckdb


DATA_WAREHOUSE_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = DATA_WAREHOUSE_ROOT.parent
DEFAULT_WAREHOUSE_PATH = PROJECT_ROOT / "warehouse" / "finance.duckdb"
DEPLOYMENT_ORDER_PATH = DATA_WAREHOUSE_ROOT / "Deployment" / "deploymentOrder.txt"


def ordered_sql_files() -> list[Path]:
    sql_files: list[Path] = []
    for line in DEPLOYMENT_ORDER_PATH.read_text().splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        sql_files.append(DATA_WAREHOUSE_ROOT / stripped)
    return sql_files


def deploy_warehouse(warehouse_path: Path, reset: bool) -> None:
    warehouse_path.parent.mkdir(parents=True, exist_ok=True)

    with duckdb.connect(str(warehouse_path)) as connection:
        if reset:
            for schema_name in ["Gold", "Silver", "Bronze"]:
                connection.execute(f"drop schema if exists {schema_name} cascade")

        for sql_file in ordered_sql_files():
            connection.execute(sql_file.read_text())
            print(f"deployed {sql_file.relative_to(DATA_WAREHOUSE_ROOT)}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Deploy the DuckDB data warehouse.")
    parser.add_argument(
        "--warehouse",
        type=Path,
        default=DEFAULT_WAREHOUSE_PATH,
        help="Path to the DuckDB database file.",
    )
    parser.add_argument(
        "--reset",
        action="store_true",
        help="Drop Bronze, Silver, and Gold before deploying.",
    )
    args = parser.parse_args()

    deploy_warehouse(args.warehouse, args.reset)
    print(f"deployed warehouse to {args.warehouse}")


if __name__ == "__main__":
    main()

