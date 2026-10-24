import logging
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path as FilePath

from fastapi import (
    Depends,
    FastAPI,
    File,
    Form,
    HTTPException,
    Path,
    UploadFile,
)
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from related_incidents_ml import find_related_incidents

from sqlalchemy import func
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError, SQLAlchemyError

from database import SessionLocal
from category_mapping import category_for_assignment
from schemas import (
    UserCreate,
    UserResponse,
    UserLogin,
    ComplaintCreate,
    ComplaintResponse,
    ComplaintDetailResponse,
    ComplaintStatusHistoryResponse,
    CitizenVerificationResponse,
    ComplaintAssignment,
    ComplaintStatusUpdate,
    RecoveryObservationCreate,
    RecoveryObservationResponse,
    InterventionCreate,
    InterventionResponse,
    InterventionStatusUpdate,
    WorkerResponse,
    EligibleWorkersResponse
)
from auth import register_user, authenticate_user, create_access_token
from dependencies import get_current_user
from models import (
    User,
    Complaint,
    ComplaintStatusHistory,
    CitizenVerification,
    Incident,
    Intervention,
    RecoveryObservation
)
from authorization import require_role
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
logger = logging.getLogger(__name__)
MAX_VERIFICATION_EVIDENCE_BYTES = 5 * 1024 * 1024
VERIFICATION_EVIDENCE_TYPES = {
    "image/jpeg": (b"\xff\xd8\xff", ".jpg"),
    "image/png": (b"\x89PNG\r\n\x1a\n", ".png"),
    "image/webp": (b"RIFF", ".webp"),
}
app.state.evidence_storage_directory = (
    FilePath(__file__).resolve().parent / "evidence_storage"
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:5500",
        "http://localhost:5500",
    ],
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:[0-9]+)?$",
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


def complaint_response_data(complaint: Complaint, assigned_worker_name=None):
    result = ComplaintResponse.model_validate(complaint).model_dump()
    result["assigned_worker_name"] = assigned_worker_name
    return result


def worker_response_data(worker: User, assigned_complaint_count=0):
    result = WorkerResponse.model_validate(worker).model_dump()
    if worker.worker_category:
        result["worker_category"] = (
            category_for_assignment(worker.worker_category)
            or worker.worker_category
        )
    result["assigned_complaint_count"] = assigned_complaint_count
    return result


def api_utc_timestamp(value: datetime | None):
    if value is None or value.tzinfo is not None:
        return value
    return value.replace(tzinfo=timezone.utc)


def complaint_detail_response_data(complaint: Complaint, db: Session):
    worker = (
        db.query(User).filter(User.id == complaint.assigned_worker_id).first()
        if complaint.assigned_worker_id is not None
        else None
    )
    history = db.query(ComplaintStatusHistory).filter(
        ComplaintStatusHistory.complaint_id == complaint.id
    ).order_by(
        ComplaintStatusHistory.changed_at.asc(),
        ComplaintStatusHistory.id.asc(),
    ).all()
    verification = db.query(CitizenVerification).filter(
        CitizenVerification.complaint_id == complaint.id
    ).order_by(
        CitizenVerification.submitted_at.desc(),
        CitizenVerification.id.desc(),
    ).first()
    latest_completion = db.query(ComplaintStatusHistory).filter(
        ComplaintStatusHistory.complaint_id == complaint.id,
        ComplaintStatusHistory.event_type == "COMPLETED",
    ).order_by(
        ComplaintStatusHistory.changed_at.desc(),
        ComplaintStatusHistory.id.desc(),
    ).first()
    completion_already_verified = (
        latest_completion is not None
        and db.query(CitizenVerification.id).filter(
            CitizenVerification.completion_event_id == latest_completion.id
        ).first()
        is not None
    )
    result = complaint_response_data(
        complaint,
        worker.name if worker is not None else None,
    )
    result["status_history"] = [
        {
            **ComplaintStatusHistoryResponse.model_validate(item).model_dump(),
            "changed_at": api_utc_timestamp(item.changed_at),
        }
        for item in history
    ]
    result["created_at"] = api_utc_timestamp(complaint.created_at)
    result["verification"] = (
        {
            "id": verification.id,
            "result": verification.result,
            "feedback": verification.feedback,
            "submitted_at": api_utc_timestamp(verification.submitted_at),
            "evidence_available": verification.evidence_filename is not None,
        }
        if verification is not None
        else None
    )
    result["verification_eligible"] = (
        complaint.status == "COMPLETED"
        and complaint.assigned_worker_id is not None
        and latest_completion is not None
        and not completion_already_verified
    )
    return result


