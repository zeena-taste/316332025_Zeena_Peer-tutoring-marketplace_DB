# UNILAK Tutor Board — Web Frontend (Innovation Component)

Thin Flask layer over the Oracle schema. All real logic (double-booking
checks, rating validation 1–5, the weekday/holiday block) stays in
PL/SQL — this app just calls procedures/functions and renders the result.

## Setup

```
pip install -r requirements.txt
```

Edit the three constants at the top of `app.py` to match your DB:

```python
DB_USER = "studentid_zoe_tutormarketplace_db"
DB_PASSWORD = "YourPassword123"
DSN = "localhost:1521/XE"
```

## Run

```
python app.py
```

Open http://localhost:5000 — you'll land on the role-select screen
("I need help" vs "I'm offering help").

## What each view does

**Student view** (`/student/dashboard`)
- Pick a subject → see tutors teaching it, their avg rating (via
  `get_tutor_avg_rating`), and open slots
- Click "Book" on a slot → calls `book_session` — if the compound
  trigger blocks it (weekday/holiday) or the slot's already taken,
  the error message from Oracle is shown directly in the UI
- See upcoming confirmed bookings
- Rate any completed session that doesn't have a rating yet — the
  `trg_validate_rating` trigger enforces 1–5 server-side regardless
  of what the UI sends

**Tutor view** (`/tutor/dashboard`)
- See own average rating + last 5 comments
- Add a new availability slot
- See upcoming confirmed sessions (same data
  `tutoring_pkg.list_upcoming_sessions` prints in SQL*Plus, surfaced
  as JSON here) and mark one completed (calls `complete_session`)
- "Marketplace insights" section renders the 3 required dashboard
  charts (Chart.js): bookings by subject, tutor ratings sorted,
  session outcomes — pulled live from `/api/dashboard/*`

## Demo checklist (matches the live-demo script in your build guide)

1. Log in as a student, book a slot → switch to that tutor's login,
   confirm the session now shows in their upcoming list
2. As tutor, add a slot → switch back to student, confirm it's
   bookable
3. Cross-check in SQL*Plus: `SELECT * FROM bookings`, `SELECT * FROM
   audit_log` — confirm the trigger fired
4. Try booking on a blocked weekday/holiday through the UI → the
   compound trigger's error surfaces as a red banner, not a crash
5. Call `get_tutor_avg_rating` directly in SQL*Plus to show it works
   independent of the web app

## Notes

- No real authentication — the login screen is a name picker, exactly
  as scoped in the build guide. Don't over-invest here; it's not what's
  graded.
- `/api/availability` expects `start_time`/`end_time` as
  `YYYY-MM-DD HH24:MI` strings (the datetime-local input sends this
  format after the `T` → space swap already handled in the JS).
- If `complete_session` or `book_session` raise a custom
  `RAISE_APPLICATION_ERROR`, the Oracle error message is passed straight
  through to the browser — good material for the "what happens when
  this fails" question in Q&A.
