# UNILAK Peer Tutoring Marketplace

**Course:** DPR400210 — Database Programming with Oracle
**Author:** Zeena (316332025)
**Repo:** `zeena-taste/316332025_Zeena_Peer-tutoring-marketplace_DB`
**Submission:** 15 July 2026

A database-backed marketplace where UNILAK students find, book, and rate peer
tutors by subject — conflict-free bookings, session tracking, and tutor
ratings, all enforced in Oracle PL/SQL, with a Flask web app on top as the
innovation component.

---

## 1. Problem

Peer tutoring at UNILAK currently gets coordinated informally over
WhatsApp/Discord — no way to see a tutor's real availability, avoid double
bookings, track whether a session actually happened, or check a tutor's
track record before booking. This project replaces that with a structured
**marketplace**: students discover tutors by subject, book an open slot,
and rate the tutor afterward — with every rule (no double-booking, no
weekday/holiday bookings, 1–5 ratings only) enforced at the database layer,
not just in the UI.

---

## 2. Architecture

```
Browser  →  Flask (thin presentation layer)  →  Oracle XE
                                                   ├─ tables + constraints
                                                   ├─ procedures/functions
                                                   ├─ tutoring_pkg (+ cursor)
                                                   └─ triggers (validation,
                                                      weekday/holiday block,
                                                      audit log)
```

All business rules — double-booking prevention, rating range validation,
the weekday/holiday block, audit logging — live in PL/SQL. Flask only
calls procedures/functions and renders JSON/HTML; it never re-implements
a rule that Oracle is already enforcing.

---

## 3. Schema (10 tables)

| Table | Purpose | Key relationship |
|---|---|---|
| `STUDENTS` | Every user (tutors and tutees are students) | — |
| `TUTOR_PROFILES` | Extends a student into a tutor (bio, hourly_rate, verified_flag) | 1:1 → `STUDENTS` |
| `SUBJECTS` | Catalog (`subject_code`, `subject_name`) | — |
| `TUTOR_SUBJECTS` | Which tutors teach which subjects | M:N junction |
| `AVAILABILITY_SLOTS` | Tutor's open time windows (`slot_date` + `start_time`/`end_time`) | 1:M ← `TUTOR_PROFILES` |
| `BOOKINGS` | A tutee books a tutor's slot for a subject | refs `STUDENTS`, `TUTOR_PROFILES`, `AVAILABILITY_SLOTS`, `SUBJECTS` |
| `SESSIONS` | Post-booking record: `status` (SCHEDULED/COMPLETED/CANCELLED), notes | 1:1 ← `BOOKINGS` |
| `RATINGS` | 1–5 score + comments on a completed session | 1:1 ← `SESSIONS` |
| `HOLIDAYS` | Public holiday reference dates, used by the compound trigger | — |
| `AUDIT_LOG` | Who changed what, when | standalone |

Full DDL: [`sql/tables.sql`](sql/tables.sql). ERD: [`docs/erd.png`](docs/erd.png).

**Design note:** `book_session` inserts the `SESSIONS` row itself, at
booking time, with `status = 'SCHEDULED'` — so every confirmed booking
always has exactly one session row, and `complete_session` only ever
*updates* it rather than deciding whether to create one.

---

## 4. PL/SQL objects

All final, tested PL/SQL lives in **[`webapp/plsql_objects.sql`](webapp/plsql_objects.sql)**
— this is the one file to run; it's the corrected version written against
the real column names (confirmed via `DESC` in SQL*Plus) and it's what
`app.py` actually calls. The `/plsql` folder contains earlier drafts kept
for the build history — don't run those against the live schema, their
signatures don't match.

| Object | Type | Notes |
|---|---|---|
| `book_session(student_id, tutor_id, slot_id, subject_id)` | Procedure | Locks the slot row (`FOR UPDATE`), rejects if already booked, inserts booking + session, commits |
| `cancel_booking(booking_id, reason)` | Procedure | Frees the slot back up |
| `complete_session(booking_id, notes)` | Procedure | Marks session COMPLETED |
| `get_tutor_avg_rating(tutor_id)` | Function → NUMBER | Used both in SQL*Plus and by the dashboard |
| `is_slot_available(slot_id)` | Function → VARCHAR2 ('Y'/'N') | |
| `count_sessions_by_status(tutor_id, status)` | Function → NUMBER | |
| `tutoring_pkg` | Package | Bundles a demo booking procedure + `list_upcoming_sessions`, which contains the required **explicit cursor** |
| `trg_validate_rating` | Simple trigger | Rejects `score` outside 1–5 |

