from datetime import datetime
from types import SimpleNamespace

from civic_relationship import get_relationship
from incident_fusion import are_categories_related
from intervention_impact import assess_interventions
from preventive_recommendation import generate_preventive_recommendations
from recurrence_detection import is_recurrence_candidate


def test_exact_mobile_categories_match_incident_fusion_and_relationship_rules():
    assert are_categories_related(
        "Pothole & Road Damage",
        "Blocked Drainage",
    )
    relationship = get_relationship(
        "Blocked Drainage",
        "Pothole & Road Damage",
    )
    assert relationship["relationship"] == "POSSIBLE_ASSOCIATION"


def test_exact_mobile_categories_match_intervention_and_prevention_rules():
    complaint = SimpleNamespace(category="Pothole & Road Damage")
    interventions = assess_interventions([complaint], [])
    assert interventions[0]["intervention"] == "ROAD_REPAIR"

    recommendations = generate_preventive_recommendations(
        [SimpleNamespace(category="Blocked Drainage")],
        recurrence_detected=True,
    )
    assert recommendations[0]["recommendation"] == "SCHEDULED_DRAIN_CLEANING"


def test_recurrence_accepts_consistent_mobile_and_legacy_category_values():
    original = SimpleNamespace(
        id=1,
        category="Blocked Drainage",
        created_at=datetime(2025, 1, 1),
    )
    follow_up = SimpleNamespace(
        id=2,
        category="BLOCKED_DRAIN",
        created_at=datetime(2025, 1, 2),
    )
    assert is_recurrence_candidate(
        original,
        follow_up,
        distance_meters=25,
        recovery_status="RECOVERED",
    )


def test_recurrence_rejects_different_supported_categories():
    original = SimpleNamespace(
        id=1,
        category="Pothole & Road Damage",
        created_at=datetime(2025, 1, 1),
    )
    follow_up = SimpleNamespace(
        id=2,
        category="Broken Streetlight",
        created_at=datetime(2025, 1, 2),
    )
    assert not is_recurrence_candidate(
        original,
        follow_up,
        distance_meters=25,
        recovery_status="RECOVERED",
    )
