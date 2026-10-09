import uuid
from datetime import datetime, timedelta, timezone

import jwt
from sqlalchemy.orm import Session

from models import User
from schemas import UserCreate
from security import hash_password, verify_password
from auth_config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_MINUTES


def register_user(user_data: UserCreate, db: Session):
    existing_user = db.query(User).filter(
        User.email == user_data.email
    ).first()

    if existing_user:
        return None

    new_user = User(
        user_id=f"USR-{uuid.uuid4().hex[:8].upper()}",
        name=user_data.name,
        email=user_data.email,
        password_hash=hash_password(user_data.password),
        role="CITIZEN",
        is_active=1
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return new_user


def authenticate_user(email: str, password: str, db: Session):
    user = db.query(User).filter(User.email == email).first()

    if not user:
        return None

    if not user.is_active:
        return None

    if not verify_password(password, user.password_hash):
        return None

    return user


def create_access_token(user: User):
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=ACCESS_TOKEN_EXPIRE_MINUTES
    )

    payload = {
        "sub": str(user.id),
        "user_id": user.user_id,
        "role": user.role,
        "exp": expire
    }

    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
    