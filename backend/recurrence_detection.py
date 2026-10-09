from datetime import timedelta


RECURRENCE_DISTANCE_METERS = 300
RECURRENCE_TIME_DAYS = 30


def calculate_recurrence_distance(
    calculate_distance_function,
    complaint1,
    complaint2
):
    return calculate_distance_function(
        complaint1.latitude,
        complaint1.longitude,
        complaint2.latitude,
        complaint2.longitude
    )


def is_recurrence_candidate(
    original_complaint,
    new_complaint,
    distance_meters,
    recovery_status
):
    if recovery_status not in [
        "RECOVERED",
        "RECOVERING"
    ]:
        return False

    if distance_meters > RECURRENCE_DISTANCE_METERS:
        return False

    if new_complaint.created_at <= original_complaint.created_at:
        return False

    time_difference = (
        new_complaint.created_at
        - original_complaint.created_at
    )

    if time_difference > timedelta(
        days=RECURRENCE_TIME_DAYS
    ):
        return False

    if original_complaint.category != new_complaint.category:
        return False

    return True


def detect_recurrence(
    original_complaint,
    complaints,
    calculate_distance_function
):
    recurrence_candidates = []

    for complaint in complaints:
        if complaint.id == original_complaint.id:
            continue

        distance = calculate_recurrence_distance(
            calculate_distance_function,
            original_complaint,
            complaint
        )

        if is_recurrence_candidate(
            original_complaint,
            complaint,
            distance
        ):
            recurrence_candidates.append({
                "complaint": complaint,
                "distance_meters": round(
                    distance,
                    2
                )
            })

    return recurrence_candidates