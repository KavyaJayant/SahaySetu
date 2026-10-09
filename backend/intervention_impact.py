# Rule-based Intervention Impact Assessment


INTERVENTION_RULES = {
    "BLOCKED_DRAIN": [
        {
            "intervention": "DRAIN_CLEANING",
            "impact": "HIGH",
            "score": 90,
            "reason": (
                "Directly addresses the identified "
                "drainage condition."
            )
        },
        {
            "intervention": "TEMPORARY_WATER_PUMPING",
            "impact": "MEDIUM",
            "score": 60,
            "reason": (
                "Can reduce current water accumulation "
                "but does not address the underlying "
                "drainage condition."
            )
        },
        {
            "intervention": "ROAD_REPAIR",
            "impact": "LOW",
            "score": 30,
            "reason": (
                "Addresses possible associated road damage "
                "rather than the drainage condition."
            )
        }
    ],

    "WATERLOGGING": [
        {
            "intervention": "DRAIN_CLEANING",
            "impact": "HIGH",
            "score": 85,
            "reason": (
                "May address a contributing drainage "
                "condition associated with waterlogging."
            )
        },
        {
            "intervention": "TEMPORARY_WATER_PUMPING",
            "impact": "MEDIUM",
            "score": 65,
            "reason": (
                "Addresses the immediate water accumulation "
                "without necessarily resolving its source."
            )
        },
        {
            "intervention": "ROAD_REPAIR",
            "impact": "LOW",
            "score": 35,
            "reason": (
                "May improve associated road conditions "
                "but does not directly address water accumulation."
            )
        }
    ],

    "ROAD_DAMAGE": [
        {
            "intervention": "ROAD_REPAIR",
            "impact": "HIGH",
            "score": 90,
            "reason": (
                "Directly addresses the identified "
                "road condition."
            )
        },
        {
            "intervention": "DRAIN_CLEANING",
            "impact": "MEDIUM",
            "score": 55,
            "reason": (
                "May reduce a drainage-related factor "
                "that could contribute to further deterioration."
            )
        }
    ],

    "DRAINAGE": [
        {
            "intervention": "DRAIN_CLEANING",
            "impact": "HIGH",
            "score": 90,
            "reason": (
                "Directly addresses the drainage condition."
            )
        },
        {
            "intervention": "TEMPORARY_WATER_PUMPING",
            "impact": "MEDIUM",
            "score": 55,
            "reason": (
                "Provides temporary relief from "
                "water accumulation."
            )
        }
    ]
}


def assess_interventions(complaints, relationships):
    """
    Rank candidate interventions for a connected
    civic incident.

    Scores represent expected impact based on
    predefined rules. They are not measured outcomes.
    """

    intervention_scores = {}

    # Use complaint categories to identify
    # relevant candidate interventions.
    for complaint in complaints:

        rules = INTERVENTION_RULES.get(
            complaint.category,
            []
        )

        for rule in rules:

            intervention = rule["intervention"]

            if intervention not in intervention_scores:
                intervention_scores[intervention] = {
                    "intervention": intervention,
                    "score": 0,
                    "reasons": [],
                    "impact": rule["impact"]
                }

            intervention_scores[intervention]["score"] += (
                rule["score"]
            )

            intervention_scores[intervention]["reasons"].append(
                rule["reason"]
            )

    # Increase relevance when an intervention directly
    # relates to a possible contributing relationship.
    for relationship in relationships:

        if relationship["relationship"] != (
            "POSSIBLE_CONTRIBUTING_RELATIONSHIP"
        ):
            continue

        categories = {
            relationship["category_1"],
            relationship["category_2"]
        }

        if "BLOCKED_DRAIN" in categories:
            intervention = "DRAIN_CLEANING"

            if intervention in intervention_scores:
                intervention_scores[intervention]["score"] += 20

    # Convert dictionary to ranked list.
    ranked_interventions = list(
        intervention_scores.values()
    )

    ranked_interventions.sort(
        key=lambda item: item["score"],
        reverse=True
    )

    # Add rank and cap displayed score at 100.
    for index, item in enumerate(
        ranked_interventions,
        start=1
    ):
        item["rank"] = index
        item["expected_impact_score"] = min(
            item["score"],
            100
        )

        del item["score"]

    return ranked_interventions