def add_complaint_status_event(
    db: Session,
    complaint: Complaint,
    event_type: str,
    actor_user_id: int,
) -> None:
    db.add(
        ComplaintStatusHistory(
            complaint_id=complaint.id,
            event_type=event_type,
            status=complaint.status,
            changed_at=datetime.now(timezone.utc).replace(tzinfo=None),
            actor_user_id=actor_user_id,
            assigned_worker_id=complaint.assigned_worker_id,
        )
    )


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

    if authenticated_user.role not in {
        "CITIZEN",
        "WORKER",
        "AUTHORITY",
        "ADMIN",
    }:
        raise HTTPException(
            status_code=403,
            detail="This account role cannot sign in to these portals"
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
    try:
        db.flush()
        add_complaint_status_event(
            db,
            new_complaint,
            "SUBMITTED",
            current_user.id,
        )
        db.commit()
        db.refresh(new_complaint)
    except SQLAlchemyError as error:
        db.rollback()
        logger.exception("Failed to save complaint")
        raise HTTPException(
            status_code=500,
            detail="Complaint could not be saved",
        ) from error

    historical_complaints = db.query(Complaint).filter(
        Complaint.id != new_complaint.id
    ).all()

    try:
        find_related_incidents(
            new_complaint,
            historical_complaints
        )
    except Exception as error:
        print(f"Related-incident ML analysis failed: {error}")

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

@app.get("/complaints/{complaint_id}/related")
def get_related_complaints(
    complaint_id: str,
    current_user: User = Depends(get_current_user),
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

    if current_user.role not in ["AUTHORITY", "ADMIN"]:
        if complaint.user_id != current_user.id:
            raise HTTPException(
                status_code=403,
                detail="Not authorized to view these results"
            )

    historical_complaints = db.query(Complaint).filter(
        Complaint.id != complaint.id
    ).all()

    results = find_related_incidents(
        complaint,
        historical_complaints
    )

    return {
        "complaint_id": complaint.complaint_id,
        "related_count": len(results),
        "related_incidents": results
    }

@app.get(
    "/complaints/{complaint_id}",
    response_model=ComplaintDetailResponse
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

    return complaint_detail_response_data(complaint, db)


@app.post(
    "/complaints/{complaint_id}/verification",
    response_model=ComplaintDetailResponse,
)
async def submit_citizen_verification(
    complaint_id: str,
    result: str = Form(...),
    feedback: str | None = Form(default=None, max_length=2000),
    evidence: UploadFile | None = File(default=None),
    current_user: User = Depends(require_role("CITIZEN")),
    db: Session = Depends(get_db),
):
    if result not in {"RESOLVED", "NOT_RESOLVED"}:
        raise HTTPException(
            status_code=422,
            detail="Result must be RESOLVED or NOT_RESOLVED",
        )

    complaint = db.query(Complaint).filter(
        Complaint.complaint_id == complaint_id,
        Complaint.user_id == current_user.id,
    ).with_for_update().first()
    if complaint is None:
        raise HTTPException(status_code=404, detail="Complaint not found")
    if complaint.status != "COMPLETED" or complaint.assigned_worker_id is None:
        raise HTTPException(
            status_code=409,
            detail="Citizen verification is available after a worker marks the complaint complete",
        )
    completion_event = db.query(ComplaintStatusHistory).filter(
        ComplaintStatusHistory.complaint_id == complaint.id,
        ComplaintStatusHistory.event_type == "COMPLETED",
    ).order_by(
        ComplaintStatusHistory.changed_at.desc(),
        ComplaintStatusHistory.id.desc(),
    ).first()
    if completion_event is None:
        raise HTTPException(
            status_code=409,
            detail="No recorded worker completion is available to verify",
        )
    if db.query(CitizenVerification.id).filter(
        CitizenVerification.completion_event_id == completion_event.id
    ).first() is not None:
        raise HTTPException(
            status_code=409,
            detail="This work completion already has a citizen response",
        )

    evidence_bytes = None
    evidence_content_type = None
    evidence_extension = None
    if evidence is not None:
        evidence_bytes = await evidence.read(MAX_VERIFICATION_EVIDENCE_BYTES + 1)
        if len(evidence_bytes) > MAX_VERIFICATION_EVIDENCE_BYTES:
            raise HTTPException(
                status_code=413,
                detail="Evidence photo must be 5 MB or smaller",
            )

        evidence_content_type = evidence.content_type
        signature = VERIFICATION_EVIDENCE_TYPES.get(evidence_content_type or "")
        if signature is None:
            raise HTTPException(
                status_code=415,
                detail="Evidence must be a JPEG, PNG, or WebP image",
            )
        expected_signature, evidence_extension = signature
        valid_signature = evidence_bytes.startswith(expected_signature)
        if evidence_content_type == "image/webp":
            valid_signature = (
                valid_signature
                and len(evidence_bytes) >= 12
                and evidence_bytes[8:12] == b"WEBP"
            )
        if not valid_signature:
            raise HTTPException(
                status_code=415,
                detail="The uploaded file does not match its image type",
            )

    evidence_filename = None
    evidence_path = None
    if evidence_bytes is not None and evidence_extension is not None:
        evidence_filename = f"{uuid.uuid4().hex}{evidence_extension}"
        evidence_directory = FilePath(app.state.evidence_storage_directory)
        evidence_path = evidence_directory / evidence_filename
        try:
            evidence_directory.mkdir(
                parents=True,
                exist_ok=True,
                mode=0o700,
            )
            file_descriptor = os.open(
                evidence_path,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL,
                0o600,
            )
            with os.fdopen(file_descriptor, "wb") as evidence_file:
                evidence_file.write(evidence_bytes)
        except OSError as error:
            try:
                evidence_path.unlink(missing_ok=True)
            except OSError:
                logger.exception("Unable to remove incomplete evidence file")
            logger.exception("Unable to store citizen verification evidence")
            raise HTTPException(
                status_code=500,
                detail="Evidence photo could not be stored",
            ) from error

    verification = CitizenVerification(
        complaint_id=complaint.id,
        completion_event_id=completion_event.id,
        citizen_user_id=current_user.id,
        result=result,
        feedback=feedback.strip() or None if feedback is not None else None,
        evidence_filename=evidence_filename,
        evidence_content_type=evidence_content_type,
        submitted_at=datetime.now(timezone.utc).replace(tzinfo=None),
    )
    complaint.status = (
        "CITIZEN_VERIFIED" if result == "RESOLVED" else "CITIZEN_DISPUTED"
    )
    db.add(verification)
    add_complaint_status_event(
        db,
        complaint,
        complaint.status,
        current_user.id,
    )
    try:
        db.commit()
        db.refresh(complaint)
    except IntegrityError as error:
        db.rollback()
        if evidence_path is not None:
            try:
                evidence_path.unlink(missing_ok=True)
            except OSError:
                logger.exception("Unable to remove uncommitted evidence file")
        duplicate = db.query(CitizenVerification.id).filter(
            CitizenVerification.completion_event_id == completion_event.id
        ).first()
        if duplicate is not None:
            raise HTTPException(
                status_code=409,
                detail="This work completion already has a citizen response",
            ) from error
        logger.exception("Database constraint rejected citizen verification")
        raise HTTPException(
            status_code=500,
            detail="Citizen verification could not be saved",
        ) from error
    except SQLAlchemyError as error:
        db.rollback()
        if evidence_path is not None:
            try:
                evidence_path.unlink(missing_ok=True)
            except OSError:
                logger.exception("Unable to remove uncommitted evidence file")
        logger.exception("Failed to save citizen verification")
        raise HTTPException(
            status_code=500,
            detail="Citizen verification could not be saved",
        ) from error

    return complaint_detail_response_data(complaint, db)


@app.get("/complaints/{complaint_id}/verification/evidence")
def get_citizen_verification_evidence(
    complaint_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    complaint = db.query(Complaint).filter(
        Complaint.complaint_id == complaint_id
    ).first()
    if complaint is None:
        raise HTTPException(status_code=404, detail="Complaint not found")

    if current_user.role == "CITIZEN":
        allowed = complaint.user_id == current_user.id
    elif current_user.role == "WORKER":
        allowed = complaint.assigned_worker_id == current_user.id
    elif current_user.role == "AUTHORITY":
        allowed = True
    else:
        allowed = False
    if not allowed:
        raise HTTPException(status_code=404, detail="Evidence not found")

    verification = db.query(CitizenVerification).filter(
        CitizenVerification.complaint_id == complaint.id
    ).order_by(
        CitizenVerification.submitted_at.desc(),
        CitizenVerification.id.desc(),
    ).first()
    if verification is None or verification.evidence_filename is None:
        raise HTTPException(status_code=404, detail="Evidence not found")

    evidence_directory = FilePath(app.state.evidence_storage_directory).resolve()
    evidence_path = (evidence_directory / verification.evidence_filename).resolve()
    if evidence_path.parent != evidence_directory or not evidence_path.is_file():
        logger.warning(
            "Stored citizen verification evidence is unavailable for complaint %s",
            complaint.complaint_id,
        )
        raise HTTPException(
            status_code=404,
            detail="Evidence file is unavailable",
        )

    return FileResponse(
        evidence_path,
        media_type=verification.evidence_content_type,
        headers={
            "X-Content-Type-Options": "nosniff",
            "Cache-Control": "private, no-store",
        },
    )

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
    complaints = db.query(Complaint, User.name).outerjoin(
        User,
        Complaint.assigned_worker_id == User.id
    ).order_by(Complaint.created_at.desc()).all()

    return [
        complaint_response_data(complaint, worker_name)
        for complaint, worker_name in complaints
    ]

@app.get(
    "/authority/complaints/{complaint_id}",
    response_model=ComplaintResponse
)
def get_authority_complaint_detail(
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

    worker = db.query(User).filter(
        User.id == complaint.assigned_worker_id
    ).first() if complaint.assigned_worker_id is not None else None

    return complaint_response_data(
        complaint,
        worker.name if worker is not None else None
    )

@app.get(
    "/authority/workers",
    response_model=list[WorkerResponse]
)
def get_authority_workers(
    current_user: User = Depends(require_role("AUTHORITY")),
    db: Session = Depends(get_db)
):
    workers = db.query(User).filter(
        User.role == "WORKER"
    ).order_by(User.name.asc(), User.id.asc()).all()
    assignment_counts = dict(
        db.query(
            Complaint.assigned_worker_id,
            func.count(Complaint.id)
        ).filter(
            Complaint.assigned_worker_id.isnot(None)
        ).group_by(Complaint.assigned_worker_id).all()
    )

    return [
        worker_response_data(worker, assignment_counts.get(worker.id, 0))
        for worker in workers
    ]


@app.get(
    "/authority/complaints/{complaint_id}/eligible-workers",
    response_model=EligibleWorkersResponse
)
def get_eligible_workers_for_complaint(
    complaint_id: str,
    current_user: User = Depends(require_role("AUTHORITY")),
    db: Session = Depends(get_db)
):
    complaint = db.query(Complaint).filter(
        Complaint.complaint_id == complaint_id
    ).first()

    if complaint is None:
        raise HTTPException(status_code=404, detail="Complaint not found")

    category = category_for_assignment(complaint.category)
    assigned_worker = db.query(User).filter(
        User.id == complaint.assigned_worker_id,
        User.role == "WORKER"
    ).first() if complaint.assigned_worker_id is not None else None

    eligible_workers = []

    if category is not None:
        active_workers = db.query(User).filter(
            User.role == "WORKER",
            User.is_active == 1
        ).order_by(User.name.asc(), User.id.asc()).all()
        eligible_workers = [
            worker for worker in active_workers
            if category_for_assignment(worker.worker_category) == category
        ]

    assignment_counts = dict(
        db.query(
            Complaint.assigned_worker_id,
            func.count(Complaint.id)
        ).filter(
            Complaint.assigned_worker_id.isnot(None)
        ).group_by(Complaint.assigned_worker_id).all()
    )

    return {
        "complaint_id": complaint.complaint_id,
        "complaint_category": complaint.category,
        "category": category,
        "assigned_worker_id": complaint.assigned_worker_id,
        "assigned_worker_name": (
            assigned_worker.name if assigned_worker is not None else None
        ),
        "workers": [
            worker_response_data(worker, assignment_counts.get(worker.id, 0))
            for worker in eligible_workers
        ]
    }


@app.get(
    "/authority/workers/{worker_id}/complaints",
    response_model=list[ComplaintResponse]
)
def get_authority_worker_complaints(
    worker_id: int = Path(gt=0),
    current_user: User = Depends(require_role("AUTHORITY")),
    db: Session = Depends(get_db)
):
    worker = db.query(User).filter(
        User.id == worker_id,
        User.role == "WORKER"
    ).first()

    if worker is None:
        raise HTTPException(status_code=404, detail="Worker not found")

    complaints = db.query(Complaint, User.name).outerjoin(
        User,
        Complaint.assigned_worker_id == User.id
    ).filter(
        Complaint.assigned_worker_id == worker.id
    ).order_by(Complaint.created_at.desc()).all()

    return [
        complaint_response_data(complaint, worker_name)
        for complaint, worker_name in complaints
    ]

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
    ).with_for_update().first()

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

    complaint_category = category_for_assignment(complaint.category)
    worker_category = category_for_assignment(worker.worker_category)

    if complaint_category is None:
        raise HTTPException(
            status_code=422,
            detail=(
                "This complaint category cannot be safely matched to a "
                "worker category. Assignment was not changed."
            )
        )

    if worker_category is None:
        raise HTTPException(
            status_code=409,
            detail="This worker has no supported category assignment"
        )

    if complaint_category != worker_category:
        raise HTTPException(
            status_code=409,
            detail=(
                f"Category mismatch: {complaint_category} complaints can "
                f"only be assigned to {complaint_category} workers."
            )
        )

    assignment_changed = (
        complaint.assigned_worker_id != worker.id
        or complaint.status != "ASSIGNED"
    )
    complaint.assigned_worker_id = worker.id
    complaint.status = "ASSIGNED"

    try:
        if assignment_changed:
            add_complaint_status_event(
                db,
                complaint,
                "ASSIGNED",
                current_user.id,
            )
        db.commit()
    except SQLAlchemyError as error:
        db.rollback()
        logger.exception("Failed to save worker assignment")
        raise HTTPException(
            status_code=500,
            detail="Assignment could not be saved"
        ) from error

    db.refresh(complaint)

    return complaint_response_data(complaint, worker.name)

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
    ).with_for_update().first()

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

    valid_next_statuses = {
        "ASSIGNED": "IN_PROGRESS",
        "IN_PROGRESS": "COMPLETED",
    }
    if valid_next_statuses.get(complaint.status) != status_update.status:
        raise HTTPException(
            status_code=409,
            detail=(
                f"Cannot change complaint status from {complaint.status} "
                f"to {status_update.status}"
            )
        )

    complaint.status = status_update.status

    try:
        add_complaint_status_event(
            db,
            complaint,
            status_update.status,
            current_user.id,
        )
        db.commit()
        db.refresh(complaint)
    except SQLAlchemyError as error:
        db.rollback()
        logger.exception("Failed to update worker complaint status")
        raise HTTPException(
            status_code=500,
            detail="Complaint status could not be saved",
        ) from error

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

@app.get(
    "/authority/incidents",
    response_model=list
)
def get_authority_incidents(
    current_user: User = Depends(require_role("AUTHORITY")),
    db: Session = Depends(get_db)
):
    incidents = db.query(Incident).order_by(Incident.created_at.desc()).all()

    return [
        {
            "id": incident.id,
            "incident_id": incident.incident_id,
            "title": incident.title,
            "description": incident.description,
            "incident_type": incident.incident_type,
            "status": incident.status,
            "fusion_score": incident.fusion_score,
            "latitude": incident.latitude,
            "longitude": incident.longitude,
            "created_at": incident.created_at,
            "complaint_count": db.query(Complaint).filter(
                Complaint.incident_id == incident.id
            ).count()
        }
        for incident in incidents
    ]

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

    if complaint.incident_id is not None:
        raise HTTPException(
            status_code=409,
            detail="Complaint is already linked to an incident"
        )

    # Find other complaints that may belong
    # to the same connected civic incident.
    all_complaints = db.query(Complaint).filter(
        Complaint.incident_id.is_(None)
    ).all()

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

@app.get(
    "/authority/incidents/{incident_id}/interventions/records",
    response_model=list[InterventionResponse]
)
def get_incident_intervention_records(
    incident_id: str,
    current_user: User = Depends(require_role("AUTHORITY")),
    db: Session = Depends(get_db)
):
    incident = db.query(Incident).filter(
        Incident.incident_id == incident_id
    ).first()

    if incident is None:
        raise HTTPException(status_code=404, detail="Incident not found")

    records = db.query(Intervention).filter(
        Intervention.incident_id == incident.id
    ).order_by(Intervention.id.asc()).all()

    return [
        {
            "id": record.id,
            "intervention_id": record.intervention_id,
            "incident_id": incident.incident_id,
            "intervention_type": record.intervention_type,
            "status": record.status,
            "expected_impact_score": record.expected_impact_score,
            "started_at": record.started_at,
            "completed_at": record.completed_at,
            "notes": record.notes,
        }
        for record in records
    ]

@app.get(
    "/authority/incidents/{incident_id}/recovery",
    response_model=list[RecoveryObservationResponse]
)
def get_incident_recovery_observations(
    incident_id: str,
    current_user: User = Depends(require_role("AUTHORITY")),
    db: Session = Depends(get_db)
):
    incident = db.query(Incident).filter(
        Incident.incident_id == incident_id
    ).first()

    if incident is None:
        raise HTTPException(status_code=404, detail="Incident not found")

    observations = db.query(
        RecoveryObservation,
        Intervention.intervention_id,
    ).outerjoin(
        Intervention,
        RecoveryObservation.intervention_id == Intervention.id,
    ).filter(
        RecoveryObservation.incident_id == incident.id
    ).order_by(
        RecoveryObservation.observed_at.desc()
    ).all()

    return [
        {
            "id": observation.id,
            "incident_id": incident.incident_id,
            "intervention_id": intervention_id,
            "observation_status": observation.observation_status,
            "recovery_score": observation.recovery_score,
            "observed_at": observation.observed_at,
            "evidence": observation.evidence,
            "notes": observation.notes,
        }
        for observation, intervention_id in observations
    ]

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

    if observation.incident_id != incident.incident_id:
        raise HTTPException(
            status_code=400,
            detail="Observation incident ID does not match the request URL"
        )

    if intervention.status != "COMPLETED":
        raise HTTPException(
            status_code=409,
            detail="Recovery observations require a completed intervention"
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

    latest_recovery = db.query(RecoveryObservation).filter(
        RecoveryObservation.incident_id == incident.id
    ).order_by(RecoveryObservation.observed_at.desc()).first()

    recovery_status = None

    if latest_recovery is not None:
        recovery_status = latest_recovery.observation_status
    elif original_complaint.status in {"COMPLETED", "RESOLVED", "RECOVERED"}:
        recovery_status = "RECOVERED"
    elif original_complaint.status in {"IN_PROGRESS", "ASSIGNED"}:
        recovery_status = "RECOVERING"

    recurrence_candidates = detect_recurrence(
        original_complaint,
        all_complaints,
        calculate_distance_meters,
        recovery_status
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

        latest_recovery = db.query(RecoveryObservation).filter(
            RecoveryObservation.incident_id == incident.id
        ).order_by(RecoveryObservation.observed_at.desc()).first()

        recovery_status = None

        if latest_recovery is not None:
            recovery_status = latest_recovery.observation_status
        elif original_complaint.status in {"COMPLETED", "RESOLVED", "RECOVERED"}:
            recovery_status = "RECOVERED"
        elif original_complaint.status in {"IN_PROGRESS", "ASSIGNED"}:
            recovery_status = "RECOVERING"

        recurrence_candidates = detect_recurrence(
            original_complaint,
            all_complaints,
            calculate_distance_meters,
            recovery_status
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

    valid_next_statuses = {
        "PLANNED": "IN_PROGRESS",
        "IN_PROGRESS": "COMPLETED",
    }
    if valid_next_statuses.get(intervention.status) != status_update.status:
        raise HTTPException(
            status_code=409,
            detail=(
                f"Cannot change intervention status from {intervention.status} "
                f"to {status_update.status}"
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