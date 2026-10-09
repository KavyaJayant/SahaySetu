from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime

from sqlalchemy.orm import Session

from database import SessionLocal
from schemas import (
    UserCreate,
    UserResponse,
    UserLogin,
    ComplaintCreate,
    ComplaintResponse,
    ComplaintAssignment,
    ComplaintStatusUpdate,
    RecoveryObservationCreate,
    RecoveryObservationResponse,
    InterventionCreate,
    InterventionResponse,
    InterventionStatusUpdate
)
from auth import register_user, authenticate_user, create_access_token
from dependencies import get_current_user
from models import (
    User,
    Complaint,
    Incident,
    Intervention,
    RecoveryObservation
)
from authorization import require_role
import uuid
from security import hash_password
from incident_fusion import (
    find_related_complaints,
    calculate_distance_meters
)
from civic_relationship import analyze_relationships
from intervention_impact import assess_interventions
from recovery_monitoring import create_recovery_observation
from recurrence_detection import detect_recurrence
from preventive_recommendation import (
    generate_preventive_recommendations
)

app = FastAPI(title="SahaySetu API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:5500",
        "http://localhost:5500",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()


@app.get("/")
def root():
    return {"message": "SahaySetu Backend is running!"}


@app.post("/auth/register", response_model=UserResponse)
def register(user: UserCreate, db: Session = Depends(get_db)):
    new_user = register_user(user, db)

    if new_user is None:
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )

    return new_user

@app.post("/auth/login")
def login(user: UserLogin, db: Session = Depends(get_db)):
    authenticated_user = authenticate_user(
        user.email,
        user.password,
        db
    )

    if authenticated_user is None:
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password"
        )

    access_token = create_access_token(authenticated_user)

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": authenticated_user.user_id,
        "role": authenticated_user.role
    }

