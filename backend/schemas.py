from pydantic import BaseModel, EmailStr, Field, field_validator
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
    worker_category: str | None = None

    class Config:
        from_attributes = True

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class ComplaintCreate(BaseModel):
    description: str = Field(min_length=10, max_length=2000)
    category: str = Field(min_length=1, max_length=100)
    severity: str = Field(min_length=1, max_length=32)

    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)

    photo_url: str | None = None
    audio_url: str | None = None

    @field_validator("description", "category", "severity")
    @classmethod
    def reject_blank_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("This field cannot be blank")
        return value

    @field_validator("description")
    @classmethod
    def require_meaningful_description(cls, value: str) -> str:
        if len(value) < 10:
            raise ValueError("Description must be at least 10 characters")
        return value


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
    assigned_worker_id: int | None = None
    assigned_worker_name: str | None = None
    incident_id: int | None = None
    user_id: int | None = None

    ai_category: str | None = None
    ai_confidence: float | None = None

    created_at: datetime

    class Config:
        from_attributes = True


class ComplaintStatusHistoryResponse(BaseModel):
    id: int
    event_type: str
    status: str
    changed_at: datetime
    assigned_worker_id: int | None = None

    class Config:
        from_attributes = True


class CitizenVerificationResponse(BaseModel):
    id: int
    result: str
    feedback: str | None = None
    submitted_at: datetime
    evidence_available: bool


class ComplaintDetailResponse(ComplaintResponse):
    status_history: list[ComplaintStatusHistoryResponse] = Field(
        default_factory=list
    )
    verification: CitizenVerificationResponse | None = None
    verification_eligible: bool = False


class WorkerResponse(BaseModel):
    id: int
    name: str
    role: str
    is_active: int
    worker_category: str | None = None
    is_demo_worker: bool = False
    assigned_complaint_count: int = 0

    class Config:
        from_attributes = True


class EligibleWorkersResponse(BaseModel):
    complaint_id: str
    complaint_category: str | None = None
    category: str | None = None
    assigned_worker_id: int | None = None
    assigned_worker_name: str | None = None
    workers: list[WorkerResponse]


class ComplaintAssignment(BaseModel):
    worker_id: int = Field(gt=0)

class ComplaintStatusUpdate(BaseModel):
    status: str

class RecoveryObservationCreate(BaseModel):
    incident_id: str
    intervention_id: str
    recovery_score: float = Field(ge=0, le=100)
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
    expected_impact_score: float | None = Field(default=None, ge=0, le=100)
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