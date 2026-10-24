A citizen-centric grievance platform designed to simplify reporting, connect citizens with
the appropriate authorities, and enable transparent and accountable resolution.

## Planned BBMP 2024–2025 grievance-data integration

This is a proposal only; no historical dataset has been imported. The repository currently contains `aiml/complaints.csv`, a 21-row prototype file with the columns `complaint_id`, `category`, `description`, `location`, `severity`, and `status`. It is not the BBMP 2024/2025 source described below, so it must not be treated as that dataset or loaded into live complaints.

### Safe import pipeline

1. **Receive and identify source files.** Keep each original CSV immutable, record the source name/year, receipt date, encoding, file checksum, and import-batch ID. Do not overwrite a previous source file.
2. **Validate structure and data quality.** Require and map the supplied complaint ID, category, subcategory, grievance date, ward name, grievance status, staff remarks, and staff name columns. Check missing IDs/dates/categories/wards, malformed dates, duplicate IDs, invalid text encodings, and unexpected status/category values. Produce a dry-run report and route ambiguous rows to review instead of guessing.
3. **Normalize without losing provenance.** Preserve each raw value alongside normalized values. Parse dates using an agreed source format and timezone; normalize statuses through an explicit reviewed lookup while retaining the raw status. Map source category/subcategory pairs to the existing five SahaySetu categories only through an approved mapping table. Leave unmatched categories unmapped for review.
4. **Stage historical records separately.** Import into a dedicated historical-data staging table or isolated historical schema, keyed by `(source_dataset, source_year, source_complaint_id)`, with the batch ID, original row number, raw-row checksum, raw columns, and normalized fields. Do not insert historical rows into the live `complaints` table or make them appear as citizen submissions.
5. **Make re-import safe.** Treat the source/year/complaint-ID key as the primary duplicate check. If the key and content checksum match, skip the row; if the same key has changed content, report a conflict for review instead of silently replacing it. Make batches transactional, retain a reject report, and test rollback and repeat-import behavior on an isolated database before any approved deployment.
6. **Apply privacy and access controls.** Restrict the staged dataset and row-level staff remarks/names to explicitly authorized roles. Minimize retained personal information, avoid including raw names/remarks in ordinary logs or public dashboards, and define retention and deletion policy before import. Historical rows must remain distinguishable from live citizen-created complaints in every query and screen.
7. **Make analysis traceable and appropriately limited.** Aggregate by available ward, date, normalized category/subcategory and status; any text-derived themes must link back to source batch and row identifiers and be presented as reviewable summaries. The supplied fields do not contain precise coordinates or a dedicated citizen-description field. They cannot independently establish exact spatial incident fusion, prove two reports describe the same physical incident, or establish causation. Do not claim a trained model or accuracy score without a separately documented training and evaluation process.

No import migration, importer, or dataset write has been performed as part of this proposal.

## Local Flutter-to-FastAPI development connection

The Flutter source does not select a single intended device target. Set the API URL at launch with `SAHAYSETU_API_BASE_URL`. Android builds default to the emulator host bridge at `http://10.0.2.2:8000`; Chrome and Windows builds default to `http://127.0.0.1:8000`.

Before starting FastAPI or applying any migration, verify that `backend\.env` points to the isolated `sahaysetu_mvp_test` database. The current local configuration names `sahaysetu`; do not use it for demo data, migrations, or API workflow tests.

```powershell
$databaseName = & .\.venv\Scripts\python.exe -c "from dotenv import load_dotenv; from sqlalchemy.engine import make_url; import os; load_dotenv(); print(make_url(os.environ['DATABASE_URL']).database)"
if ($databaseName -ne "sahaysetu_mvp_test") { throw "Refusing to start: configure the isolated sahaysetu_mvp_test database first." }
.\.venv\Scripts\python.exe -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

For Android targets, explicitly choose the corresponding URL:

- **Android Studio emulator:** `http://10.0.2.2:8000` (the emulator host-machine bridge).
- **Physical Android device:** `http://<host-computer-LAN-IPv4>:8000`. Find the current address with `ipconfig`; the phone and computer must be able to reach each other on the network. Start FastAPI with `--host 0.0.0.0` and permit inbound TCP port 8000 in the host firewall. Do not use `127.0.0.1` from the phone; it refers to the phone itself.

Launch the mobile app from `mobile\`, replacing the URL with the one for the selected target:

```powershell
flutter run -d chrome --dart-define=SAHAYSETU_API_BASE_URL=http://127.0.0.1:8000
flutter run -d windows --dart-define=SAHAYSETU_API_BASE_URL=http://127.0.0.1:8000
flutter run -d <android-emulator-id> --dart-define=SAHAYSETU_API_BASE_URL=http://10.0.2.2:8000
flutter run -d <physical-android-device-id> --dart-define=SAHAYSETU_API_BASE_URL=http://<host-computer-LAN-IPv4>:8000
```

For a physical device, use this instead of the loopback Uvicorn command above:

```powershell
$databaseName = & .\.venv\Scripts\python.exe -c "from dotenv import load_dotenv; from sqlalchemy.engine import make_url; import os; load_dotenv(); print(make_url(os.environ['DATABASE_URL']).database)"
if ($databaseName -ne "sahaysetu_mvp_test") { throw "Refusing to start: configure the isolated sahaysetu_mvp_test database first." }
.\.venv\Scripts\python.exe -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Use the host computer's current LAN IPv4 URL and keep both devices on a mutually reachable network. Android cleartext HTTP is enabled only by `mobile/android/app/src/debug/AndroidManifest.xml` for local debug builds; use HTTPS for deployed builds. These instructions do not change production behavior.

## Local authority and administration portals

From the repository root, serve the existing HTML files without opening them as `file://` URLs:

```powershell
python -m http.server 5500 --bind 127.0.0.1
```

- Authority login: `http://127.0.0.1:5500/AUTHO-login/authority-login.html`
- Administration login: `http://127.0.0.1:5500/Administration-Login/administration-login.html`

Both portals use the API on `http://127.0.0.1:8000` and require an existing account with the matching `AUTHORITY` or `ADMIN` role.

## Citizen complaint progress and verification

Complaint details show the stored coordinates, an optional reverse-geocoded address, the assigned worker when present, and only status-change events recorded by the server. Existing complaints are not given invented assignment or work timestamps. A Worker marking a complaint `COMPLETED` enables Citizen verification; it does not itself mean the Citizen has confirmed the repair. A Citizen can confirm it or report that work remains unresolved. Unresolved reports are stored with `CITIZEN_DISPUTED` status and remain visible to Authority users for follow-up.

Apply the Alembic migration in `backend\alembic\versions\2bc7e4d9a610_add_citizen_verification_and_status_history.py` to the intended development database before using the new detail and verification routes. The migration adds status-history and one-response-per-worker-completion verification records; it does not rewrite existing complaint records or invent their past status transitions. A later Worker completion after Authority follow-up can be verified separately, while duplicate responses to the same completion are rejected.

Optional verification photos are restricted to JPEG, PNG, or WebP up to 5 MB. They are stored under `backend\evidence_storage\` with generated filenames and are served only through an authenticated, ownership/assignment-checked API route. This is local filesystem storage, not managed or backed-up object storage; deployments must provide durable private storage and backup/retention procedures before relying on it. Do not commit the evidence directory.

The detail view also supports a device-provided reverse-geocoded label, with coordinates retained as the authoritative location and a graceful fallback when lookup is unavailable. The optional map preview loads OpenStreetMap tiles only after the user requests it and displays attribution. The tile service receives tile coordinates; opening the full map sends the precise complaint location to OpenStreetMap.
