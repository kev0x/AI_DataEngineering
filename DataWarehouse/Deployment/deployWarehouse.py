from __future__ import annotations

from pathlib import Path
import argparse
import sys

import duckdb


DATA_WAREHOUSE_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = DATA_WAREHOUSE_ROOT.parent
DEFAULT_WAREHOUSE_PATH = PROJECT_ROOT / "warehouse" / "finance.duckdb"
DEFAULT_DATA_ROOT = PROJECT_ROOT / "data" / "private" / "chase"
DEPLOYMENT_ORDER_PATH = DATA_WAREHOUSE_ROOT / "Deployment" / "deploymentOrder.txt"

sys.path.insert(0, str(PROJECT_ROOT))

from DataWarehouse.Deployment.populateWarehouse import populate_warehouse
from DataWarehouse.Deployment.populateWarehouse import DEFAULT_STAGE_CHUNK_SIZE


class WarehouseDeployer:
    """Deploys DuckDB warehouse schemas, tables, seeds, and views from SQL files."""

    def __init__(
        self,
        warehouse_path: Path,
        deployment_order_path: Path = DEPLOYMENT_ORDER_PATH,
        data_warehouse_root: Path = DATA_WAREHOUSE_ROOT,
    ) -> None:
        """Store the warehouse target and deployment manifest locations."""
        self.warehouse_path = warehouse_path
        self.deployment_order_path = deployment_order_path
        self.data_warehouse_root = data_warehouse_root

    def ordered_sql_files(self) -> list[Path]:
        """Read deploymentOrder.txt and return SQL files in execution order."""
        sql_files: list[Path] = []
        for line in self.deployment_order_path.read_text().splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            sql_files.append(self.data_warehouse_root / stripped)
        return sql_files

    def deploy(self, reset: bool = False) -> None:
        """Create or update the DuckDB warehouse, optionally dropping schemas first."""
        self.warehouse_path.parent.mkdir(parents=True, exist_ok=True)

        with duckdb.connect(str(self.warehouse_path)) as connection:
            if reset:
                self.drop_medallion_schemas(connection)
            self.execute_sql_files(connection)

    def drop_medallion_schemas(self, connection: duckdb.DuckDBPyConnection) -> None:
        """Drop Gold, Silver, and Bronze schemas for a development full refresh."""
        for schema_name in ["Gold", "Silver", "Bronze"]:
            connection.execute(f"drop schema if exists {schema_name} cascade")

    def execute_sql_files(self, connection: duckdb.DuckDBPyConnection) -> None:
        """Execute each SQL file from the deployment manifest."""
        for sql_file in self.ordered_sql_files():
            connection.execute(sql_file.read_text())
            print(f"deployed {sql_file.relative_to(self.data_warehouse_root)}")


class DeploymentCommand:
    """Command-line entry point for deploying and optionally populating the warehouse."""

    def __init__(
        self,
        parser: argparse.ArgumentParser | None = None,
    ) -> None:
        """Store the CLI parser used by the deployment command."""
        self.parser = parser or self.build_argument_parser()

    def build_argument_parser(self) -> argparse.ArgumentParser:
        """Create the command-line parser for warehouse deployment options."""
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
        parser.add_argument(
            "--populate",
            action="store_true",
            help="Load private Chase CSV files into Bronze and Silver after deployment.",
        )
        parser.add_argument(
            "--data-root",
            type=Path,
            default=DEFAULT_DATA_ROOT,
            help="Directory containing private Chase CSV exports.",
        )
        parser.add_argument(
            "--stage-chunk-size",
            type=int,
            default=DEFAULT_STAGE_CHUNK_SIZE,
            help="Maximum staged transaction rows to process per source table per chunk.",
        )
        return parser

    def run(self) -> None:
        """Parse CLI arguments, deploy SQL objects, and optionally populate data."""
        args = self.parser.parse_args()
        deploy_warehouse(args.warehouse, args.reset)
        print(f"deployed warehouse to {args.warehouse}")
        if args.populate:
            populate_warehouse(args.warehouse, args.data_root, args.stage_chunk_size)


def deploy_warehouse(warehouse_path: Path, reset: bool) -> None:
    """Compatibility function that deploys the warehouse through WarehouseDeployer."""
    WarehouseDeployer(warehouse_path).deploy(reset=reset)


def main() -> None:
    """Run the deployment command from the command line."""
    DeploymentCommand().run()


if __name__ == "__main__":
    main()