@app.get("/auth/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user

@app.post(
    "/complaints",
    response_model=ComplaintResponse
)
def create_complaint(
    complaint: ComplaintCreate,
    current_user: User = Depends(require_role("CITIZEN")),
    db: Session = Depends(get_db)
):
    new_complaint = Complaint(
        complaint_id=f"CMP-{uuid.uuid4().hex[:8].upper()}",
        user_id=current_user.id,

        description=complaint.description,
        category=complaint.category,
        severity=complaint.severity,

        latitude=complaint.latitude,
        longitude=complaint.longitude,

        photo_url=complaint.photo_url,
        audio_url=complaint.audio_url,

        status="SUBMITTED"
    )

    db.add(new_complaint)
    db.commit()
    db.refresh(new_complaint)

    return new_complaint

@app.get(
    "/complaints/my",
    response_model=list[ComplaintResponse]
)
def get_my_complaints(
    current_user: User = Depends(require_role("CITIZEN")),
    db: Session = Depends(get_db)
):
    complaints = db.query(Complaint).filter(
        Complaint.user_id == current_user.id
    ).order_by(
        Complaint.created_at.desc()
    ).all()

    return complaints

@app.get(
    "/complaints/{complaint_id}",
    response_model=ComplaintResponse
)
def get_complaint(
    complaint_id: str,
    current_user: User = Depends(require_role("CITIZEN")),
    db: Session = Depends(get_db)
):
    complaint = db.query(Complaint).filter(
        Complaint.complaint_id == complaint_id,
        Complaint.user_id == current_user.id
    ).first()

    if complaint is None:
        raise HTTPException(
            status_code=404,
            detail="Complaint not found"
        )

    return complaint

@app.get(
    "/worker/complaints",
    response_model=list[ComplaintResponse]
)
def get_worker_complaints(
    current_user: User = Depends(require_role("WORKER")),
    db: Session = Depends(get_db)
):
    complaints = db.query(Complaint).filter(
        Complaint.assigned_worker_id == current_user.id
    ).order_by(
        Complaint.created_at.desc()
    ).all()

    return complaints

@app.get(
    "/authority/complaints",
    response_model=list[ComplaintResponse]
)
def get_authority_complaints(
    current_user: User = Depends(require_role("AUTHORITY")),
    db: Session = Depends(get_db)
):
    complaints = db.query(Complaint).order_by(
        Complaint.created_at.desc()
    ).all()

    return complaints

@app.put(
    "/authority/complaints/{complaint_id}/assign",
    response_model=ComplaintResponse
)
def assign_complaint(
    complaint_id: str,
    assignment: ComplaintAssignment,
    current_user: User = Depends(require_role("AUTHORITY")),
    db: Session = Depends(get_db)
):
    complaint = db.query(Complaint).filter(
        Complaint.complaint_id == complaint_id
    ).first()

    if complaint is None:
        raise HTTPException(
            status_code=404,
            detail="Complaint not found"
        )

    worker = db.query(User).filter(
        User.id == assignment.worker_id,
        User.role == "WORKER",
        User.is_active == 1
    ).first()

    if worker is None:
        raise HTTPException(
            status_code=400,
            detail="Invalid or inactive worker"
        )

    complaint.assigned_worker_id = worker.id
    complaint.status = "ASSIGNED"

    db.commit()
    db.refresh(complaint)

    return complaint

@app.put(
    "/worker/complaints/{complaint_id}/status",
    response_model=ComplaintResponse
)
def update_complaint_status(
    complaint_id: str,
    status_update: ComplaintStatusUpdate,
    current_user: User = Depends(require_role("WORKER")),
    db: Session = Depends(get_db)
):
    complaint = db.query(Complaint).filter(
        Complaint.complaint_id == complaint_id,
        Complaint.assigned_worker_id == current_user.id
    ).first()

    if complaint is None:
        raise HTTPException(
            status_code=404,
            detail="Assigned complaint not found"
        )

    allowed_statuses = {
        "IN_PROGRESS",
        "COMPLETED"
    }

    if status_update.status not in allowed_statuses:
        raise HTTPException(
            status_code=400,
            detail="Invalid status"
        )

    complaint.status = status_update.status

    db.commit()
    db.refresh(complaint)

    return complaint

@app.get("/admin/users")
def get_all_users(
    current_user: User = Depends(require_role("ADMIN")),
    db: Session = Depends(get_db)
):
    users = db.query(User).order_by(
        User.id.asc()
    ).all()

    return users

@app.put("/admin/users/{user_id}/status")
def update_user_status(
    user_id: int,
    status: int,
    current_user: User = Depends(require_role("ADMIN")),
    db: Session = Depends(get_db)
):
    user = db.query(User).filter(
        User.id == user_id
    ).first()

    if user is None:
        raise HTTPException(
            status_code=404,
            detail="User not found"
        )

    if status not in [0, 1]:
        raise HTTPException(
            status_code=400,
            detail="Status must be 0 or 1"
        )

    user.is_active = status

    db.commit()
    db.refresh(user)

    return {
        "message": "User status updated successfully",
        "user_id": user.user_id,
        "is_active": user.is_active
    }

@app.get(
    "/admin/complaints",
    response_model=list[ComplaintResponse]
)
def get_all_complaints(
    current_user: User = Depends(require_role("ADMIN")),
    db: Session = Depends(get_db)
):
    complaints = db.query(Complaint).order_by(
        Complaint.created_at.desc()
    ).all()

    return complaints

@app.post("/admin/users", response_model=UserResponse)
def create_staff_user(
    user: UserCreate,
    role: str,
    current_user: User = Depends(require_role("ADMIN")),
    db: Session = Depends(get_db)
):
    if role not in ["WORKER", "AUTHORITY"]:
        raise HTTPException(
            status_code=400,
            detail="Admin can only create WORKER or AUTHORITY users"
        )

    existing_user = db.query(User).filter(
        User.email == user.email
    ).first()

    if existing_user:
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )

    new_user = User(
        user_id=f"{role[:3]}-{uuid.uuid4().hex[:8].upper()}",
        name=user.name,
        email=user.email,
        password_hash=hash_password(user.password),
        role=role,
        is_active=1
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return new_user

@app.post("/authority/incidents/fuse/{complaint_id}")
def fuse_complaint_into_incident(
    complaint_id: str,
    current_user: User = Depends(require_role("AUTHORITY")),
    db: Session = Depends(get_db)
):
    complaint = db.query(Complaint).filter(
        Complaint.complaint_id == complaint_id
    ).first()

    if complaint is None:
        raise HTTPException(
            status_code=404,
            detail="Complaint not found"
        )

    # Find other complaints that may belong
    # to the same connected civic incident.
    all_complaints = db.query(Complaint).all()

    related_complaints = find_related_complaints(
        complaint,
        all_complaints
    )

    if not related_complaints:
        return {
            "message": "No related complaints found",
            "complaint_id": complaint.complaint_id,
            "related_count": 0
        }

    # Include the original complaint
    complaint_group = [
        complaint
    ] + [
        item["complaint"]
        for item in related_complaints
    ]

    # Calculate average fusion score
    fusion_scores = [
        item["fusion_score"]
        for item in related_complaints
    ]

    average_fusion_score = sum(fusion_scores) / len(
        fusion_scores
    )

    # Create a new incident
    new_incident = Incident(
        incident_id=f"INC-{uuid.uuid4().hex[:8].upper()}",
        title=f"Connected {complaint.category} Incident",
        description=(
            f"Probable connected civic incident involving "
            f"{len(complaint_group)} complaints."
        ),
        incident_type=complaint.category,
        status="DETECTED",
        fusion_score=round(average_fusion_score, 2),
        latitude=sum(
            item.latitude for item in complaint_group
        ) / len(complaint_group),
        longitude=sum(
            item.longitude for item in complaint_group
        ) / len(complaint_group)
    )

    db.add(new_incident)
    db.flush()

    # Link all complaints to the incident
    for item in complaint_group:
        item.incident_id = new_incident.id

    db.commit()
    db.refresh(new_incident)

    return {
        "message": "Probable civic incident created",
        "incident_id": new_incident.incident_id,
        "complaint_count": len(complaint_group),
        "fusion_score": new_incident.fusion_score,
        "complaints": [
            item.complaint_id
            for item in complaint_group
        ]
    }

@app.get("/authority/incidents/{incident_id}/relationships")
def analyze_incident_relationships(
    incident_id: str,
    current_user: User = Depends(require_role("AUTHORITY")),
    db: Session = Depends(get_db)
):
    incident = db.query(Incident).filter(
        Incident.incident_id == incident_id
    ).first()

    if incident is None:
        raise HTTPException(
            status_code=404,
            detail="Incident not found"
        )

    complaints = db.query(Complaint).filter(
        Complaint.incident_id == incident.id
    ).all()

    relationships = analyze_relationships(
        complaints
    )

    return {
        "incident_id": incident.incident_id,
        "complaint_count": len(complaints),
        "relationships": relationships
    }
@app.get("/authority/incidents/{incident_id}/interventions")
def assess_incident_interventions(
    incident_id: str,
    current_user: User = Depends(require_role("AUTHORITY")),
    db: Session = Depends(get_db)
):
    incident = db.query(Incident).filter(
        Incident.incident_id == incident_id
    ).first()

    if incident is None:
        raise HTTPException(
            status_code=404,
            detail="Incident not found"
        )

    complaints = db.query(Complaint).filter(
        Complaint.incident_id == incident.id
    ).all()

    if not complaints:
        return {
            "incident_id": incident.incident_id,
            "complaint_count": 0,
            "interventions": []
        }

    relationships = analyze_relationships(
        complaints
    )

    interventions = assess_interventions(
        complaints,
        relationships
    )

    return {
        "incident_id": incident.incident_id,
        "complaint_count": len(complaints),
        "interventions": interventions
    }

@app.post(
    "/authority/incidents/{incident_id}/recovery",
    response_model=RecoveryObservationResponse
)
def record_recovery_observation(
    incident_id: str,
    observation: RecoveryObservationCreate,
    current_user: User = Depends(require_role("AUTHORITY")),
    db: Session = Depends(get_db)
):
    incident = db.query(Incident).filter(
        Incident.incident_id == incident_id
    ).first()

    if incident is None:
        raise HTTPException(
            status_code=404,
            detail="Incident not found"
        )

    intervention = db.query(Intervention).filter(
        Intervention.intervention_id == observation.intervention_id
    ).first()

    if intervention is None:
        raise HTTPException(
            status_code=404,
            detail="Intervention not found"
        )

    if intervention.incident_id != incident.id:
        raise HTTPException(
            status_code=400,
            detail="Intervention does not belong to this incident"
        )

    recovery_data = create_recovery_observation(
        observation.recovery_score,
        observation.evidence,
        observation.notes
    )

    new_observation = RecoveryObservation(
        incident_id=incident.id,
        intervention_id=intervention.id,
        observation_status=recovery_data["observation_status"],
        recovery_score=recovery_data["recovery_score"],
        evidence=recovery_data["evidence"],
        notes=recovery_data["notes"]
    )

    db.add(new_observation)
    db.commit()
    db.refresh(new_observation)

    return {
        "id": new_observation.id,
        "incident_id": incident.incident_id,
        "intervention_id": intervention.intervention_id,
        "observation_status": new_observation.observation_status,
        "recovery_score": new_observation.recovery_score,
        "observed_at": new_observation.observed_at,
        "evidence": new_observation.evidence,
        "notes": new_observation.notes
    }

@app.get("/authority/incidents/{incident_id}/recurrence")
def detect_incident_recurrence(
    incident_id: str,
    current_user: User = Depends(require_role("AUTHORITY")),
    db: Session = Depends(get_db)
):
    incident = db.query(Incident).filter(
        Incident.incident_id == incident_id
    ).first()

    if incident is None:
        raise HTTPException(
            status_code=404,
            detail="Incident not found"
        )

    complaints = db.query(Complaint).filter(
        Complaint.incident_id == incident.id
    ).all()

    if not complaints:
        return {
            "incident_id": incident.incident_id,
            "recurrence_detected": False,
            "recurrence_candidates": []
        }

    original_complaint = complaints[0]

    all_complaints = db.query(Complaint).all()

    recurrence_candidates = detect_recurrence(
        original_complaint,
        all_complaints,
        calculate_distance_meters
    )

    return {
        "incident_id": incident.incident_id,
        "recurrence_detected": len(
            recurrence_candidates
        ) > 0,
        "recurrence_count": len(
            recurrence_candidates
        ),
        "recurrence_candidates": [
            {
                "complaint_id": item["complaint"].complaint_id,
                "category": item["complaint"].category,
                "distance_meters": item["distance_meters"],
                "created_at": item["complaint"].created_at
            }
            for item in recurrence_candidates
        ]
    }

@app.get("/authority/incidents/{incident_id}/prevention")
def get_preventive_recommendations(
    incident_id: str,
    current_user: User = Depends(require_role("AUTHORITY")),
    db: Session = Depends(get_db)
):
    incident = db.query(Incident).filter(
        Incident.incident_id == incident_id
    ).first()

    if incident is None:
        raise HTTPException(
            status_code=404,
            detail="Incident not found"
        )

    complaints = db.query(Complaint).filter(
        Complaint.incident_id == incident.id
    ).all()

    all_complaints = db.query(Complaint).all()

    recurrence_detected = False

    if complaints:
        original_complaint = complaints[0]

        recurrence_candidates = detect_recurrence(
            original_complaint,
            all_complaints,
            calculate_distance_meters
        )

        recurrence_detected = (
            len(recurrence_candidates) > 0
        )

    recommendations = generate_preventive_recommendations(
        complaints,
        recurrence_detected
    )

    return {
        "incident_id": incident.incident_id,
        "recurrence_detected": recurrence_detected,
        "recommendation_count": len(recommendations),
        "recommendations": recommendations
    }

@app.post(
    "/authority/incidents/{incident_id}/interventions",
    response_model=InterventionResponse
)
def create_intervention(
    incident_id: str,
    intervention: InterventionCreate,
    current_user: User = Depends(require_role("AUTHORITY")),
    db: Session = Depends(get_db)
):
    incident = db.query(Incident).filter(
        Incident.incident_id == incident_id
    ).first()

    if incident is None:
        raise HTTPException(
            status_code=404,
            detail="Incident not found"
        )

    new_intervention = Intervention(
        intervention_id=f"INT-{uuid.uuid4().hex[:8].upper()}",
        incident_id=incident.id,
        intervention_type=intervention.intervention_type,
        status="PLANNED",
        expected_impact_score=intervention.expected_impact_score,
        notes=intervention.notes
    )

    db.add(new_intervention)
    db.commit()
    db.refresh(new_intervention)

    return {
        "id": new_intervention.id,
        "intervention_id": new_intervention.intervention_id,
        "incident_id": incident.incident_id,
        "intervention_type": new_intervention.intervention_type,
        "status": new_intervention.status,
        "expected_impact_score": new_intervention.expected_impact_score,
        "started_at": new_intervention.started_at,
        "completed_at": new_intervention.completed_at,
        "notes": new_intervention.notes
    }

@app.put(
    "/authority/interventions/{intervention_id}/status",
    response_model=InterventionResponse
)
def update_intervention_status(
    intervention_id: str,
    status_update: InterventionStatusUpdate,
    current_user: User = Depends(require_role("AUTHORITY")),
    db: Session = Depends(get_db)
):
    intervention = db.query(Intervention).filter(
        Intervention.intervention_id == intervention_id
    ).first()

    if intervention is None:
        raise HTTPException(
            status_code=404,
            detail="Intervention not found"
        )

    allowed_statuses = [
        "PLANNED",
        "IN_PROGRESS",
        "COMPLETED"
    ]

    if status_update.status not in allowed_statuses:
        raise HTTPException(
            status_code=400,
            detail=(
                "Status must be PLANNED, "
                "IN_PROGRESS, or COMPLETED"
            )
        )

    intervention.status = status_update.status

    if status_update.status == "IN_PROGRESS":
        intervention.started_at = datetime.utcnow()

    if status_update.status == "COMPLETED":
        intervention.completed_at = datetime.utcnow()

    db.commit()
    db.refresh(intervention)

    incident = db.query(Incident).filter(
        Incident.id == intervention.incident_id
    ).first()

    return {
        "id": intervention.id,
        "intervention_id": intervention.intervention_id,
        "incident_id": incident.incident_id,
        "intervention_type": intervention.intervention_type,
        "status": intervention.status,
        "expected_impact_score": intervention.expected_impact_score,
        "started_at": intervention.started_at,
        "completed_at": intervention.completed_at,
        "notes": intervention.notes
    }