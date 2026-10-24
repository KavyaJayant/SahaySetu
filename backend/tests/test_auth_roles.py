import asyncio
import json
import os
import tempfile
import unittest

os.environ["DATABASE_URL"] = "sqlite://"
os.environ["SECRET_KEY"] = "sahaysetu-auth-tests-only-key-fixture"

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base
from dependencies import get_db as auth_get_db
from main import app, get_db as main_get_db
from models import (
    CitizenVerification,
    Complaint,
    ComplaintStatusHistory,
    Incident,
    User,
)
from security import hash_password


TEST_DATABASE = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestSession = sessionmaker(bind=TEST_DATABASE, autoflush=False)


def override_get_db():
    db = TestSession()
    try:
        yield db
    finally:
        db.close()


async def asgi_request(
    method,
    path,
    body=None,
    token=None,
    raw_body=None,
    content_type="application/json",
    parse_json=True,
):
    request_body = (
        raw_body
        if raw_body is not None
        else json.dumps(body or {}).encode("utf-8")
    )
    request_sent = False
    response_complete = asyncio.Event()
    response_messages = []
    headers = [(b"content-type", content_type.encode("ascii"))]
    if token:
        headers.append((b"authorization", f"Bearer {token}".encode("ascii")))

    async def receive():
        nonlocal request_sent
        if not request_sent:
            request_sent = True
            return {
                "type": "http.request",
                "body": request_body,
                "more_body": False,
            }
        await response_complete.wait()
        return {"type": "http.disconnect"}

    async def send(message):
        response_messages.append(message)
        if (
            message["type"] == "http.response.body"
            and not message.get("more_body", False)
        ):
            response_complete.set()

    await app(
        {
            "type": "http",
            "asgi": {"version": "3.0", "spec_version": "2.3"},
            "http_version": "1.1",
            "method": method,
            "scheme": "http",
            "path": path,
            "raw_path": path.encode("ascii"),
            "query_string": b"",
            "root_path": "",
            "headers": headers,
            "server": ("testserver", 80),
            "client": ("testclient", 12345),
        },
        receive,
        send,
    )

    status = next(
        item["status"]
        for item in response_messages
        if item["type"] == "http.response.start"
    )
    response_body = b"".join(
        item.get("body", b"")
        for item in response_messages
        if item["type"] == "http.response.body"
    )
    if not parse_json:
        return status, response_body
    return status, json.loads(response_body) if response_body else None


class RoleAuthenticationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        Base.metadata.create_all(TEST_DATABASE)
        app.dependency_overrides[main_get_db] = override_get_db
        app.dependency_overrides[auth_get_db] = override_get_db

        db = TestSession()
        for role in ("CITIZEN", "WORKER", "AUTHORITY", "ADMIN"):
            db.add(
                User(
                    user_id=f"TEST-{role}",
                    name=f"Test {role.title()}",
                    email=f"{role.lower()}@example.com",
                    password_hash=hash_password("correct-horse-battery"),
                    role=role,
                    is_active=1,
                    worker_category=(
                        "Pothole & Road Damage"
                        if role == "WORKER"
                        else None
                    ),
                )
            )
        db.add(
            User(
                user_id="TEST-WORKER-OTHER",
                name="Other Test Worker",
                email="other-worker@example.com",
                password_hash=hash_password("correct-horse-battery"),
                role="WORKER",
                is_active=1,
                worker_category="Pothole & Road Damage",
            )
        )
        db.add(
            User(
                user_id="TEST-INACTIVE",
                name="Inactive Worker",
                email="inactive@example.com",
                password_hash=hash_password("correct-horse-battery"),
                role="WORKER",
                is_active=0,
            )
        )
        db.add(
            User(
                user_id="TEST-CITIZEN-OTHER",
                name="Other Test Citizen",
                email="other-citizen@example.com",
                password_hash=hash_password("correct-horse-battery"),
                role="CITIZEN",
                is_active=1,
            )
        )
        db.commit()
        db.close()

    @classmethod
    def tearDownClass(cls):
        app.dependency_overrides.pop(main_get_db, None)
        app.dependency_overrides.pop(auth_get_db, None)
        Base.metadata.drop_all(TEST_DATABASE)
        TEST_DATABASE.dispose()

    def tearDown(self):
        self.evidence_directory.cleanup()

    def request(self, method, path, body=None, token=None):
        return asyncio.run(asgi_request(method, path, body, token))

    def setUp(self):
        self.evidence_directory = tempfile.TemporaryDirectory()
        app.state.evidence_storage_directory = self.evidence_directory.name
        db = TestSession()
        db.query(CitizenVerification).delete(synchronize_session=False)
        db.query(ComplaintStatusHistory).delete(synchronize_session=False)
        db.query(Complaint).delete(synchronize_session=False)
        db.commit()
        db.close()

    def login(self, role, password="correct-horse-battery", email=None):
        return self.request(
            "POST",
            "/auth/login",
            {
                "email": email or f"{role.lower()}@example.com",
                "password": password,
            },
        )

    def create_completed_complaint(self):
        citizen_status, citizen = self.login("CITIZEN")
        authority_status, authority = self.login("AUTHORITY")
        worker_status, worker = self.login("WORKER")
        self.assertEqual(
            (citizen_status, authority_status, worker_status),
            (200, 200, 200),
        )
        _, worker_identity = self.request(
            "GET",
            "/auth/me",
            token=worker["access_token"],
        )
        complaint_status, complaint = self.request(
            "POST",
            "/complaints",
            {
                "description": "Large pothole beside the community centre entrance",
                "category": "Pothole & Road Damage",
                "severity": "High",
                "latitude": 28.61,
                "longitude": 77.20,
            },
            token=citizen["access_token"],
        )
        self.assertEqual(complaint_status, 200)
        assignment_status, _ = self.request(
            "PUT",
            f"/authority/complaints/{complaint['complaint_id']}/assign",
            {"worker_id": worker_identity["id"]},
            token=authority["access_token"],
        )
        self.assertEqual(assignment_status, 200)
        in_progress_status, _ = self.request(
            "PUT",
            f"/worker/complaints/{complaint['complaint_id']}/status",
            {"status": "IN_PROGRESS"},
            token=worker["access_token"],
        )
        completed_status, _ = self.request(
            "PUT",
            f"/worker/complaints/{complaint['complaint_id']}/status",
            {"status": "COMPLETED"},
            token=worker["access_token"],
        )
        self.assertEqual((in_progress_status, completed_status), (200, 200))
        return citizen, authority, worker, complaint

    @staticmethod
    def multipart_body(
        boundary,
        fields,
        filename=None,
        content=None,
        media_type=None,
    ):
        chunks = []
        for key, value in fields.items():
            chunks.extend(
                [
                    f"--{boundary}\r\n".encode(),
                    f'Content-Disposition: form-data; name="{key}"\r\n\r\n'.encode(),
                    str(value).encode(),
                    b"\r\n",
                ]
            )
        if filename is not None:
            chunks.extend(
                [
                    f"--{boundary}\r\n".encode(),
                    (
                        'Content-Disposition: form-data; name="evidence"; '
                        f'filename="{filename}"\r\n'
                    ).encode(),
                    f"Content-Type: {media_type}\r\n\r\n".encode(),
                    content or b"",
                    b"\r\n",
                ]
            )
        chunks.append(f"--{boundary}--\r\n".encode())
        return b"".join(chunks)

    def submit_verification(
        self,
        complaint_id,
        token,
        result="RESOLVED",
        feedback="The repair has been checked.",
        filename="proof.png",
        content=b"\x89PNG\r\n\x1a\n" + b"\x00" * 8,
        media_type="image/png",
    ):
        boundary = "sahaysetu-test-boundary"
        body = self.multipart_body(
            boundary,
            {"result": result, "feedback": feedback},
            filename=filename,
            content=content,
            media_type=media_type,
        )
        return asyncio.run(
            asgi_request(
                "POST",
                f"/complaints/{complaint_id}/verification",
                token=token,
                raw_body=body,
                content_type=f"multipart/form-data; boundary={boundary}",
            )
        )

    def test_active_citizen_worker_and_authority_can_login_and_access_own_route(self):
        protected_routes = {
            "CITIZEN": "/complaints/my",
            "WORKER": "/worker/complaints",
            "AUTHORITY": "/authority/complaints",
        }

        for role, protected_route in protected_routes.items():
            with self.subTest(role=role):
                status, data = self.login(role)
                self.assertEqual(status, 200)
                self.assertEqual(data["role"], role)
                self.assertEqual(data["token_type"], "bearer")
                self.assertTrue(data["access_token"])

                identity_status, identity = self.request(
                    "GET",
                    "/auth/me",
                    token=data["access_token"],
                )
                self.assertEqual(identity_status, 200)
                self.assertEqual(identity["role"], role)

                route_status, _ = self.request(
                    "GET",
                    protected_route,
                    token=data["access_token"],
                )
                self.assertEqual(route_status, 200)

    def test_invalid_password_and_unknown_account_are_rejected(self):
        status, _ = self.login("CITIZEN", password="incorrect-password")
        self.assertEqual(status, 401)

        status, _ = self.login(
            "CITIZEN",
            email="missing@example.com",
        )
        self.assertEqual(status, 401)

    def test_inactive_account_cannot_login(self):
        status, _ = self.login(
            "WORKER",
            email="inactive@example.com",
        )
        self.assertEqual(status, 401)

    def test_invalid_bearer_token_is_rejected(self):
        status, _ = self.request(
            "GET",
            "/auth/me",
            token="not-a-valid-token",
        )
        self.assertEqual(status, 401)

    def test_roles_cannot_access_other_roles_protected_routes(self):
        protected_routes = {
            "CITIZEN": "/complaints/my",
            "WORKER": "/worker/complaints",
            "AUTHORITY": "/authority/complaints",
        }

        for role, own_route in protected_routes.items():
            status, data = self.login(role)
            self.assertEqual(status, 200)
            for other_role, other_route in protected_routes.items():
                if other_role == role:
                    continue
                with self.subTest(role=role, route=other_route):
                    route_status, _ = self.request(
                        "GET",
                        other_route,
                        token=data["access_token"],
                    )
                    self.assertEqual(route_status, 403)

    def test_admin_can_sign_in_only_to_admin_routes(self):
        status, data = self.login("ADMIN")
        self.assertEqual(status, 200)

        users_status, _ = self.request(
            "GET",
            "/admin/users",
            token=data["access_token"],
        )
        self.assertEqual(users_status, 200)

        authority_status, _ = self.request(
            "GET",
            "/authority/complaints",
            token=data["access_token"],
        )
        self.assertEqual(authority_status, 403)

    def test_citizen_complaint_creation_persists_owner_id_and_returns_real_status(self):
        login_status, login_data = self.login("CITIZEN")
        self.assertEqual(login_status, 200)
        identity_status, identity = self.request(
            "GET",
            "/auth/me",
            token=login_data["access_token"],
        )
        self.assertEqual(identity_status, 200)

        status, complaint = self.request(
            "POST",
            "/complaints",
            {
                "description": "Large pothole near the public library entrance",
                "category": "Pothole & Road Damage",
                "severity": "High",
                "latitude": 28.6139,
                "longitude": 77.2090,
            },
            token=login_data["access_token"],
        )
        self.assertEqual(status, 200)
        self.assertRegex(complaint["complaint_id"], r"^CMP-[A-F0-9]{8}$")
        self.assertEqual(complaint["status"], "SUBMITTED")
        self.assertEqual(complaint["category"], "Pothole & Road Damage")
        self.assertEqual(complaint["user_id"], identity["id"])

        history_status, history = self.request(
            "GET",
            "/complaints/my",
            token=login_data["access_token"],
        )
        self.assertEqual(history_status, 200)
        self.assertEqual([item["complaint_id"] for item in history], [
            complaint["complaint_id"]
        ])

    def test_complaint_history_and_detail_are_limited_to_the_owner(self):
        owner_status, owner_login = self.login("CITIZEN")
        other_status, other_login = self.login(
            "CITIZEN",
            email="other-citizen@example.com",
        )
        self.assertEqual(owner_status, 200)
        self.assertEqual(other_status, 200)

        create_status, complaint = self.request(
            "POST",
            "/complaints",
            {
                "description": "Streetlight is broken near the school gate",
                "category": "Broken Streetlight",
                "severity": "Medium",
                "latitude": 28.61,
                "longitude": 77.20,
            },
            token=owner_login["access_token"],
        )
        self.assertEqual(create_status, 200)

        owner_history_status, owner_history = self.request(
            "GET",
            "/complaints/my",
            token=owner_login["access_token"],
        )
        other_history_status, other_history = self.request(
            "GET",
            "/complaints/my",
            token=other_login["access_token"],
        )
        other_detail_status, _ = self.request(
            "GET",
            f"/complaints/{complaint['complaint_id']}",
            token=other_login["access_token"],
        )

        self.assertEqual(owner_history_status, 200)
        self.assertIn(
            complaint["complaint_id"],
            [item["complaint_id"] for item in owner_history],
        )
        self.assertEqual(other_history_status, 200)
        self.assertEqual(other_history, [])
        self.assertEqual(other_detail_status, 404)

    def test_complaint_detail_records_real_status_history_and_verification_eligibility(self):
        citizen, _, _, complaint = self.create_completed_complaint()

        detail_status, detail = self.request(
            "GET",
            f"/complaints/{complaint['complaint_id']}",
            token=citizen["access_token"],
        )

        self.assertEqual(detail_status, 200)
        self.assertEqual(detail["status"], "COMPLETED")
        self.assertTrue(detail["verification_eligible"])
        self.assertEqual(
            [event["status"] for event in detail["status_history"]],
            ["SUBMITTED", "ASSIGNED", "IN_PROGRESS", "COMPLETED"],
        )
        self.assertTrue(
            all(event["changed_at"] for event in detail["status_history"])
        )
        self.assertIsNone(detail["verification"])

    def test_citizen_verification_requires_owner_and_worker_completion(self):
        citizen_status, citizen = self.login("CITIZEN")
        other_status, other_citizen = self.login(
            "CITIZEN",
            email="other-citizen@example.com",
        )
        worker_status, worker = self.login("WORKER")
        self.assertEqual((citizen_status, other_status, worker_status), (200, 200, 200))
        complaint_status, complaint = self.request(
            "POST",
            "/complaints",
            {
                "description": "Large pothole beside the community centre entrance",
                "category": "Pothole & Road Damage",
                "severity": "High",
                "latitude": 28.61,
                "longitude": 77.20,
            },
            token=citizen["access_token"],
        )
        self.assertEqual(complaint_status, 200)

        premature_status, _ = self.submit_verification(
            complaint["complaint_id"],
            citizen["access_token"],
        )
        other_owner_status, _ = self.submit_verification(
            complaint["complaint_id"],
            other_citizen["access_token"],
        )
        wrong_role_status, _ = self.submit_verification(
            complaint["complaint_id"],
            worker["access_token"],
        )
        boundary = "sahaysetu-unauthenticated-boundary"
        unauthenticated_body = self.multipart_body(
            boundary,
            {"result": "RESOLVED"},
        )
        unauthenticated_status, _ = asyncio.run(
            asgi_request(
                "POST",
                f"/complaints/{complaint['complaint_id']}/verification",
                raw_body=unauthenticated_body,
                content_type=f"multipart/form-data; boundary={boundary}",
            )
        )

        self.assertEqual(premature_status, 409)
        self.assertEqual(other_owner_status, 404)
        self.assertEqual(wrong_role_status, 403)
        self.assertIn(unauthenticated_status, (401, 403))

    def test_citizen_can_confirm_resolution_with_private_evidence_once(self):
        citizen, _, worker, complaint = self.create_completed_complaint()
        png = (
            b"\x89PNG\r\n\x1a\n"
            b"\x00\x00\x00\x0dIHDR"
            b"\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00"
            b"\x1f\x15\xc4\x89"
            b"\x00\x00\x00\x0bIDAT\x08\xd7c\xf8\xcf\xc0\xf0\x1f\x00\x05"
            b"\x00\x01\xff\x89\x99\x3d\x1d"
            b"\x00\x00\x00\x00IEND\xaeB`\x82"
        )
        verify_status, verification = self.submit_verification(
            complaint["complaint_id"],
            citizen["access_token"],
            content=png,
        )

        self.assertEqual(verify_status, 200)
        self.assertEqual(verification["status"], "CITIZEN_VERIFIED")
        self.assertFalse(verification["verification_eligible"])
        self.assertEqual(verification["verification"]["result"], "RESOLVED")
        self.assertTrue(verification["verification"]["evidence_available"])
        self.assertEqual(
            verification["status_history"][-1]["event_type"],
            "CITIZEN_VERIFIED",
        )

        evidence_status, evidence_body = asyncio.run(
            asgi_request(
                "GET",
                f"/complaints/{complaint['complaint_id']}/verification/evidence",
                token=citizen["access_token"],
                parse_json=False,
            )
        )
        _, other_citizen = self.login(
            "CITIZEN",
            email="other-citizen@example.com",
        )
        other_evidence_status, _ = asyncio.run(
            asgi_request(
                "GET",
                f"/complaints/{complaint['complaint_id']}/verification/evidence",
                token=other_citizen["access_token"],
                parse_json=False,
            )
        )
        worker_evidence_status, worker_evidence = asyncio.run(
            asgi_request(
                "GET",
                f"/complaints/{complaint['complaint_id']}/verification/evidence",
                token=worker["access_token"],
                parse_json=False,
            )
        )
        duplicate_status, _ = self.submit_verification(
            complaint["complaint_id"],
            citizen["access_token"],
        )
        refreshed_status, refreshed = self.request(
            "GET",
            f"/complaints/{complaint['complaint_id']}",
            token=citizen["access_token"],
        )

        self.assertEqual(evidence_status, 200)
        self.assertEqual(evidence_body, png)
        self.assertEqual(other_evidence_status, 404)
        self.assertEqual(worker_evidence_status, 200)
        self.assertEqual(worker_evidence, png)
        self.assertEqual(duplicate_status, 409)
        self.assertEqual(refreshed_status, 200)
        self.assertEqual(refreshed["status"], "CITIZEN_VERIFIED")
        self.assertFalse(refreshed["verification_eligible"])

    def test_unresolved_verification_flags_authority_and_can_be_reassigned(self):
        citizen, authority, worker, complaint = self.create_completed_complaint()
        status, disputed = self.submit_verification(
            complaint["complaint_id"],
            citizen["access_token"],
            result="NOT_RESOLVED",
            feedback="The drain is still blocked.",
            filename=None,
        )
        self.assertEqual(status, 200)
        self.assertEqual(disputed["status"], "CITIZEN_DISPUTED")
        self.assertFalse(disputed["verification"]["evidence_available"])

        authority_status, authority_complaints = self.request(
            "GET",
            "/authority/complaints",
            token=authority["access_token"],
        )
        self.assertEqual(authority_status, 200)
        authority_complaint = next(
            item
            for item in authority_complaints
            if item["complaint_id"] == complaint["complaint_id"]
        )
        self.assertEqual(authority_complaint["status"], "CITIZEN_DISPUTED")

        _, worker_identity = self.request(
            "GET",
            "/auth/me",
            token=worker["access_token"],
        )
        reassign_status, reassigned = self.request(
            "PUT",
            f"/authority/complaints/{complaint['complaint_id']}/assign",
            {"worker_id": worker_identity["id"]},
            token=authority["access_token"],
        )
        self.assertEqual(reassign_status, 200)
        self.assertEqual(reassigned["status"], "ASSIGNED")
        for next_status in ("IN_PROGRESS", "COMPLETED"):
            transition_status, _ = self.request(
                "PUT",
                f"/worker/complaints/{complaint['complaint_id']}/status",
                {"status": next_status},
                token=worker["access_token"],
            )
            self.assertEqual(transition_status, 200)

        detail_status, detail = self.request(
            "GET",
            f"/complaints/{complaint['complaint_id']}",
            token=citizen["access_token"],
        )
        self.assertEqual(detail_status, 200)
        self.assertTrue(detail["verification_eligible"])
        second_response_status, second_response = self.submit_verification(
            complaint["complaint_id"],
            citizen["access_token"],
            result="RESOLVED",
            feedback="The follow-up repair resolved the problem.",
            filename=None,
        )
        self.assertEqual(second_response_status, 200)
        self.assertEqual(second_response["status"], "CITIZEN_VERIFIED")
        self.assertEqual(
            sum(
                event["event_type"] == "CITIZEN_DISPUTED"
                for event in second_response["status_history"]
            ),
            1,
        )
        self.assertEqual(
            sum(
                event["event_type"] == "CITIZEN_VERIFIED"
                for event in second_response["status_history"]
            ),
            1,
        )

    def test_verification_upload_rejects_invalid_image_type_and_size(self):
        citizen, _, _, complaint = self.create_completed_complaint()
        invalid_type_status, _ = self.submit_verification(
            complaint["complaint_id"],
            citizen["access_token"],
            content=b"not an image",
        )
        oversized_status, _ = self.submit_verification(
            complaint["complaint_id"],
            citizen["access_token"],
            content=b"\x89PNG\r\n\x1a\n"
            + b"\x00" * (5 * 1024 * 1024),
        )
        self.assertEqual(invalid_type_status, 415)
        self.assertEqual(oversized_status, 413)

    def test_complaint_creation_validates_required_fields_and_coordinate_ranges(self):
        citizen_status, citizen = self.login("CITIZEN")
        self.assertEqual(citizen_status, 200)
        valid_body = {
            "description": "Garbage has accumulated beside the market entrance",
            "category": "Garbage Accumulation",
            "severity": "Low",
            "latitude": 28.61,
            "longitude": 77.20,
        }

        missing_description = dict(valid_body)
        del missing_description["description"]
        status, _ = self.request(
            "POST",
            "/complaints",
            missing_description,
            token=citizen["access_token"],
        )
        self.assertEqual(status, 422)

        short_description = dict(valid_body, description="Short")
        status, _ = self.request(
            "POST",
            "/complaints",
            short_description,
            token=citizen["access_token"],
        )
        self.assertEqual(status, 422)

        invalid_coordinates = dict(valid_body, latitude=91)
        status, _ = self.request(
            "POST",
            "/complaints",
            invalid_coordinates,
            token=citizen["access_token"],
        )
        self.assertEqual(status, 422)

    def test_complaint_creation_requires_citizen_authentication(self):
        body = {
            "description": "Water is leaking from a pipe near the park",
            "category": "Water Leakage",
            "severity": "Medium",
            "latitude": 28.61,
            "longitude": 77.20,
        }

        unauthenticated_status, _ = self.request(
            "POST",
            "/complaints",
            body,
        )
        worker_status, worker = self.login("WORKER")
        self.assertEqual(worker_status, 200)
        wrong_role_status, _ = self.request(
            "POST",
            "/complaints",
            body,
            token=worker["access_token"],
        )

        self.assertIn(unauthenticated_status, (401, 403))
        self.assertEqual(wrong_role_status, 403)

    def test_authority_assignment_is_persisted_and_visible_in_worker_queue(self):
        citizen_status, citizen = self.login("CITIZEN")
        authority_status, authority = self.login("AUTHORITY")
        worker_status, worker = self.login("WORKER")
        other_worker_status, other_worker = self.login(
            "WORKER",
            email="other-worker@example.com",
        )
        self.assertEqual(citizen_status, 200)
        self.assertEqual(authority_status, 200)
        self.assertEqual(worker_status, 200)
        self.assertEqual(other_worker_status, 200)

        _, worker_identity = self.request(
            "GET",
            "/auth/me",
            token=worker["access_token"],
        )
        complaint_status, complaint = self.request(
            "POST",
            "/complaints",
            {
                "description": "Large pothole beside the community centre entrance",
                "category": "Pothole & Road Damage",
                "severity": "High",
                "latitude": 28.61,
                "longitude": 77.20,
            },
            token=citizen["access_token"],
        )
        self.assertEqual(complaint_status, 200)

        denied_status, _ = self.request(
            "PUT",
            f"/authority/complaints/{complaint['complaint_id']}/assign",
            {"worker_id": worker_identity["id"]},
            token=worker["access_token"],
        )
        self.assertEqual(denied_status, 403)

        assignment_status, assigned = self.request(
            "PUT",
            f"/authority/complaints/{complaint['complaint_id']}/assign",
            {"worker_id": worker_identity["id"]},
            token=authority["access_token"],
        )
        self.assertEqual(assignment_status, 200)
        self.assertEqual(assigned["assigned_worker_id"], worker_identity["id"])
        self.assertEqual(assigned["assigned_worker_name"], "Test Worker")
        self.assertEqual(assigned["status"], "ASSIGNED")

        queue_status, queue = self.request(
            "GET",
            "/worker/complaints",
            token=worker["access_token"],
        )
        other_queue_status, other_queue = self.request(
            "GET",
            "/worker/complaints",
            token=other_worker["access_token"],
        )
        self.assertEqual(queue_status, 200)
        self.assertIn(complaint["complaint_id"], [
            item["complaint_id"] for item in queue
        ])
        self.assertEqual(other_queue_status, 200)
        self.assertEqual(other_queue, [])

        eligible_status, eligible = self.request(
            "GET",
            f"/authority/complaints/{complaint['complaint_id']}/eligible-workers",
            token=authority["access_token"],
        )
        self.assertEqual(eligible_status, 200)
        self.assertEqual(
            {item["id"] for item in eligible["workers"]},
            {
                worker_identity["id"],
                self.request(
                    "GET",
                    "/auth/me",
                    token=other_worker["access_token"],
                )[1]["id"],
            },
        )

        other_worker_identity_status, other_worker_identity = self.request(
            "GET",
            "/auth/me",
            token=other_worker["access_token"],
        )
        self.assertEqual(other_worker_identity_status, 200)
        reassign_status, reassigned = self.request(
            "PUT",
            f"/authority/complaints/{complaint['complaint_id']}/assign",
            {"worker_id": other_worker_identity["id"]},
            token=authority["access_token"],
        )
        self.assertEqual(reassign_status, 200)
        self.assertEqual(
            reassigned["assigned_worker_name"],
            "Other Test Worker",
        )
        old_queue_status, old_queue = self.request(
            "GET",
            "/worker/complaints",
            token=worker["access_token"],
        )
        new_queue_status, new_queue = self.request(
            "GET",
            "/worker/complaints",
            token=other_worker["access_token"],
        )
        self.assertEqual(old_queue_status, 200)
        self.assertEqual(new_queue_status, 200)
        self.assertEqual(old_queue, [])
        self.assertIn(
            complaint["complaint_id"],
            [item["complaint_id"] for item in new_queue],
        )
    def test_worker_can_update_only_assigned_complaint_to_supported_statuses(self):
        citizen_status, citizen = self.login("CITIZEN")
        authority_status, authority = self.login("AUTHORITY")
        worker_status, worker = self.login("WORKER")
        other_worker_status, other_worker = self.login(
            "WORKER",
            email="other-worker@example.com",
        )
        self.assertEqual(citizen_status, 200)
        self.assertEqual(authority_status, 200)
        self.assertEqual(worker_status, 200)
        self.assertEqual(other_worker_status, 200)

        _, worker_identity = self.request(
            "GET",
            "/auth/me",
            token=worker["access_token"],
        )
        _, complaint = self.request(
            "POST",
            "/complaints",
            {
                "description": "Road surface is damaged outside the library",
                "category": "Pothole & Road Damage",
                "severity": "Medium",
                "latitude": 28.61,
                "longitude": 77.20,
            },
            token=citizen["access_token"],
        )
        assigned_status, _ = self.request(
            "PUT",
            f"/authority/complaints/{complaint['complaint_id']}/assign",
            {"worker_id": worker_identity["id"]},
            token=authority["access_token"],
        )
        self.assertEqual(assigned_status, 200)

        wrong_worker_status, _ = self.request(
            "PUT",
            f"/worker/complaints/{complaint['complaint_id']}/status",
            {"status": "IN_PROGRESS"},
            token=other_worker["access_token"],
        )
        self.assertEqual(wrong_worker_status, 404)

        for new_status in ("IN_PROGRESS", "COMPLETED"):
            status, updated = self.request(
                "PUT",
                f"/worker/complaints/{complaint['complaint_id']}/status",
                {"status": new_status},
                token=worker["access_token"],
            )
            self.assertEqual(status, 200)
            self.assertEqual(updated["status"], new_status)

        invalid_status, _ = self.request(
            "PUT",
            f"/worker/complaints/{complaint['complaint_id']}/status",
            {"status": "SUBMITTED"},
            token=worker["access_token"],
        )
        self.assertEqual(invalid_status, 400)

        invalid_transition, _ = self.request(
            "PUT",
            f"/worker/complaints/{complaint['complaint_id']}/status",
            {"status": "IN_PROGRESS"},
            token=worker["access_token"],
        )
        self.assertEqual(invalid_transition, 409)

        queue_status, queue = self.request(
            "GET",
            "/worker/complaints",
            token=worker["access_token"],
        )
        self.assertEqual(queue_status, 200)
        saved_complaint = next(
            item for item in queue
            if item["complaint_id"] == complaint["complaint_id"]
        )
        self.assertEqual(saved_complaint["status"], "COMPLETED")

    def test_authority_incident_work_and_recovery_records_round_trip(self):
        citizen_status, citizen = self.login("CITIZEN")
        authority_status, authority = self.login("AUTHORITY")
        worker_status, worker = self.login("WORKER")
        self.assertEqual(citizen_status, 200)
        self.assertEqual(authority_status, 200)
        self.assertEqual(worker_status, 200)

        complaint_status, complaint = self.request(
            "POST",
            "/complaints",
            {
                "description": "Road surface has a deep pothole outside the clinic",
                "category": "Pothole & Road Damage",
                "severity": "High",
                "latitude": 28.61,
                "longitude": 77.20,
            },
            token=citizen["access_token"],
        )
        self.assertEqual(complaint_status, 200)

        db = TestSession()
        incident = Incident(
            incident_id="INC-TEST-FLOW",
            title="Test road incident",
            description="Isolated workflow fixture",
            incident_type="Pothole & Road Damage",
            status="DETECTED",
            latitude=28.61,
            longitude=77.20,
        )
        db.add(incident)
        db.flush()
        complaint_record = db.query(Complaint).filter(
            Complaint.complaint_id == complaint["complaint_id"]
        ).one()
        complaint_record.incident_id = incident.id
        db.commit()
        db.close()

        relationship_status, relationship_data = self.request(
            "GET",
            "/authority/incidents/INC-TEST-FLOW/relationships",
            token=authority["access_token"],
        )
        self.assertEqual(relationship_status, 200)
        self.assertEqual(relationship_data["complaint_count"], 1)
        self.assertEqual(relationship_data["relationships"], [])

        recommendation_status, recommendation_data = self.request(
            "GET",
            "/authority/incidents/INC-TEST-FLOW/interventions",
            token=authority["access_token"],
        )
        self.assertEqual(recommendation_status, 200)
        self.assertEqual(
            recommendation_data["interventions"][0]["intervention"],
            "ROAD_REPAIR",
        )

        create_status, intervention = self.request(
            "POST",
            "/authority/incidents/INC-TEST-FLOW/interventions",
            {
                "intervention_type": "ROAD_REPAIR",
                "expected_impact_score": 90,
                "notes": "Test record only",
            },
            token=authority["access_token"],
        )
        self.assertEqual(create_status, 200)
        self.assertEqual(intervention["status"], "PLANNED")

        records_status, records = self.request(
            "GET",
            "/authority/incidents/INC-TEST-FLOW/interventions/records",
            token=authority["access_token"],
        )
        self.assertEqual(records_status, 200)
        self.assertEqual(
            [record["intervention_id"] for record in records],
            [intervention["intervention_id"]],
        )

        early_recovery_status, _ = self.request(
            "POST",
            "/authority/incidents/INC-TEST-FLOW/recovery",
            {
                "incident_id": "INC-TEST-FLOW",
                "intervention_id": intervention["intervention_id"],
                "recovery_score": 50,
            },
            token=authority["access_token"],
        )
        self.assertEqual(early_recovery_status, 409)

        for status_value in ("IN_PROGRESS", "COMPLETED"):
            status, updated = self.request(
                "PUT",
                f"/authority/interventions/{intervention['intervention_id']}/status",
                {"status": status_value},
                token=authority["access_token"],
            )
            self.assertEqual(status, 200)
            self.assertEqual(updated["status"], status_value)

        invalid_transition_status, _ = self.request(
            "PUT",
            f"/authority/interventions/{intervention['intervention_id']}/status",
            {"status": "IN_PROGRESS"},
            token=authority["access_token"],
        )
        self.assertEqual(invalid_transition_status, 409)

        observation_status, observation = self.request(
            "POST",
            "/authority/incidents/INC-TEST-FLOW/recovery",
            {
                "incident_id": "INC-TEST-FLOW",
                "intervention_id": intervention["intervention_id"],
                "recovery_score": 75,
                "evidence": "Visual inspection completed",
                "notes": "Test observation only",
            },
            token=authority["access_token"],
        )
        self.assertEqual(observation_status, 200)
        self.assertEqual(observation["observation_status"], "RECOVERED")

        history_status, history = self.request(
            "GET",
            "/authority/incidents/INC-TEST-FLOW/recovery",
            token=authority["access_token"],
        )
        self.assertEqual(history_status, 200)
        self.assertEqual(len(history), 1)
        self.assertEqual(history[0]["id"], observation["id"])
        self.assertEqual(
            history[0]["intervention_id"],
            intervention["intervention_id"],
        )

        recurrence_status, recurrence = self.request(
            "GET",
            "/authority/incidents/INC-TEST-FLOW/recurrence",
            token=authority["access_token"],
        )
        self.assertEqual(recurrence_status, 200)
        self.assertFalse(recurrence["recurrence_detected"])

        prevention_status, prevention = self.request(
            "GET",
            "/authority/incidents/INC-TEST-FLOW/prevention",
            token=authority["access_token"],
        )
        self.assertEqual(prevention_status, 200)
        self.assertEqual(prevention["recommendations"], [])

        unauthorized_status, _ = self.request(
            "GET",
            "/authority/incidents/INC-TEST-FLOW/recovery",
            token=worker["access_token"],
        )
        self.assertEqual(unauthorized_status, 403)

        invalid_score_status, _ = self.request(
            "POST",
            "/authority/incidents/INC-TEST-FLOW/recovery",
            {
                "incident_id": "INC-TEST-FLOW",
                "intervention_id": intervention["intervention_id"],
                "recovery_score": 101,
            },
            token=authority["access_token"],
        )
        self.assertEqual(invalid_score_status, 422)

    def test_authority_fusion_links_only_unlinked_nearby_reports(self):
        citizen_status, citizen = self.login("CITIZEN")
        authority_status, authority = self.login("AUTHORITY")
        self.assertEqual(citizen_status, 200)
        self.assertEqual(authority_status, 200)

        complaint_ids = []
        for description, latitude in (
            ("Deep pothole near the east entrance of the park", 28.6100),
            ("Road damage near the park east entrance", 28.6101),
        ):
            status, complaint = self.request(
                "POST",
                "/complaints",
                {
                    "description": description,
                    "category": "Pothole & Road Damage",
                    "severity": "Medium",
                    "latitude": latitude,
                    "longitude": 77.20,
                },
                token=citizen["access_token"],
            )
            self.assertEqual(status, 200)
            complaint_ids.append(complaint["complaint_id"])

        fusion_status, fusion = self.request(
            "POST",
            f"/authority/incidents/fuse/{complaint_ids[0]}",
            token=authority["access_token"],
        )
        self.assertEqual(fusion_status, 200)
        self.assertEqual(fusion["complaint_count"], 2)
        self.assertEqual(set(fusion["complaints"]), set(complaint_ids))

        duplicate_fusion_status, _ = self.request(
            "POST",
            f"/authority/incidents/fuse/{complaint_ids[0]}",
            token=authority["access_token"],
        )
        self.assertEqual(duplicate_fusion_status, 409)


if __name__ == "__main__":
    unittest.main()
