def determine_recovery_status(recovery_score: float):
    if recovery_score < 0 or recovery_score > 100:
        raise ValueError(
            "Recovery score must be between 0 and 100"
        )

    if recovery_score < 40:
        return "NOT_RECOVERED"

    if recovery_score < 70:
        return "RECOVERING"

    return "RECOVERED"


def create_recovery_observation(
    recovery_score: float,
    evidence: str | None = None,
    notes: str | None = None
):
    status = determine_recovery_status(
        recovery_score
    )

    return {
        "observation_status": status,
        "recovery_score": recovery_score,
        "evidence": evidence,
        "notes": notes
    }