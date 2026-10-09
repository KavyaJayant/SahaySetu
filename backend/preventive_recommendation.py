PREVENTION_RULES = {
    "WATERLOGGING": {
        "recommendation": "PERIODIC_DRAINAGE_INSPECTION",
        "reason": (
            "Repeated waterlogging may indicate a recurring "
            "drainage-related condition. Periodic inspection "
            "can help identify the issue before severe "
            "water accumulation occurs."
        ),
        "priority": "HIGH"
    },

    "BLOCKED_DRAIN": {
        "recommendation": "SCHEDULED_DRAIN_CLEANING",
        "reason": (
            "Repeated blocked-drain observations suggest "
            "that scheduled cleaning may reduce recurrence "
            "of drainage-related problems."
        ),
        "priority": "HIGH"
    },

    "DRAINAGE": {
        "recommendation": "DRAINAGE_SYSTEM_INSPECTION",
        "reason": (
            "Recurring drainage-related observations may "
            "indicate the need for periodic inspection of "
            "the affected drainage system."
        ),
        "priority": "HIGH"
    },

    "ROAD_DAMAGE": {
        "recommendation": "PERIODIC_ROAD_CONDITION_INSPECTION",
        "reason": (
            "Repeated road-damage observations may indicate "
            "an underlying maintenance issue. Periodic "
            "inspection can help identify deterioration earlier."
        ),
        "priority": "MEDIUM"
    }
}


def generate_preventive_recommendations(
    complaints,
    recurrence_detected
):
    recommendations = []

    if not recurrence_detected:
        return recommendations

    categories = set(
        complaint.category
        for complaint in complaints
    )

    for category in categories:
        rule = PREVENTION_RULES.get(category)

        if rule is None:
            continue

        recommendations.append({
            "category": category,
            "recommendation": rule["recommendation"],
            "priority": rule["priority"],
            "reason": rule["reason"]
        })

    return recommendations