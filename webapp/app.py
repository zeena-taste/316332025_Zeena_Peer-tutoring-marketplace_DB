"""
UNILAK Peer Tutoring Marketplace — Flask web frontend (innovation component)

Rewritten to match the REAL schema (confirmed via DESC in SQL*Plus):
  BOOKINGS(booking_id, student_id, tutor_id, slot_id, subject_id, status, booked_at)
  SESSIONS(session_id, booking_id, status, notes, completed_at)
  RATINGS(rating_id, session_id, score, comments, rated_at)
  AVAILABILITY_SLOTS(slot_id, tutor_id, slot_date, start_time, end_time, is_booked)
  SUBJECTS(subject_id, subject_code, subject_name)
  TUTOR_PROFILES(tutor_id, student_id, bio, hourly_rate, verified_flag)

Run plsql_objects.sql in SQL*Plus FIRST — this app calls book_session,
complete_session, and get_tutor_avg_rating, which won't exist otherwise.

Run:
    pip install flask oracledb
    python app.py
Then open http://localhost:5000
"""

from flask import Flask, render_template, request, jsonify, redirect, url_for
import oracledb

app = Flask(__name__)

# ---------------------------------------------------------------------------
# DB CONNECTION — replace with your real project user + password
# ---------------------------------------------------------------------------
DB_USER = "C##316332025_zeena_tutormarketplace_db"
DB_PASSWORD = "1234"
DSN = "localhost:1521/XE"


def get_conn():
    return oracledb.connect(user=DB_USER, password=DB_PASSWORD, dsn=DSN)


def rows_to_dicts(cursor, rows):
    """Turn (col, col, col) tuples into [{col_name: value}] using cursor.description."""
    cols = [d[0].lower() for d in cursor.description]
    return [dict(zip(cols, r)) for r in rows]


def db_error_message(e):
    error_obj, = e.args
    return getattr(error_obj, "message", str(error_obj))


# ---------------------------------------------------------------------------
# LOGIN / ROLE SELECT
# ---------------------------------------------------------------------------

@app.route("/")
def login():
    conn = get_conn()
    cur = conn.cursor()

    cur.execute("SELECT student_id, full_name FROM students ORDER BY full_name")
    students = rows_to_dicts(cur, cur.fetchall())

    cur.execute("""
        SELECT t.tutor_id, s.full_name
        FROM tutor_profiles t
        JOIN students s ON t.student_id = s.student_id
        ORDER BY s.full_name
    """)
    tutors = rows_to_dicts(cur, cur.fetchall())

    conn.close()
    return render_template("login.html", students=students, tutors=tutors)


@app.route("/login/student", methods=["POST"])
def login_student():
    student_id = request.form.get("student_id")
    return redirect(url_for("student_dashboard", student_id=student_id))


@app.route("/login/tutor", methods=["POST"])
def login_tutor():
    tutor_id = request.form.get("tutor_id")
    return redirect(url_for("tutor_dashboard", tutor_id=tutor_id))


# ---------------------------------------------------------------------------
# STUDENT (TUTEE) VIEW
# ---------------------------------------------------------------------------

@app.route("/student/dashboard")
def student_dashboard():
    student_id = request.args.get("student_id", type=int)
    conn = get_conn()
    cur = conn.cursor()

    cur.execute("SELECT full_name FROM students WHERE student_id = :1", [student_id])
    row = cur.fetchone()
    student_name = row[0] if row else "Unknown student"

    cur.execute("SELECT subject_id, subject_name, subject_code FROM subjects ORDER BY subject_name")
    subjects = rows_to_dicts(cur, cur.fetchall())

    conn.close()
    return render_template(
        "student_dashboard.html",
        student_id=student_id,
        student_name=student_name,
        subjects=subjects,
    )


