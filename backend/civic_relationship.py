# Rule-based civic relationship model


RELATIONSHIP_RULES = {
    ("BLOCKED_DRAIN", "WATERLOGGING"): {
        "relationship": "POSSIBLE_CONTRIBUTING_RELATIONSHIP",
        "explanation": (
            "Blocked drainage may be contributing to "
            "water accumulation or waterlogging."
        )
    },

    ("DRAINAGE", "WATERLOGGING"): {
        "relationship": "POSSIBLE_CONTRIBUTING_RELATIONSHIP",
        "explanation": (
            "A drainage-related condition may be contributing "
            "to water accumulation or waterlogging."
        )
    },

    ("WATERLOGGING", "ROAD_DAMAGE"): {
        "relationship": "POSSIBLE_ASSOCIATION",
        "explanation": (
            "Repeated water accumulation may be associated "
            "with deterioration of the road surface."
        )
    },

    ("BLOCKED_DRAIN", "ROAD_DAMAGE"): {
        "relationship": "POSSIBLE_ASSOCIATION",
        "explanation": (
            "A drainage problem may be associated with "
            "persistent road deterioration in the affected area."
        )
    }
}


def get_relationship(category1, category2):
    """
    Find a possible relationship between two civic categories.

    The result represents a rule-based hypothesis,
    not confirmed causation.
    """

    rule = RELATIONSHIP_RULES.get(
        (category1, category2)
    )

    if rule:
        return rule

    # Check reverse direction
    rule = RELATIONSHIP_RULES.get(
        (category2, category1)
    )

    if rule:
        return rule

    return {
        "relationship": "NO_DEFINED_RELATIONSHIP",
        "explanation": (
            "No predefined relationship was identified "
            "between these observations."
        )
    }


def analyze_relationships(complaints):
    """
    Analyze possible relationships among complaints
    belonging to the same civic incident.
    """

    relationships = []

    for i in range(len(complaints)):
        for j in range(i + 1, len(complaints)):

            complaint1 = complaints[i]
            complaint2 = complaints[j]

            result = get_relationship(
                complaint1.category,
                complaint2.category
            )

            if result["relationship"] != "NO_DEFINED_RELATIONSHIP":
                relationships.append({
                    "complaint_1": complaint1.complaint_id,
                    "category_1": complaint1.category,

                    "complaint_2": complaint2.complaint_id,
                    "category_2": complaint2.category,

                    "relationship": result["relationship"],
                    "explanation": result["explanation"]
                })

    return relationships