Compound trigger and audit trigger live in [`plsql/triggers.sql`](plsql/triggers.sql)
and [`plsql/audit_log_triggers.sql`](plsql/audit_log_triggers.sql):

- `trg_block_weekday_holiday` — compound trigger on `BOOKINGS`, blocks
  INSERT/UPDATE on weekdays and on any date present in `HOLIDAYS`
- `trg_audit_bookings` — after INSERT/UPDATE/DELETE on `BOOKINGS`, writes
  old/new values into `AUDIT_LOG`

---

## 5. Web app (innovation component)

Flask + `oracledb`, two role-based views, corkboard-style visual theme,
three live Chart.js dashboards. Full details in
[`webapp/README.md`](webapp/README.md) — summary below.

### Setup

```bash
cd webapp
python -m venv venv
venv\Scripts\activate        # Windows CMD
pip install -r requirements.txt
```

Edit the three constants at the top of `app.py` to match your DB:

```python
DB_USER = "C##316332025_zeena_tutormarketplace_db"
DB_PASSWORD = "1234"
DSN = "localhost:1521/XE"
```

### Run

1. In SQL*Plus, connected as your project user, build the schema **in
   order**:
   ```sql
   @sql/tables.sql
   @sql/demo_data.sql
   @webapp/plsql_objects.sql
   ```
2. Start the app:
   ```bash
   python app.py
   ```
3. Open `http://localhost:5000` — role-select screen ("I need help" /
   "I'm offering help").

### What each view does

**Student view** — pick a subject → see tutors + avg rating + open slots →
book a slot (calls `book_session`) → see own upcoming bookings → rate a
completed session.

**Tutor view** — see own avg rating + recent comments → add an
availability slot → see upcoming confirmed sessions (same data
`tutoring_pkg.list_upcoming_sessions` prints in SQL*Plus, surfaced here as
JSON) → mark a session complete (calls `complete_session`) → the 3
dashboard charts (bookings by subject, tutor ratings sorted, session
outcomes).

**Audit log** - shows all the data from the audit_log table in a web page for easier viewing. → navigate to `http://localhost:5000/audit-log` to view it.

---

## 6. Repo structure

```
sql/              tables.sql, demo_data.sql
plsql/            earlier draft procedures/functions/package/triggers
                   (kept for history — see note in section 4)
webapp/
  app.py          Flask routes
  plsql_objects.sql   <- authoritative PL/SQL, run this one
  templates/      login.html, base.html, student_dashboard.html, tutor_dashboard.html, audit_log.html
  static/         style.css
  requirements.txt
docs/
  erd.png
  screenshots/    trigger tests, package tests, security/role setup
README.md         this file
```

---

## 7. Sample data

Seeded via `sql/demo_data.sql`: 6 students (2 also tutors — Alice, Bob),
4 subjects, 9 availability slots, 5 bookings in mixed states (COMPLETED,
CANCELLED, CONFIRMED, PENDING), 2 completed sessions with ratings, and 6
real 2026 Rwandan public holidays for testing the compound trigger.

---

## 8. Known limitation / before-demo checklist

- Role/privilege separation (`tutee_role` etc.) was demonstrated and
  screenshotted (`docs/screenshots/created_user_to_test_security.PNG`,
  `security_chcekced.PNG`) but the `CREATE ROLE`/`GRANT` statements
  themselves aren't currently saved as a script in the repo. Worth adding
  a `sql/roles.sql` before submission so there's a file to point to, not
  just a screenshot — see the ready-made version in
  `presentation_and_defense_prep.md`.
- Compile-check before the live demo:
  ```sql
  SELECT object_name, object_type, status FROM user_objects
  WHERE status = 'INVALID';
  ```
  should return no rows.
