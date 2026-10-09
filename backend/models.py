from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from database import Base
from datetime import datetime


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, unique=True, nullable=False, index=True)

    name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False, index=True)

    password_hash = Column(String, nullable=False)

    role = Column(String, nullable=False)

    is_active = Column(Integer, nullable=False, default=1)


class Complaint(Base):
    __tablename__ = "complaints"

    id = Column(Integer, primary_key=True, index=True)
    complaint_id = Column(String, unique=True, nullable=False, index=True)

    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    assigned_worker_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=True
    )

    incident_id = Column(
    Integer,
    ForeignKey("incidents.id"),
    nullable=True
)
    
    description = Column(String, nullable=False)
    category = Column(String, nullable=False)
    severity = Column(String, nullable=False)

    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)

    photo_url = Column(String, nullable=True)
    audio_url = Column(String, nullable=True)

    status = Column(String, nullable=False, default="SUBMITTED")

    ai_category = Column(String, nullable=True)
    ai_confidence = Column(Float, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)

class Infrastructure(Base):
    __tablename__ = "infrastructure"

    id = Column(Integer, primary_key=True, index=True)
    infrastructure_id = Column(
        String, unique=True, nullable=False, index=True
    )

    name = Column(String, nullable=False)
    type = Column(String, nullable=False)

    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)

    status = Column(String, nullable=False, default="ACTIVE")


class Incident(Base):
    __tablename__ = "incidents"

    id = Column(Integer, primary_key=True, index=True)
    incident_id = Column(String, unique=True, nullable=False, index=True)

    title = Column(String, nullable=False)
    description = Column(String, nullable=True)
    incident_type = Column(String, nullable=False)

    status = Column(String, nullable=False, default="DETECTED")

    fusion_score = Column(Float, nullable=True)

    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)

    created_at = Column(DateTime, default=datetime.utcnow)

class Intervention(Base):
    __tablename__ = "interventions"

    id = Column(Integer, primary_key=True, index=True)

    intervention_id = Column(
        String,
        unique=True,
        nullable=False,
        index=True
    )

    incident_id = Column(
        Integer,
        ForeignKey("incidents.id"),
        nullable=False
    )

    intervention_type = Column(
        String,
        nullable=False
    )

    status = Column(
        String,
        nullable=False,
        default="PLANNED"
    )

    expected_impact_score = Column(
        Float,
        nullable=True
    )

    started_at = Column(
        DateTime,
        nullable=True
    )

    completed_at = Column(
        DateTime,
        nullable=True
    )

    notes = Column(
        String,
        nullable=True
    )


class RecoveryObservation(Base):
    __tablename__ = "recovery_observations"

    id = Column(
        Integer,
        primary_key=True,
        index=True
    )

    incident_id = Column(
        Integer,
        ForeignKey("incidents.id"),
        nullable=False
    )
    
    intervention_id = Column(
    Integer,
    ForeignKey("interventions.id"),
    nullable=True
    )

    observation_status = Column(
        String,
        nullable=False
    )

    recovery_score = Column(
        Float,
        nullable=True
    )

    observed_at = Column(
        DateTime,
        default=datetime.utcnow
    )

    evidence = Column(
        String,
        nullable=True
    )

    notes = Column(
        String,
        nullable=True
    )