@app.route("/api/tutors")
def api_tutors():
    """List tutors (+ avg rating) who teach a given subject, with their open slots."""
    subject_id = request.args.get("subject_id", type=int)
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT t.tutor_id, s.full_name, t.bio, t.hourly_rate, t.verified_flag,
               get_tutor_avg_rating(t.tutor_id) AS avg_rating
        FROM tutor_profiles t
        JOIN students s ON t.student_id = s.student_id
        JOIN tutor_subjects ts ON ts.tutor_id = t.tutor_id
        WHERE ts.subject_id = :1
        ORDER BY avg_rating DESC
    """, [subject_id])
    tutors = rows_to_dicts(cur, cur.fetchall())

    for t in tutors:
        cur.execute("""
            SELECT slot_id, slot_date, start_time, end_time
            FROM availability_slots
            WHERE tutor_id = :1 AND is_booked = 'N' AND slot_date >= TRUNC(SYSDATE)
            ORDER BY slot_date, start_time
        """, [t["tutor_id"]])
        t["slots"] = rows_to_dicts(cur, cur.fetchall())

    conn.close()
    return jsonify(tutors)


@app.route("/api/bookings", methods=["POST"])
def api_book():
    """Calls the book_session procedure — all validation happens in PL/SQL."""
    data = request.json
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.callproc("book_session", [
            data["student_id"], data["tutor_id"], data["slot_id"], data["subject_id"]
        ])
        conn.commit()
        return jsonify({"status": "ok"})
    except oracledb.DatabaseError as e:
        return jsonify({"status": "error", "message": db_error_message(e)}), 400
    finally:
        conn.close()


@app.route("/api/student/<int:student_id>/bookings")
def api_student_bookings(student_id):
    """Everything a student needs to see: upcoming bookings + completed sessions
    awaiting a rating."""
    conn = get_conn()
    cur = conn.cursor()

    cur.execute("""
        SELECT b.booking_id, b.status, a.slot_date, a.start_time, a.end_time,
               s.full_name AS tutor_name
        FROM bookings b
        JOIN availability_slots a ON b.slot_id = a.slot_id
        JOIN tutor_profiles tp ON b.tutor_id = tp.tutor_id
        JOIN students s ON tp.student_id = s.student_id
        WHERE b.student_id = :1 AND b.status = 'CONFIRMED'
        ORDER BY a.slot_date, a.start_time
    """, [student_id])
    upcoming = rows_to_dicts(cur, cur.fetchall())

    cur.execute("""
        SELECT se.session_id, b.booking_id, s.full_name AS tutor_name, a.slot_date, a.start_time
        FROM sessions se
        JOIN bookings b ON se.booking_id = b.booking_id
        JOIN availability_slots a ON b.slot_id = a.slot_id
        JOIN tutor_profiles tp ON b.tutor_id = tp.tutor_id
        JOIN students s ON tp.student_id = s.student_id
        WHERE b.student_id = :1
          AND se.status = 'COMPLETED'
          AND NOT EXISTS (SELECT 1 FROM ratings r WHERE r.session_id = se.session_id)
        ORDER BY a.slot_date DESC
    """, [student_id])
    awaiting_rating = rows_to_dicts(cur, cur.fetchall())

    conn.close()
    return jsonify({"upcoming": upcoming, "awaiting_rating": awaiting_rating})


@app.route("/api/ratings", methods=["POST"])
def api_rate():
    """Insert a rating; trg_validate_rating enforces the 1-5 range in Oracle."""
    data = request.json
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO ratings (session_id, score, comments, rated_at)
            VALUES (:1, :2, :3, SYSDATE)
        """, [data["session_id"], data["score"], data.get("comment")])
        conn.commit()
        return jsonify({"status": "ok"})
    except oracledb.DatabaseError as e:
        return jsonify({"status": "error", "message": db_error_message(e)}), 400
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# TUTOR VIEW
# ---------------------------------------------------------------------------

@app.route("/tutor/dashboard")
def tutor_dashboard():
    tutor_id = request.args.get("tutor_id", type=int)
    conn = get_conn()
    cur = conn.cursor()

    cur.execute("""
        SELECT s.full_name
        FROM tutor_profiles t JOIN students s ON t.student_id = s.student_id
        WHERE t.tutor_id = :1
    """, [tutor_id])
    row = cur.fetchone()
    tutor_name = row[0] if row else "Unknown tutor"

    conn.close()
    return render_template("tutor_dashboard.html", tutor_id=tutor_id, tutor_name=tutor_name)


