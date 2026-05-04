from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import argparse
import csv
import hashlib
import re

import duckdb


DATA_WAREHOUSE_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = DATA_WAREHOUSE_ROOT.parent
DEFAULT_WAREHOUSE_PATH = PROJECT_ROOT / "warehouse" / "finance.duckdb"
DEFAULT_DATA_ROOT = PROJECT_ROOT / "data" / "private" / "chase"
ETL_ORDER_PATH = DATA_WAREHOUSE_ROOT / "ETL" / "etlOrder.txt"
DEFAULT_STAGE_CHUNK_SIZE = 500
METADATA_ETL_FILES = {
    "ETL/Silver/ProcessDimSourceFile.sql",
    "ETL/Silver/ProcessDimFinancialAccount.sql",
}

CHECKING_HEADERS = {
    "Details",
    "Posting Date",
    "Description",
    "Amount",
    "Type",
    "Balance",
    "Check or Slip #",
}
CREDIT_HEADERS = {
    "Transaction Date",
    "Post Date",
    "Description",
    "Category",
    "Type",
    "Amount",
    "Memo",
}


@dataclass(frozen=True)
class SourceFileMetadata:
    """Metadata registered for one private Chase CSV before SQL ETL runs."""

    sourceFileName: str
    sourceFilePath: Path
    sourceFileHash: str
    sourceFileType: str
    rowCount: int
    accountType: str
    accountLastFour: str


class SqlLiteral:
    """Formats trusted Python values as SQL literals for DuckDB script generation."""

    @staticmethod
    def string(value: str | Path) -> str:
        """Return a single-quoted SQL string literal."""
        return "'" + str(value).replace("'", "''") + "'"


class ChaseSourceFileProfiler:
    """Discovers Chase CSV files and collects file-level metadata for SQL ETL."""

    def discover_source_files(self, data_root: Path) -> list[SourceFileMetadata]:
        """Return supported Chase CSV files under the private data folder."""
        discovered_source_files: list[SourceFileMetadata] = []
        discovered_csv_file_paths = (
            sorted(
                file_path
                for file_path in data_root.rglob("*")
                if file_path.is_file() and file_path.suffix.lower() == ".csv"
            )
            if data_root.exists()
            else []
        )
        for csv_file_path in discovered_csv_file_paths:
            source_file_metadata = self.profile_source_file(csv_file_path)
            if source_file_metadata is not None:
                discovered_source_files.append(source_file_metadata)
        return discovered_source_files

    def profile_source_file(self, csv_file_path: Path) -> SourceFileMetadata | None:
        """Inspect one CSV header and return metadata when the file is supported."""
        with csv_file_path.open(newline="", encoding="utf-8-sig") as source_file:
            csv_reader = csv.DictReader(source_file)
            source_headers = set(csv_reader.fieldnames or [])
            row_count = sum(1 for _ in csv_reader)

        source_file_type = self.detect_source_file_type(source_headers)
        if source_file_type is None:
            print(f"skipped unsupported CSV shape: {csv_file_path.name}")
            return None

        return SourceFileMetadata(
            sourceFileName=csv_file_path.name,
            sourceFilePath=csv_file_path,
            sourceFileHash=self.file_hash(csv_file_path),
            sourceFileType=source_file_type,
            rowCount=row_count,
            accountType=self.account_type(source_file_type),
            accountLastFour=self.account_last_four(csv_file_path.name),
        )

    @staticmethod
    def detect_source_file_type(source_headers: set[str]) -> str | None:
        """Classify a CSV as Chase checking, Chase credit card, or unsupported."""
        if CHECKING_HEADERS.issubset(source_headers):
            return "chaseCheckingCsv"
        if CREDIT_HEADERS.issubset(source_headers):
            return "chaseCreditCsv"
        return None

    @staticmethod
    def file_hash(csv_file_path: Path) -> str:
        """Calculate a stable SHA-256 hash for idempotent file loading."""
        return hashlib.sha256(csv_file_path.read_bytes()).hexdigest()

    @staticmethod
    def account_type(source_file_type: str) -> str:
        """Return the Silver account type for a Chase source file type."""
        if source_file_type == "chaseCheckingCsv":
            return "checking"
        return "creditCard"

    @staticmethod
    def account_last_four(source_file_name: str) -> str:
        """Extract account last four from a file name when present."""
        account_digit_candidates = re.findall(r"(?<!\d)(\d{4})(?!\d)", source_file_name)
        return account_digit_candidates[-1] if account_digit_candidates else "unknown"


