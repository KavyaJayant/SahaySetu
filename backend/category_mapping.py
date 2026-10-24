"""Safe mappings between citizen-facing complaint categories and worker categories."""

import unicodedata


CATEGORY_LABELS = (
    "Pothole & Road Damage",
    "Broken Streetlight",
    "Garbage Accumulation",
    "Water Leakage",
    "Blocked Drainage",
)


def _key(value: str) -> str:
    return " ".join(
        unicodedata.normalize("NFKC", value).casefold().split()
    )


_ALIASES = {
    "Pothole & Road Damage": (
        "ROAD_DAMAGE",
        "POTHOLE",
        "POTHOLE_AND_ROAD_DAMAGE",
    ),
    "Broken Streetlight": (
        "BROKEN_STREETLIGHT",
    ),
    "Garbage Accumulation": (
        "GARBAGE_ACCUMULATION",
    ),
    "Water Leakage": (
        "WATER_LEAKAGE",
        "WATER_LEAK",
    ),
    "Blocked Drainage": (
        "BLOCKED_DRAIN",
        "BLOCKED_DRAINAGE",
    ),
}

_CATEGORY_BY_KEY = {
    _key(alias): category
    for category in CATEGORY_LABELS
    for alias in (category, *_ALIASES[category])
}

_ANALYSIS_KEY_BY_CATEGORY = {
    "Pothole & Road Damage": "ROAD_DAMAGE",
    "Broken Streetlight": "BROKEN_STREETLIGHT",
    "Garbage Accumulation": "GARBAGE_ACCUMULATION",
    "Water Leakage": "WATER_LEAKAGE",
    "Blocked Drainage": "BLOCKED_DRAIN",
}


def category_for_assignment(value: str | None) -> str | None:
    """Return a supported category label, or None when the value is ambiguous."""
    if not value or not value.strip():
        return None
    return _CATEGORY_BY_KEY.get(_key(value))


def category_analysis_key(value: str | None) -> str | None:
    """Map supported labels and legacy keys to a shared analysis key."""
    if not value or not value.strip():
        return None
    category = category_for_assignment(value)
    if category is not None:
        return _ANALYSIS_KEY_BY_CATEGORY[category]
    return value.strip().upper().replace(" ", "_")