@app.route("/api/tutor/<int:tutor_id>/sessions")
def api_tutor_sessions(tutor_id):
    """Upcoming confirmed sessions — same data tutoring_pkg.list_upcoming_sessions
    prints via DBMS_OUTPUT in SQL*Plus, surfaced here as JSON for the UI.

    NOTE: complete_session() only ever updates SESSIONS.status (BOOKINGS.status
    stays 'CONFIRMED' by design — that column tracks the booking itself, not
    whether the session happened). So this list has to check SESSIONS.status
    too, or a completed session keeps showing up here forever even though
    marking it complete worked correctly on the database side.
    """
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT b.booking_id, a.slot_date, a.start_time, a.end_time, s.full_name AS student_name
        FROM bookings b
        JOIN sessions se ON se.booking_id = b.booking_id
        JOIN availability_slots a ON b.slot_id = a.slot_id
        JOIN students s ON b.student_id = s.student_id
        WHERE b.tutor_id = :1 AND b.status = 'CONFIRMED' AND se.status = 'SCHEDULED'
        ORDER BY a.slot_date, a.start_time
    """, [tutor_id])
    sessions = rows_to_dicts(cur, cur.fetchall())
    conn.close()
    return jsonify(sessions)


@app.route("/api/tutor/<int:tutor_id>/rating")
def api_tutor_rating(tutor_id):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT get_tutor_avg_rating(:1) FROM dual", [tutor_id])
    avg_rating = cur.fetchone()[0]

    cur.execute("""
        SELECT r.score, r.comments, a.slot_date, a.start_time
        FROM ratings r
        JOIN sessions se ON r.session_id = se.session_id
        JOIN bookings b ON se.booking_id = b.booking_id
        JOIN availability_slots a ON b.slot_id = a.slot_id
        WHERE b.tutor_id = :1
        ORDER BY a.slot_date DESC
        FETCH FIRST 5 ROWS ONLY
    """, [tutor_id])
    recent = rows_to_dicts(cur, cur.fetchall())

    conn.close()
    return jsonify({"avg_rating": avg_rating, "recent": recent})


@app.route("/api/subjects")
def api_subjects():
    """All subjects in the catalog — used to populate the 'pick an existing
    course' dropdown on the tutor dashboard."""
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT subject_id, subject_code, subject_name FROM subjects ORDER BY subject_name")
    subjects = rows_to_dicts(cur, cur.fetchall())
    conn.close()
    return jsonify(subjects)


@app.route("/api/tutor/<int:tutor_id>/subjects", methods=["GET"])
def api_tutor_subjects(tutor_id):
    """Subjects this specific tutor currently teaches."""
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT sub.subject_id, sub.subject_code, sub.subject_name
        FROM tutor_subjects ts
        JOIN subjects sub ON sub.subject_id = ts.subject_id
        WHERE ts.tutor_id = :1
        ORDER BY sub.subject_name
    """, [tutor_id])
    subjects = rows_to_dicts(cur, cur.fetchall())
    conn.close()
    return jsonify(subjects)


@app.route("/api/tutor/<int:tutor_id>/subjects", methods=["POST"])
def api_add_tutor_subject(tutor_id):
    """Add a course to a tutor's teaching list.

    Two request shapes:
      { "subject_id": 5 }                                -> link to an EXISTING subject
      { "subject_code": "CS201", "subject_name": "..." }  -> CREATE the subject, then link it

    No new tables are needed for this — SUBJECTS and TUTOR_SUBJECTS already
    exist in the schema; this just performs the two inserts your old SQL*Plus
    workflow would have done by hand. See the note in plsql_objects.sql about
    the optional unique constraints that make this endpoint safe to call twice.
    """
    data = request.json
    conn = get_conn()
    cur = conn.cursor()
    try:
        if "subject_id" in data and data["subject_id"]:
            subject_id = data["subject_id"]
        else:
            code = (data.get("subject_code") or "").strip()
            name = (data.get("subject_name") or "").strip()
            if not code or not name:
                return jsonify({"status": "error", "message": "Course code and name are required."}), 400

            # Reuse the subject if that code already exists, otherwise create it.
            cur.execute("SELECT subject_id FROM subjects WHERE subject_code = :1", [code])
            row = cur.fetchone()
            if row:
                subject_id = row[0]
            else:
                cur.execute("""
                    INSERT INTO subjects (subject_code, subject_name) VALUES (:1, :2)
                """, [code, name])
                cur.execute("SELECT subject_id FROM subjects WHERE subject_code = :1", [code])
                subject_id = cur.fetchone()[0]

        # Avoid duplicate links if the tutor already teaches this subject.
        cur.execute("""
            SELECT 1 FROM tutor_subjects WHERE tutor_id = :1 AND subject_id = :2
        """, [tutor_id, subject_id])
        if not cur.fetchone():
            cur.execute("""
                INSERT INTO tutor_subjects (tutor_id, subject_id) VALUES (:1, :2)
            """, [tutor_id, subject_id])

        conn.commit()
        return jsonify({"status": "ok", "subject_id": subject_id})
    except oracledb.DatabaseError as e:
        conn.rollback()
        return jsonify({"status": "error", "message": db_error_message(e)}), 400
    finally:
        conn.close()


@app.route("/api/availability", methods=["POST"])
def api_add_availability():
    """Expects JSON: { tutor_id, slot_date: 'YYYY-MM-DD', start_time: 'HH:MM', end_time: 'HH:MM' }"""
    data = request.json
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO availability_slots (tutor_id, slot_date, start_time, end_time, is_booked)
            VALUES (:1, TO_DATE(:2, 'YYYY-MM-DD'), :3, :4, 'N')
        """, [data["tutor_id"], data["slot_date"], data["start_time"], data["end_time"]])
        conn.commit()
        return jsonify({"status": "ok"})
    except oracledb.DatabaseError as e:
        return jsonify({"status": "error", "message": db_error_message(e)}), 400
    finally:
        conn.close()