class DuckDbEtlRunner:
    """Stages source CSVs and runs DuckDB SQL ETL scripts in manifest order."""

    def __init__(
        self,
        warehouse_path: Path,
        data_root: Path,
        stage_chunk_size: int = DEFAULT_STAGE_CHUNK_SIZE,
        etl_order_path: Path = ETL_ORDER_PATH,
        data_warehouse_root: Path = DATA_WAREHOUSE_ROOT,
    ) -> None:
        """Store warehouse paths and source discovery settings."""
        self.warehouse_path = warehouse_path
        self.data_root = data_root
        self.stage_chunk_size = stage_chunk_size
        self.etl_order_path = etl_order_path
        self.data_warehouse_root = data_warehouse_root
        self.source_file_profiler = ChaseSourceFileProfiler()

    def populate(self) -> None:
        """Stage private CSV files, execute ETL SQL, and print row counts."""
        source_file_metadata_list = self.source_file_profiler.discover_source_files(
            self.data_root
        )
        if not source_file_metadata_list:
            print(f"no Chase CSV files found under {self.data_root}")
            return

        with duckdb.connect(str(self.warehouse_path)) as duckdb_connection:
            self.create_stage_tables(duckdb_connection)
            self.insert_stage_source_file_metadata(
                duckdb_connection,
                source_file_metadata_list,
            )
            self.load_stage_transactions(
                duckdb_connection,
                source_file_metadata_list,
            )
            self.execute_metadata_etl_scripts(duckdb_connection)
            self.execute_chunked_transaction_etl(duckdb_connection)
            self.print_population_summary(duckdb_connection, source_file_metadata_list)

    def create_stage_tables(self, duckdb_connection: duckdb.DuckDBPyConnection) -> None:
        """Create temporary stage tables used by the SQL ETL scripts."""
        duckdb_connection.execute(
            """
            create temporary table stageSourceFileMetadata (
                sourceFileName varchar,
                sourceFilePath varchar,
                sourceFileHash varchar,
                sourceFileType varchar,
                rowCount integer,
                accountType varchar,
                accountLastFour varchar
            )
            """
        )
        duckdb_connection.execute(
            """
            create temporary table stageChaseCheckingTransactionQueue (
                sourceFileName varchar,
                sourceFileHash varchar,
                sourceFileType varchar,
                sourceRowNumber integer,
                details varchar,
                postingDate varchar,
                description varchar,
                amount varchar,
                type varchar,
                balance varchar,
                checkOrSlipNumber varchar
            )
            """
        )
        duckdb_connection.execute(
            """
            create temporary table stageChaseCreditTransactionQueue (
                sourceFileName varchar,
                sourceFileHash varchar,
                sourceFileType varchar,
                sourceRowNumber integer,
                transactionDate varchar,
                postDate varchar,
                description varchar,
                category varchar,
                type varchar,
                amount varchar,
                memo varchar
            )
            """
        )

    def insert_stage_source_file_metadata(
        self,
        duckdb_connection: duckdb.DuckDBPyConnection,
        source_file_metadata_list: list[SourceFileMetadata],
    ) -> None:
        """Insert file metadata into the temporary source metadata stage table."""
        duckdb_connection.executemany(
            """
            insert into stageSourceFileMetadata (
                sourceFileName,
                sourceFilePath,
                sourceFileHash,
                sourceFileType,
                rowCount,
                accountType,
                accountLastFour
            ) values (?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    source_file_metadata.sourceFileName,
                    str(source_file_metadata.sourceFilePath),
                    source_file_metadata.sourceFileHash,
                    source_file_metadata.sourceFileType,
                    source_file_metadata.rowCount,
                    source_file_metadata.accountType,
                    source_file_metadata.accountLastFour,
                )
                for source_file_metadata in source_file_metadata_list
            ],
        )

    def load_stage_transactions(
        self,
        duckdb_connection: duckdb.DuckDBPyConnection,
        source_file_metadata_list: list[SourceFileMetadata],
    ) -> None:
        """Load source CSV rows into temporary Chase transaction stage tables."""
        for source_file_metadata in source_file_metadata_list:
            if source_file_metadata.sourceFileType == "chaseCheckingCsv":
                self.load_stage_checking_transactions(
                    duckdb_connection,
                    source_file_metadata,
                )
            if source_file_metadata.sourceFileType == "chaseCreditCsv":
                self.load_stage_credit_transactions(
                    duckdb_connection,
                    source_file_metadata,
                )

    def load_stage_checking_transactions(
        self,
        duckdb_connection: duckdb.DuckDBPyConnection,
        source_file_metadata: SourceFileMetadata,
    ) -> None:
        """Load one Chase checking CSV into the temporary checking stage table."""
        source_file_path_literal = SqlLiteral.string(source_file_metadata.sourceFilePath)
        duckdb_connection.execute(
            f"""
            insert into stageChaseCheckingTransactionQueue
            select
                {SqlLiteral.string(source_file_metadata.sourceFileName)} as sourceFileName,
                {SqlLiteral.string(source_file_metadata.sourceFileHash)} as sourceFileHash,
                {SqlLiteral.string(source_file_metadata.sourceFileType)} as sourceFileType,
                row_number() over ()::integer as sourceRowNumber,
                Details as details,
                "Posting Date" as postingDate,
                Description as description,
                Amount as amount,
                Type as type,
                Balance as balance,
                "Check or Slip #" as checkOrSlipNumber
            from read_csv({source_file_path_literal}, header = true, all_varchar = true)
            """
        )

    def load_stage_credit_transactions(
        self,
        duckdb_connection: duckdb.DuckDBPyConnection,
        source_file_metadata: SourceFileMetadata,
    ) -> None:
        """Load one Chase credit-card CSV into the temporary credit stage table."""
        source_file_path_literal = SqlLiteral.string(source_file_metadata.sourceFilePath)
        duckdb_connection.execute(
            f"""
            insert into stageChaseCreditTransactionQueue
            select
                {SqlLiteral.string(source_file_metadata.sourceFileName)} as sourceFileName,
                {SqlLiteral.string(source_file_metadata.sourceFileHash)} as sourceFileHash,
                {SqlLiteral.string(source_file_metadata.sourceFileType)} as sourceFileType,
                row_number() over ()::integer as sourceRowNumber,
                "Transaction Date" as transactionDate,
                "Post Date" as postDate,
                Description as description,
                Category as category,
                Type as type,
                Amount as amount,
                Memo as memo
            from read_csv({source_file_path_literal}, header = true, all_varchar = true)
            """
        )

    def execute_metadata_etl_scripts(
        self,
        duckdb_connection: duckdb.DuckDBPyConnection,
    ) -> None:
        """Execute source-file metadata ETL scripts once before chunk processing."""
        for etl_sql_file_path in self.ordered_etl_sql_files():
            relative_etl_sql_file_path = str(
                etl_sql_file_path.relative_to(self.data_warehouse_root)
            )
            if relative_etl_sql_file_path not in METADATA_ETL_FILES:
                continue
            duckdb_connection.execute(etl_sql_file_path.read_text())
            print(f"processed {relative_etl_sql_file_path}")

    def execute_chunked_transaction_etl(
        self,
        duckdb_connection: duckdb.DuckDBPyConnection,
    ) -> None:
        """Process staged transaction rows in chunks until both queues are empty."""
        processed_chunk_count = 0
        while self.has_queued_transactions(duckdb_connection):
            processed_chunk_count += 1
            self.create_transaction_chunk_tables(duckdb_connection)
            print(
                "processing transaction chunk "
                f"{processed_chunk_count} with up to {self.stage_chunk_size} rows "
                "per source table"
            )
            self.execute_transaction_chunk_etl_scripts(duckdb_connection)
            self.delete_processed_transaction_chunks(duckdb_connection)

    def execute_transaction_chunk_etl_scripts(
        self,
        duckdb_connection: duckdb.DuckDBPyConnection,
    ) -> None:
        """Execute transaction ETL scripts against current chunk temp tables."""
        for etl_sql_file_path in self.ordered_etl_sql_files():
            relative_etl_sql_file_path = str(
                etl_sql_file_path.relative_to(self.data_warehouse_root)
            )
            if relative_etl_sql_file_path in METADATA_ETL_FILES:
                continue
            duckdb_connection.execute(etl_sql_file_path.read_text())
            print(f"processed {relative_etl_sql_file_path}")

    def has_queued_transactions(
        self,
        duckdb_connection: duckdb.DuckDBPyConnection,
    ) -> bool:
        """Return whether any staged transaction rows still need processing."""
        queued_transaction_count = duckdb_connection.execute(
            """
            select
                (select count(*) from stageChaseCheckingTransactionQueue)
                + (select count(*) from stageChaseCreditTransactionQueue)
            """
        ).fetchone()[0]
        return queued_transaction_count > 0

    def create_transaction_chunk_tables(
        self,
        duckdb_connection: duckdb.DuckDBPyConnection,
    ) -> None:
        """Create temp tables containing the next staged transaction chunk."""
        duckdb_connection.execute("drop table if exists stageChaseCheckingTransaction")
        duckdb_connection.execute("drop table if exists stageChaseCreditTransaction")
        duckdb_connection.execute(
            """
            create temporary table stageChaseCheckingTransaction as
            select *
            from stageChaseCheckingTransactionQueue
            order by sourceFileHash, sourceRowNumber
            limit ?
            """,
            (self.stage_chunk_size,),
        )
        duckdb_connection.execute(
            """
            create temporary table stageChaseCreditTransaction as
            select *
            from stageChaseCreditTransactionQueue
            order by sourceFileHash, sourceRowNumber
            limit ?
            """,
            (self.stage_chunk_size,),
        )

    def delete_processed_transaction_chunks(
        self,
        duckdb_connection: duckdb.DuckDBPyConnection,
    ) -> None:
        """Remove processed chunk rows from the staging queues."""
        duckdb_connection.execute(
            """
            delete from stageChaseCheckingTransactionQueue as stagedTransactionQueue
            using stageChaseCheckingTransaction as processedTransactionChunk
            where stagedTransactionQueue.sourceFileHash = processedTransactionChunk.sourceFileHash
              and stagedTransactionQueue.sourceRowNumber = processedTransactionChunk.sourceRowNumber
            """
        )
        duckdb_connection.execute(
            """
            delete from stageChaseCreditTransactionQueue as stagedTransactionQueue
            using stageChaseCreditTransaction as processedTransactionChunk
            where stagedTransactionQueue.sourceFileHash = processedTransactionChunk.sourceFileHash
              and stagedTransactionQueue.sourceRowNumber = processedTransactionChunk.sourceRowNumber
            """
        )

    def ordered_etl_sql_files(self) -> list[Path]:
        """Read etlOrder.txt and return ETL SQL files in execution order."""
        ordered_sql_files: list[Path] = []
        for manifest_line in self.etl_order_path.read_text().splitlines():
            stripped_manifest_line = manifest_line.strip()
            if not stripped_manifest_line or stripped_manifest_line.startswith("#"):
                continue
            ordered_sql_files.append(
                self.data_warehouse_root / "ETL" / stripped_manifest_line
            )
        return ordered_sql_files

    def print_population_summary(
        self,
        duckdb_connection: duckdb.DuckDBPyConnection,
        source_file_metadata_list: list[SourceFileMetadata],
    ) -> None:
        """Print source and warehouse row counts after ETL completes."""
        print("population summary")
        print(f"  source files read: {len(source_file_metadata_list)}")
        print(
            "  source rows read: "
            f"{sum(source_file_metadata.rowCount for source_file_metadata in source_file_metadata_list)}"
        )
        for qualified_table_name in self.summary_table_names():
            row_count = duckdb_connection.execute(
                f"select count(*) from {qualified_table_name}"
            ).fetchone()[0]
            print(f"  {qualified_table_name}: {row_count} rows")

    @staticmethod
    def summary_table_names() -> list[str]:
        """Return warehouse objects included in population summary logs."""
        return [
            "Bronze.rawChaseCheckingTransaction",
            "Bronze.rawChaseCreditTransaction",
            "Silver.dimSourceFile",
            "Silver.dimFinancialAccount",
            "Silver.dimMerchant",
            "Silver.dimCalendarDate",
            "Silver.mapMerchantRule",
            "Silver.mapCategoryRule",
            "Silver.factTransaction",
        ]


def populate_warehouse(
    warehouse_path: Path,
    data_root: Path,
    stage_chunk_size: int = DEFAULT_STAGE_CHUNK_SIZE,
) -> None:
    """Populate the warehouse by staging CSVs and running DuckDB SQL ETL scripts."""
    DuckDbEtlRunner(warehouse_path, data_root, stage_chunk_size).populate()


def build_argument_parser() -> argparse.ArgumentParser:
    """Create the command-line parser for direct population runs."""
    argument_parser = argparse.ArgumentParser(
        description="Populate the DuckDB data warehouse."
    )
    argument_parser.add_argument(
        "--warehouse",
        type=Path,
        default=DEFAULT_WAREHOUSE_PATH,
        help="Path to the DuckDB database file.",
    )
    argument_parser.add_argument(
        "--data-root",
        type=Path,
        default=DEFAULT_DATA_ROOT,
        help="Directory containing private Chase CSV exports.",
    )
    argument_parser.add_argument(
        "--stage-chunk-size",
        type=int,
        default=DEFAULT_STAGE_CHUNK_SIZE,
        help="Maximum staged transaction rows to process per source table per chunk.",
    )
    return argument_parser


def main() -> None:
    """Parse CLI arguments and run the DuckDB SQL ETL workflow."""
    parsed_arguments = build_argument_parser().parse_args()
    populate_warehouse(
        parsed_arguments.warehouse,
        parsed_arguments.data_root,
        parsed_arguments.stage_chunk_size,
    )


if __name__ == "__main__":
    main()
