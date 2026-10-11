from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity


def find_related_incidents(new_complaint, historical_complaints, limit=5):
    """Rank historical complaints by text, category and geographic proximity."""

    if not historical_complaints:
        return []

    def norm(value):
        return " ".join(str(value or "").lower().strip().split())

    def text(item):
        return " ".join([
            norm(item.category),
            norm(item.description),
        ])

    old_items = [
        item for item in historical_complaints
        if item.id != new_complaint.id
    ]

    if not old_items:
        return []

    documents = [text(item) for item in old_items] + [text(new_complaint)]

    try:
        vectors = TfidfVectorizer(ngram_range=(1, 2)).fit_transform(documents)
    except ValueError:
        return []

    similarities = cosine_similarity(vectors[-1], vectors[:-1])[0]
    results = []

    for item, similarity in zip(old_items, similarities):
        category_match = norm(item.category) == norm(new_complaint.category)

        # Approximate distance using latitude/longitude.
        from math import radians, sin, cos, asin, sqrt

        lat1, lon1 = radians(new_complaint.latitude), radians(new_complaint.longitude)
        lat2, lon2 = radians(item.latitude), radians(item.longitude)
        dlat, dlon = lat2 - lat1, lon2 - lon1
        a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
        distance_m = 6371000 * 2 * asin(sqrt(min(1.0, a)))

        location_match = distance_m <= 300

        score = min(
            float(similarity)
            + (0.15 if category_match else 0)
            + (0.25 if location_match else 0),
            1.0,
        )

        results.append({
            "complaint_id": item.complaint_id,
            "category": item.category,
            "description": item.description,
            "distance_meters": round(distance_m, 1),
            "similarity": round(float(similarity), 4),
            "related_score": round(score, 4),
            "category_match": category_match,
            "location_match": location_match,
        })

    ranked_results = sorted(
    results,
    key=lambda result: result["related_score"],
    reverse=True
    )

    return [
      result for result in ranked_results
      if result["related_score"] >= 0.30
    ][:limit]