@app.route("/api/sessions/complete", methods=["POST"])
def api_complete_session():
    """Calls the complete_session(p_booking_id, p_notes) procedure."""
    data = request.json
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.callproc("complete_session", [data["booking_id"], data.get("notes", "")])
        conn.commit()
        return jsonify({"status": "ok"})
    except oracledb.DatabaseError as e:
        return jsonify({"status": "error", "message": db_error_message(e)}), 400
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# DASHBOARD CHARTS (shared innovation component — 3 live charts)
# ---------------------------------------------------------------------------

@app.route("/api/dashboard/bookings-by-subject")
def dashboard_bookings_by_subject():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT sub.subject_name, COUNT(*) AS booking_count
        FROM bookings b
        JOIN subjects sub ON b.subject_id = sub.subject_id
        GROUP BY sub.subject_name
        ORDER BY booking_count DESC
    """)
    data = rows_to_dicts(cur, cur.fetchall())
    conn.close()
    return jsonify(data)


@app.route("/api/dashboard/tutor-ratings")
def dashboard_tutor_ratings():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT s.full_name AS tutor_name, get_tutor_avg_rating(t.tutor_id) AS avg_rating
        FROM tutor_profiles t
        JOIN students s ON t.student_id = s.student_id
        ORDER BY avg_rating DESC
    """)
    data = rows_to_dicts(cur, cur.fetchall())
    conn.close()
    return jsonify(data)


@app.route("/api/dashboard/session-outcomes")
def dashboard_session_outcomes():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT status AS outcome, COUNT(*) AS outcome_count
        FROM sessions
        GROUP BY status
    """)
    data = rows_to_dicts(cur, cur.fetchall())
    conn.close()
    return jsonify(data)


# ---------------------------------------------------------------------------
# AUDIT LOG VIEWER — lets you check trg_audit_bookings visually instead of
# querying AUDIT_LOG in SQL*Plus every time. Read-only, no writes happen here.
# ---------------------------------------------------------------------------

@app.route("/audit-log")
def audit_log_page():
    return render_template("audit_log.html")


@app.route("/api/audit-log")
def api_audit_log():
    """Returns AUDIT_LOG rows, most recent first, with optional filters.
    Query params: table_name, action, limit (default 100)."""
    table_name = request.args.get("table_name")
    action = request.args.get("action")
    limit = request.args.get("limit", "100")

    conn = get_conn()
    cur = conn.cursor()

    where_clauses = []
    params = {}
    if table_name:
        where_clauses.append("table_name = :table_name")
        params["table_name"] = table_name
    if action:
        where_clauses.append("action = :action")
        params["action"] = action

    where_sql = ("WHERE " + " AND ".join(where_clauses)) if where_clauses else ""

    cur.execute(f"""
        SELECT log_id, table_name, action, record_id, old_value, new_value,
               changed_by, changed_at
        FROM audit_log
        {where_sql}
        ORDER BY changed_at DESC, log_id DESC
        FETCH FIRST :row_limit ROWS ONLY
    """, {**params, "row_limit": int(limit)})

    data = rows_to_dicts(cur, cur.fetchall())
    conn.close()
    return jsonify(data)


if __name__ == "__main__":
    app.run(debug=True)
