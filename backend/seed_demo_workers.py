"""Create the ten category-specific authority-portal demo workers idempotently."""

import secrets
import uuid

from sqlalchemy.exc import SQLAlchemyError

from category_mapping import CATEGORY_LABELS
from database import SessionLocal
from models import User
from security import hash_password


DEMO_WORKERS = (
    ("Demo Worker — Roads 1", "Pothole & Road Damage", "roads1"),
    ("Demo Worker — Roads 2", "Pothole & Road Damage", "roads2"),
    ("Demo Worker — Streetlights 1", "Broken Streetlight", "streetlights1"),
    ("Demo Worker — Streetlights 2", "Broken Streetlight", "streetlights2"),
    ("Demo Worker — Garbage 1", "Garbage Accumulation", "garbage1"),
    ("Demo Worker — Garbage 2", "Garbage Accumulation", "garbage2"),
    ("Demo Worker — Water 1", "Water Leakage", "water1"),
    ("Demo Worker — Water 2", "Water Leakage", "water2"),
    ("Demo Worker — Drainage 1", "Blocked Drainage", "drainage1"),
    ("Demo Worker — Drainage 2", "Blocked Drainage", "drainage2"),
)


def seed_demo_workers() -> int:
    db = SessionLocal()
    created = 0

    try:
        for name, category, key in DEMO_WORKERS:
            email = f"demo.worker.{key}@sahaysetu-demo.invalid"
            worker = db.query(User).filter(User.email == email).first()

            if worker is None:
                matches = db.query(User).filter(
                    User.role == "WORKER",
                    User.is_demo_worker.is_(True),
                    User.name == name,
                    User.worker_category == category,
                ).all()

                if len(matches) > 1:
                    raise RuntimeError(
                        f"Multiple demo workers match {name!r}; "
                        "resolve duplicates before seeding."
                    )

                worker = matches[0] if matches else None

            if worker is not None:
                if (
                    worker.role != "WORKER"
                    or not worker.is_demo_worker
                    or worker.name != name
                    or worker.worker_category != category
                ):
                    raise RuntimeError(
                        f"Seed identity conflicts with an existing account: {email}"
                    )
                continue

            db.add(
                User(
                    user_id=f"DEMO-WRK-{uuid.uuid4().hex[:10].upper()}",
                    name=name,
                    email=email,
                    password_hash=hash_password(secrets.token_urlsafe(32)),
                    role="WORKER",
                    is_active=1,
                    worker_category=category,
                    is_demo_worker=True,
                )
            )
            created += 1

        db.commit()
        demo_workers = db.query(User).filter(
            User.role == "WORKER",
            User.is_demo_worker.is_(True),
            User.name.in_([name for name, _, _ in DEMO_WORKERS]),
        ).all()

        counts = {
            category: sum(
                1 for worker in demo_workers
                if worker.worker_category == category
            )
            for category in CATEGORY_LABELS
        }

        if len(demo_workers) != len(DEMO_WORKERS) or any(
            count != 2 for count in counts.values()
        ):
            raise RuntimeError(
                f"Expected exactly two demo workers per category; found {counts}"
            )

        return created
    except (SQLAlchemyError, RuntimeError):
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    print(f"Created {seed_demo_workers()} demo workers.")
