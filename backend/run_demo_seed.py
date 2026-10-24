"""Safely prepare demo accounts in the isolated local test database.

Run from the backend directory with:
    .\\.venv\\Scripts\\python.exe run_demo_seed.py

This launcher never creates a database or runs migrations. It derives only the
credentials from the configured URL, pins the target to local
sahaysetu_mvp_test, verifies the connected server and Alembic head before
writing, and invokes the existing worker seeder as a child process.

The demo password below is a test-fixture password, not a production secret.
"""

from __future__ import annotations

import ipaddress
import os
import subprocess
import sys
import uuid
from contextlib import contextmanager
from pathlib import Path

import sqlalchemy as sa
from dotenv import load_dotenv
from sqlalchemy.engine import URL, make_url
from sqlalchemy.orm import Session


TARGET_DATABASE = "sahaysetu_mvp_test"
TARGET_HOST = "127.0.0.1"
TARGET_PORT = 5432
EXPECTED_REVISION = "2bc7e4d9a610"
DEMO_PASSWORD = "correct-horse-battery"
ROAD_CATEGORY = "Pothole & Road Damage"
BACKEND_DIRECTORY = Path(__file__).resolve().parent
SEED_SCRIPT = BACKEND_DIRECTORY / "seed_demo_workers.py"


class DemoSeedError(Exception):
    """A safe-to-display test database setup failure."""


@contextmanager
def without_libpq_environment():
    removed = {
        key: os.environ.pop(key)
        for key in tuple(os.environ)
        if key.upper().startswith("PG")
    }
    try:
        yield
    finally:
        os.environ.update(removed)


def safe_database_error(error: Exception) -> str:
    original = getattr(error, "orig", None) or error
    sqlstate = (
        getattr(original, "sqlstate", None)
        or getattr(original, "pgcode", None)
    )
    diagnostic = getattr(original, "diag", None)
    primary = getattr(diagnostic, "message_primary", None)
    message = f"{type(original).__name__}"
    if sqlstate:
        message += f", SQLSTATE {sqlstate}"
    if primary:
        message += f": {primary}"
    return message


def target_url() -> URL:
    load_dotenv(BACKEND_DIRECTORY / ".env", override=False)
    configured = os.environ.get("DATABASE_URL")
    if not configured:
        raise DemoSeedError("DATABASE_URL is not configured; no changes made.")

    try:
        source = make_url(configured)
    except Exception as error:
        raise DemoSeedError(
            f"DATABASE_URL could not be parsed ({type(error).__name__}); "
            "its value is withheld."
        ) from None

    if source.drivername.split("+", 1)[0] != "postgresql":
        raise DemoSeedError("Only PostgreSQL is allowed; no changes made.")
    if source.host not in {"localhost", TARGET_HOST} or source.port != TARGET_PORT:
        raise DemoSeedError(
            "Configured credentials are not for the approved local PostgreSQL "
            "instance; no changes made."
        )
    if source.query:
        raise DemoSeedError(
            "DATABASE_URL query parameters are not allowed; no changes made."
        )

    target = source.set(
        host=TARGET_HOST,
        port=TARGET_PORT,
        database=TARGET_DATABASE,
        query={},
    )
    if (
        target.host != TARGET_HOST
        or target.port != TARGET_PORT
        or target.database != TARGET_DATABASE
        or target.username != source.username
        or target.password != source.password
        or target.drivername != source.drivername
        or target.query
    ):
        raise DemoSeedError("Test database target validation failed.")
    return target


def verify_target(connection: sa.Connection) -> None:
    database, address, port = connection.execute(
        sa.text(
            "SELECT current_database(), inet_server_addr()::text, "
            "inet_server_port()"
        )
    ).one()
    try:
        server_ip = ipaddress.ip_interface(address).ip if address else None
    except ValueError:
        server_ip = None

    if (
        database != TARGET_DATABASE
        or server_ip != ipaddress.IPv4Address(TARGET_HOST)
        or port != TARGET_PORT
    ):
        raise DemoSeedError(
            "Connected database/server is not the approved local test target."
        )


def verify_revision(connection: sa.Connection) -> None:
    revision = connection.execute(
        sa.text("SELECT version_num FROM public.alembic_version")
    ).scalar_one_or_none()
    if revision != EXPECTED_REVISION:
        raise DemoSeedError(
            "Test database is not at the required Alembic revision; no seed run."
        )


def inspect_target(engine: sa.Engine) -> bool:
    with without_libpq_environment():
        with engine.connect() as connection:
            with connection.begin():
                connection.exec_driver_sql("SET TRANSACTION READ ONLY")
                verify_target(connection)
                verify_revision(connection)
                return connection.execute(
                    sa.text(
                        """
                        SELECT EXISTS (
                            SELECT 1
                            FROM public.users
                            WHERE email = 'demo.worker.roads1@example.com'
                              AND role = 'WORKER'
                              AND is_active = 1
                              AND worker_category = :category
                              AND is_demo_worker IS TRUE
                        )
                        """
                    ),
                    {"category": ROAD_CATEGORY},
                ).scalar_one()


