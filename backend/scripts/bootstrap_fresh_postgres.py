"""Bootstrap a fresh SahaySetu PostgreSQL test database.

This is an inferred fresh-install baseline, not an authoritative reconstruction
of the original database schema and not an Alembic revision. Run from the
backend directory with:

    python scripts\bootstrap_fresh_postgres.py

The script loads backend/.env without overriding process environment variables.
It always targets sahaysetu_mvp_test on localhost:5432, refuses any existing
user-schema objects, and never creates the database itself. After bootstrap,
run the normal Alembic upgrade separately against the same verified database.
"""

from __future__ import annotations

import os
import sys
import ipaddress
from contextlib import contextmanager
from pathlib import Path

import sqlalchemy as sa
from dotenv import load_dotenv
from sqlalchemy import ForeignKey
from sqlalchemy.engine import make_url
from sqlalchemy.schema import CreateIndex, CreateTable


TARGET_DATABASE = "sahaysetu_mvp_test"
APPROVED_HOST = "localhost"
APPROVED_PORT = 5432
APPROVED_HOSTADDR = "127.0.0.1"
BACKEND_DIRECTORY = Path(__file__).resolve().parents[1]
BLOCKED_URL_PARAMETERS = {
    "database",
    "dbname",
    "host",
    "hostaddr",
    "password",
    "port",
    "service",
    "servicefile",
    "user",
}


class BootstrapError(Exception):
    """A safe-to-display bootstrap validation failure."""


