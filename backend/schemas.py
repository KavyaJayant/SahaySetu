from pydantic import BaseModel, EmailStr
from datetime import datetime


class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    id: int
    user_id: str
    name: str
    email: EmailStr
    role: str
    is_active: int

    class Config:
        from_attributes = True

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class ComplaintCreate(BaseModel):
    description: str
    category: str
    severity: str

    latitude: float
    longitude: float

    photo_url: str | None = None
    audio_url: str | None = None


class ComplaintResponse(BaseModel):
    id: int
    complaint_id: str

    description: str
    category: str
    severity: str

    latitude: float
    longitude: float

    photo_url: str | None = None
    audio_url: str | None = None

    status: str

    ai_category: str | None = None
    ai_confidence: float | None = None

    created_at: datetime

    class Config:
        from_attributes = True

class ComplaintAssignment(BaseModel):
    worker_id: int

class ComplaintStatusUpdate(BaseModel):
    status: str

class RecoveryObservationCreate(BaseModel):
    incident_id: str
    intervention_id: str
    recovery_score: float
    evidence: str | None = None
    notes: str | None = None


class RecoveryObservationResponse(BaseModel):
    id: int
    incident_id: str
    intervention_id: str | None
    observation_status: str
    recovery_score: float | None
    observed_at: datetime
    evidence: str | None
    notes: str | None

    class Config:
        from_attributes = True

class InterventionCreate(BaseModel):
    intervention_type: str
    expected_impact_score: float | None = None
    notes: str | None = None


class InterventionResponse(BaseModel):
    id: int
    intervention_id: str
    incident_id: str
    intervention_type: str
    status: str
    expected_impact_score: float | None
    started_at: datetime | None
    completed_at: datetime | None
    notes: str | None

class InterventionStatusUpdate(BaseModel):
    status: str