def seed_workers(engine: sa.Engine, url: URL, existing_worker: bool) -> None:
    if existing_worker:
        return

    child_environment = {
        key: value
        for key, value in os.environ.items()
        if not key.upper().startswith("PG")
    }
    child_environment["DATABASE_URL"] = url.render_as_string(
        hide_password=False
    )
    try:
        result = subprocess.run(
            [sys.executable, str(SEED_SCRIPT)],
            cwd=BACKEND_DIRECTORY,
            env=child_environment,
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError as error:
        raise DemoSeedError(
            f"Could not start worker seeder ({type(error).__name__})."
        ) from None
    if result.returncode != 0:
        raise DemoSeedError(
            f"Worker seeder failed (exit code {result.returncode}); "
            "child output is withheld."
        )

    # Confirm the child still used the same approved target before later writes.
    with without_libpq_environment():
        with engine.connect() as connection:
            with connection.begin():
                connection.exec_driver_sql("SET TRANSACTION READ ONLY")
                verify_target(connection)
                verify_revision(connection)


def create_demo_accounts(engine: sa.Engine) -> None:
    # Set the process-local URL before importing models, whose database module
    # creates an engine at import time.
    load_dotenv(BACKEND_DIRECTORY / ".env", override=False)
    os.environ["DATABASE_URL"] = engine.url.render_as_string(hide_password=False)
    from models import User
    from security import hash_password

    accounts = (
        (
            "demo.citizen@example.com",
            "SahaySetu Demo Citizen",
            "CITIZEN",
            "CIT-DEMO-",
            "demo.citizen@sahaysetu-demo.invalid",
        ),
        (
            "demo.authority@example.com",
            "SahaySetu Demo Authority",
            "AUTHORITY",
            "AUT-DEMO-",
            "demo.authority@sahaysetu-demo.invalid",
        ),
    )

    with without_libpq_environment():
        with Session(engine) as session:
            with session.begin():
                connection = session.connection()
                verify_target(connection)
                verify_revision(connection)

                for email, name, role, user_id_prefix, legacy_email in accounts:
                    user = session.query(User).filter(User.email == email).first()
                    legacy_user = session.query(User).filter(
                        User.email == legacy_email
                    ).first()
                    if user is not None and legacy_user is not None:
                        raise DemoSeedError(
                            "Both current and legacy demo accounts exist; "
                            "refusing to choose between them."
                        )
                    if user is None:
                        user = legacy_user
                    if user is None:
                        session.add(
                            User(
                                user_id=(
                                    f"{user_id_prefix}"
                                    f"{uuid.uuid4().hex[:10].upper()}"
                                ),
                                name=name,
                                email=email,
                                password_hash=hash_password(DEMO_PASSWORD),
                                role=role,
                                is_active=1,
                            )
                        )
                    elif user.name == name and user.role == role:
                        user.email = email
                        user.password_hash = hash_password(DEMO_PASSWORD)
                        user.is_active = 1
                    else:
                        raise DemoSeedError(
                            "A reserved demo account email conflicts with an "
                            "existing user; refusing to modify it."
                        )

                worker = session.query(User).filter(
                    User.email == "demo.worker.roads1@example.com"
                ).first()
                legacy_worker = session.query(User).filter(
                    User.email == "demo.worker.roads1@sahaysetu-demo.invalid"
                ).first()
                if worker is not None and legacy_worker is not None:
                    raise DemoSeedError(
                        "Both current and legacy road demo workers exist; "
                        "refusing to choose between them."
                    )
                if worker is None:
                    worker = legacy_worker
                if (
                    worker is None
                    or worker.role != "WORKER"
                    or not worker.is_demo_worker
                    or worker.worker_category != ROAD_CATEGORY
                ):
                    raise DemoSeedError(
                        "The expected seeded road demo worker was not found."
                    )
                worker.email = "demo.worker.roads1@example.com"
                worker.password_hash = hash_password(DEMO_PASSWORD)
                worker.is_active = 1


def main() -> None:
    url = target_url()
    engine = None
    try:
        with without_libpq_environment():
            engine = sa.create_engine(
                url,
                connect_args={"hostaddr": TARGET_HOST},
                hide_parameters=True,
            )
            has_demo_road_worker = inspect_target(engine)
            seed_workers(engine, url, has_demo_road_worker)
            create_demo_accounts(engine)

            with engine.connect() as connection:
                with connection.begin():
                    connection.exec_driver_sql("SET TRANSACTION READ ONLY")
                    verify_target(connection)
                    verify_revision(connection)
                    counts = connection.execute(
                        sa.text(
                            """
                            SELECT
                                count(*) FILTER (
                                    WHERE role = 'CITIZEN'
                                      AND email = 'demo.citizen@example.com'
                                ),
                                count(*) FILTER (
                                    WHERE role = 'AUTHORITY'
                                      AND email = 'demo.authority@example.com'
                                ),
                                count(*) FILTER (
                                    WHERE role = 'WORKER'
                                      AND is_active = 1
                                      AND worker_category = :category
                                      AND is_demo_worker IS TRUE
                                )
                            FROM public.users
                            """
                        ),
                        {"category": ROAD_CATEGORY},
                    ).one()
            if counts[0] != 1 or counts[1] != 1 or counts[2] < 1:
                raise DemoSeedError(
                    "Post-seed verification did not find the required demo "
                    "accounts."
                )
    except DemoSeedError:
        raise
    except Exception as error:
        raise DemoSeedError(
            f"Test database setup failed ({safe_database_error(error)}); "
            "connection details are withheld."
        ) from None
    finally:
        if engine is not None:
            engine.dispose()

    print("Verified demo accounts are ready in sahaysetu_mvp_test.")
    print("No migration was run and the original sahaysetu database was not targeted.")
    print("Demo credential values are intentionally not printed.")


if __name__ == "__main__":
    try:
        main()
    except DemoSeedError as error:
        print(f"Demo setup stopped: {error}", file=sys.stderr)
        raise SystemExit(1) from None