def build_tables() -> tuple[sa.Table, ...]:
    metadata = sa.MetaData()

    users = sa.Table(
        "users",
        metadata,
        sa.Column("id", sa.Integer(), sa.Identity(always=False), primary_key=True),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("email", sa.String(), nullable=False),
        sa.Column("role", sa.String(), nullable=False),
    )
    incidents = sa.Table(
        "incidents",
        metadata,
        sa.Column("id", sa.Integer(), sa.Identity(always=False), primary_key=True),
        sa.Column("incident_id", sa.String(), nullable=False),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("description", sa.String(), nullable=True),
        sa.Column("incident_type", sa.String(), nullable=False),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("fusion_score", sa.Float(), nullable=True),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
    )
    complaints = sa.Table(
        "complaints",
        metadata,
        sa.Column("id", sa.Integer(), sa.Identity(always=False), primary_key=True),
        sa.Column("complaint_id", sa.String(), nullable=False),
        sa.Column("user_id", sa.Integer(), ForeignKey("users.id"), nullable=False),
        sa.Column("description", sa.String(), nullable=False),
        sa.Column("category", sa.String(), nullable=False),
        sa.Column("severity", sa.String(), nullable=False),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.Column("photo_url", sa.String(), nullable=True),
        sa.Column("audio_url", sa.String(), nullable=True),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("ai_category", sa.String(), nullable=True),
        sa.Column("ai_confidence", sa.Float(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
    )

    sa.Index("ix_users_user_id", users.c.user_id, unique=True)
    sa.Index("ix_users_email", users.c.email, unique=True)
    sa.Index("ix_incidents_incident_id", incidents.c.incident_id, unique=True)
    sa.Index(
        "ix_complaints_complaint_id",
        complaints.c.complaint_id,
        unique=True,
    )
    return users, incidents, complaints


def verified_target_url():
    load_dotenv(dotenv_path=BACKEND_DIRECTORY / ".env", override=False)
    configured_url = os.environ.get("DATABASE_URL")
    if not configured_url:
        raise BootstrapError(
            "DATABASE_URL is not configured in the process environment or backend/.env."
        )

    try:
        source_url = make_url(configured_url)
    except Exception as error:
        raise BootstrapError(
            f"DATABASE_URL could not be parsed ({type(error).__name__}); "
            "the value is withheld."
        ) from None

    target_url = source_url.set(database=TARGET_DATABASE)
    preserved_fields = (
        "username",
        "password",
        "host",
        "port",
        "drivername",
        "query",
    )
    if any(
        getattr(source_url, field) != getattr(target_url, field)
        for field in preserved_fields
    ):
        raise BootstrapError("A non-database connection setting changed.")
    if target_url.database != TARGET_DATABASE:
        raise BootstrapError("The database name is not the approved test target.")
    if target_url.drivername.split("+", 1)[0] != "postgresql":
        raise BootstrapError("Only a PostgreSQL connection is allowed.")
    if target_url.host != APPROVED_HOST or target_url.port != APPROVED_PORT:
        raise BootstrapError(
            "The connection must use the approved localhost:5432 PostgreSQL target."
        )
    if BLOCKED_URL_PARAMETERS.intersection(
        str(key).lower() for key in target_url.query
    ):
        raise BootstrapError(
            "Connection query parameters may not override the approved target "
            "or credentials."
        )
    return target_url


@contextmanager
def without_libpq_environment():
    """Prevent inherited libpq variables from changing connection parameters."""
    removed = {
        key: os.environ.pop(key)
        for key in tuple(os.environ)
        if key.upper().startswith("PG")
    }
    try:
        yield
    finally:
        os.environ.update(removed)


def database_error_message(error: Exception) -> str:
    driver_error = getattr(error, "orig", None) or error
    error_class = type(driver_error).__name__
    sqlstate = (
        getattr(driver_error, "sqlstate", None)
        or getattr(driver_error, "pgcode", None)
    )
    diagnostic = getattr(driver_error, "diag", None)
    primary_message = getattr(diagnostic, "message_primary", None)

    message = f"PostgreSQL bootstrap failed ({error_class}"
    if sqlstate:
        message += f", SQLSTATE {sqlstate}"
    message += ")"
    if primary_message:
        message += f": {primary_message}"
    return message + "."


def refuse_nonempty_database(connection: sa.Connection) -> None:
    database_name, server_address, server_port = connection.execute(
        sa.text(
            "SELECT current_database(), inet_server_addr()::text, "
            "inet_server_port()"
        )
    ).one()
    if database_name != TARGET_DATABASE:
        raise BootstrapError(
            "The connected database identity does not match the approved test target."
        )
    try:
        is_approved_server_address = (
            server_address is not None
            and ipaddress.ip_interface(server_address).ip
            == ipaddress.IPv4Address(APPROVED_HOSTADDR)
        )
    except ValueError:
        is_approved_server_address = False
    if not is_approved_server_address or server_port != APPROVED_PORT:
        raise BootstrapError(
            "The connected PostgreSQL server is not the approved local instance."
        )

    current_schema = connection.execute(
        sa.text("SELECT current_schema()")
    ).scalar_one()
    if current_schema != "public":
        raise BootstrapError(
            "The connection search path does not resolve to the public schema."
        )

    nonstandard_schema_exists = connection.execute(
        sa.text(
            """
            SELECT EXISTS (
                SELECT 1
                FROM pg_catalog.pg_namespace
                WHERE nspname NOT IN (
                    'public',
                    'pg_catalog',
                    'information_schema',
                    'pg_toast'
                )
            )
            """
        )
    ).scalar_one()
    if nonstandard_schema_exists:
        raise BootstrapError(
            "The target contains a nonstandard user schema; refusing to reuse it."
        )

    alembic_version_exists = connection.execute(
        sa.text("SELECT to_regclass('public.alembic_version') IS NOT NULL")
    ).scalar_one()
    if alembic_version_exists:
        raise BootstrapError(
            "The target already has an alembic_version table; refusing to reuse it."
        )

    existing_relations = connection.execute(
        sa.text(
            """
            SELECT namespace.nspname, relation.relname
            FROM pg_catalog.pg_class AS relation
            JOIN pg_catalog.pg_namespace AS namespace
              ON namespace.oid = relation.relnamespace
            WHERE namespace.nspname NOT IN (
                'pg_catalog',
                'information_schema',
                'pg_toast'
            )
              AND relation.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
            ORDER BY namespace.nspname, relation.relname
            LIMIT 1
            """
        )
    ).first()
    if existing_relations:
        raise BootstrapError(
            "The target contains an existing user-schema relation; refusing to "
            "repair or reuse a non-empty database."
        )

    existing_types = connection.execute(
        sa.text(
            """
            SELECT type_row.typname
            FROM pg_catalog.pg_type AS type_row
            JOIN pg_catalog.pg_namespace AS namespace
              ON namespace.oid = type_row.typnamespace
            WHERE namespace.nspname NOT IN (
                'pg_catalog',
                'information_schema',
                'pg_toast'
            )
              AND type_row.typtype IN ('b', 'c', 'd', 'e', 'm', 'p', 'r')
            LIMIT 1
            """
        )
    ).first()
    if existing_types:
        raise BootstrapError(
            "The target contains an existing user-defined type; refusing to "
            "repair or reuse a partially initialized database."
        )

    existing_routine = connection.execute(
        sa.text(
            """
            SELECT 1
            FROM pg_catalog.pg_proc AS routine
            JOIN pg_catalog.pg_namespace AS namespace
              ON namespace.oid = routine.pronamespace
            WHERE namespace.nspname = 'public'
              AND routine.prokind IN ('f', 'p', 'a', 'w')
            LIMIT 1
            """
        )
    ).first()
    if existing_routine:
        raise BootstrapError(
            "The target contains an existing user-defined routine; refusing to "
            "reuse a partially initialized database."
        )


def bootstrap() -> None:
    target_url = verified_target_url()
    engine = None
    try:
        engine = sa.create_engine(
            target_url,
            connect_args={"hostaddr": APPROVED_HOSTADDR},
            hide_parameters=True,
        )
        with without_libpq_environment():
            with engine.begin() as connection:
                refuse_nonempty_database(connection)

                users, incidents, complaints = build_tables()
                for table in (users, incidents, complaints):
                    connection.execute(CreateTable(table))
                    for index in table.indexes:
                        connection.execute(CreateIndex(index))
    except BootstrapError:
        raise
    except Exception as error:
        raise BootstrapError(database_error_message(error)) from None
    finally:
        if engine is not None:
            engine.dispose()

    print(f"Fresh baseline created in database {TARGET_DATABASE}.")
    print("No Alembic revision was stamped or applied.")


if __name__ == "__main__":
    try:
        bootstrap()
    except BootstrapError as error:
        print(f"Bootstrap refused or failed: {error}", file=sys.stderr)
        raise SystemExit(1) from None
