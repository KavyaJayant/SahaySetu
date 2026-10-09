from math import radians, sin, cos, sqrt, atan2
from datetime import timedelta

from models import Complaint


# Maximum distance between complaints in metres
FUSION_DISTANCE_METERS = 300

# Maximum time difference between complaints
FUSION_TIME_DAYS = 30


# Categories that can represent related observations
RELATED_CATEGORIES = {
    "WATERLOGGING": {
        "WATERLOGGING",
        "BLOCKED_DRAIN",
        "DRAINAGE",
        "ROAD_DAMAGE"
    },
    "BLOCKED_DRAIN": {
        "WATERLOGGING",
        "BLOCKED_DRAIN",
        "DRAINAGE",
        "ROAD_DAMAGE"
    },
    "DRAINAGE": {
        "WATERLOGGING",
        "BLOCKED_DRAIN",
        "DRAINAGE",
        "ROAD_DAMAGE"
    },
    "ROAD_DAMAGE": {
        "WATERLOGGING",
        "BLOCKED_DRAIN",
        "DRAINAGE",
        "ROAD_DAMAGE"
    }
}


def calculate_distance_meters(
    lat1,
    lon1,
    lat2,
    lon2
):
    """
    Calculate approximate distance between two
    geographical coordinates using the Haversine formula.
    """

    earth_radius = 6371000

    lat1 = radians(lat1)
    lat2 = radians(lat2)

    delta_lat = radians(lat2 - lat1)
    delta_lon = radians(lon2 - lon1)

    a = (
        sin(delta_lat / 2) ** 2
        + cos(lat1)
        * cos(lat2)
        * sin(delta_lon / 2) ** 2
    )

    c = 2 * atan2(sqrt(a), sqrt(1 - a))

    return earth_radius * c


def are_categories_related(category1, category2):
    """
    Check whether two complaint categories
    are considered related.
    """

    related_categories = RELATED_CATEGORIES.get(
        category1,
        {category1}
    )

    return category2 in related_categories


def calculate_fusion_score(
    complaint1,
    complaint2
):
    """
    Calculate a simple fusion score based on:
    - geographical proximity
    - temporal proximity
    - category relationship
    """

    score = 0

    # 1. Geographic relationship
    distance = calculate_distance_meters(
        complaint1.latitude,
        complaint1.longitude,
        complaint2.latitude,
        complaint2.longitude
    )

    if distance <= FUSION_DISTANCE_METERS:
        score += 40

    # 2. Category relationship
    if are_categories_related(
        complaint1.category,
        complaint2.category
    ):
        score += 30

    # 3. Temporal relationship
    time_difference = abs(
        complaint1.created_at - complaint2.created_at
    )

    if time_difference <= timedelta(days=FUSION_TIME_DAYS):
        score += 30

    return score


def find_related_complaints(
    complaint,
    complaints
):
    """
    Find complaints that may belong to the
    same or connected civic incident.
    """

    related = []

    for other in complaints:

        if other.id == complaint.id:
            continue

        distance = calculate_distance_meters(
            complaint.latitude,
            complaint.longitude,
            other.latitude,
            other.longitude
        )

        if distance > FUSION_DISTANCE_METERS:
            continue

        time_difference = abs(
            complaint.created_at - other.created_at
        )

        if time_difference > timedelta(days=FUSION_TIME_DAYS):
            continue

        if not are_categories_related(
            complaint.category,
            other.category
        ):
            continue

        score = calculate_fusion_score(
            complaint,
            other
        )

        related.append({
            "complaint": other,
            "distance_meters": round(distance, 2),
            "fusion_score": score
        })

    return related