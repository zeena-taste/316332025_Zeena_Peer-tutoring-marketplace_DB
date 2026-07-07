-- ===========================================================================
-- UNILAK Peer Tutoring Marketplace — PL/SQL objects (Step 6, 7, 8)
-- Written against the REAL schema (confirmed via DESC in SQL*Plus 07-Jul-2026):
--   BOOKINGS(booking_id, student_id, tutor_id, slot_id, subject_id, status, booked_at)
--   SESSIONS(session_id, booking_id, status, notes, completed_at)
--   RATINGS(rating_id, session_id, score, comments, rated_at)
--   AVAILABILITY_SLOTS(slot_id, tutor_id, slot_date, start_time, end_time, is_booked)
--   SUBJECTS(subject_id, subject_code, subject_name)
--   TUTOR_PROFILES(tutor_id, student_id, bio, hourly_rate, verified_flag)
--
-- Run this whole file in SQL*Plus while connected as your project user:
--   SQL> @plsql_objects.sql
-- ===========================================================================

SET SERVEROUTPUT ON;

-- ---------------------------------------------------------------------------
-- PROCEDURE: book_session
-- Design note: creates the SESSIONS row immediately (status = 'SCHEDULED')
-- so there is always exactly one session per confirmed booking. This keeps
-- the 1:1 BOOKINGS <-> SESSIONS relationship clean and gives complete_session
-- a guaranteed row to update later.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE book_session (
    p_student_id IN NUMBER,
    p_tutor_id   IN NUMBER,
    p_slot_id    IN NUMBER,
    p_subject_id IN NUMBER
) IS
    v_is_booked      availability_slots.is_booked%TYPE;
    v_new_booking_id bookings.booking_id%TYPE;
BEGIN
    SELECT is_booked INTO v_is_booked
    FROM availability_slots
    WHERE slot_id = p_slot_id
    FOR UPDATE;  -- lock the row so two students can't book it in the same instant

    IF v_is_booked = 'Y' THEN
        RAISE_APPLICATION_ERROR(-20001, 'That slot is already booked.');
    END IF;

    INSERT INTO bookings (student_id, tutor_id, slot_id, subject_id, status, booked_at)
    VALUES (p_student_id, p_tutor_id, p_slot_id, p_subject_id, 'CONFIRMED', SYSDATE)
    RETURNING booking_id INTO v_new_booking_id;

    INSERT INTO sessions (booking_id, status)
    VALUES (v_new_booking_id, 'SCHEDULED');

    UPDATE availability_slots SET is_booked = 'Y' WHERE slot_id = p_slot_id;

    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'That availability slot does not exist.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END book_session;
/

-- ---------------------------------------------------------------------------
-- PROCEDURE: cancel_booking
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE cancel_booking (
    p_booking_id IN NUMBER,
    p_reason     IN VARCHAR2
) IS
    v_slot_id availability_slots.slot_id%TYPE;
BEGIN
    SELECT slot_id INTO v_slot_id FROM bookings WHERE booking_id = p_booking_id;

    UPDATE bookings SET status = 'CANCELLED' WHERE booking_id = p_booking_id;
    UPDATE sessions SET status = 'CANCELLED', notes = p_reason WHERE booking_id = p_booking_id;
    UPDATE availability_slots SET is_booked = 'N' WHERE slot_id = v_slot_id;

    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20003, 'Booking not found: ' || p_booking_id);
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END cancel_booking;
/

-- ---------------------------------------------------------------------------
-- PROCEDURE: complete_session
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE complete_session (
    p_booking_id IN NUMBER,
    p_notes      IN VARCHAR2
) IS
BEGIN
    UPDATE sessions
    SET status = 'COMPLETED', notes = p_notes, completed_at = SYSDATE
    WHERE booking_id = p_booking_id;

    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'No session found for booking: ' || p_booking_id);
    END IF;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END complete_session;
/

-- ---------------------------------------------------------------------------
-- FUNCTION: get_tutor_avg_rating
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_tutor_avg_rating (p_tutor_id IN NUMBER)
RETURN NUMBER IS
    v_avg NUMBER;
BEGIN
    SELECT AVG(r.score) INTO v_avg
    FROM ratings r
    JOIN sessions s  ON r.session_id = s.session_id
    JOIN bookings b  ON s.booking_id = b.booking_id
    WHERE b.tutor_id = p_tutor_id;

    RETURN NVL(v_avg, 0);
END get_tutor_avg_rating;
/

-- ---------------------------------------------------------------------------
-- FUNCTION: is_slot_available
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION is_slot_available (p_slot_id IN NUMBER)
RETURN VARCHAR2 IS
    v_flag availability_slots.is_booked%TYPE;
BEGIN
    SELECT is_booked INTO v_flag FROM availability_slots WHERE slot_id = p_slot_id;
    RETURN CASE WHEN v_flag = 'N' THEN 'Y' ELSE 'N' END;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'N';
END is_slot_available;
/

-- ---------------------------------------------------------------------------
-- FUNCTION: count_sessions_by_status
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION count_sessions_by_status (
    p_tutor_id IN NUMBER,
    p_status   IN VARCHAR2
) RETURN NUMBER IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM sessions s
    JOIN bookings b ON s.booking_id = b.booking_id
    WHERE b.tutor_id = p_tutor_id AND s.status = p_status;

    RETURN v_count;
END count_sessions_by_status;
/

-- ---------------------------------------------------------------------------
-- PACKAGE: tutoring_pkg (bundles booking + the required explicit cursor)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE tutoring_pkg AS
    PROCEDURE book_session(p_student_id NUMBER, p_tutor_id NUMBER, p_slot_id NUMBER, p_subject_id NUMBER);
    PROCEDURE list_upcoming_sessions(p_tutor_id NUMBER);
END tutoring_pkg;
/

CREATE OR REPLACE PACKAGE BODY tutoring_pkg AS

    -- NOTE: this mirrors the standalone book_session procedure's logic exactly.
    -- It's duplicated (not delegated) because a package member calling an
    -- unqualified procedure of the same name would recurse into itself rather
    -- than reach the standalone one. The web app calls the standalone
    -- book_session directly for this reason; this package version exists to
    -- satisfy the "package bundles the booking logic" requirement and to sit
    -- next to the cursor below for the live demo.
    PROCEDURE book_session(p_student_id NUMBER, p_tutor_id NUMBER, p_slot_id NUMBER, p_subject_id NUMBER) IS
        v_is_booked      availability_slots.is_booked%TYPE;
        v_new_booking_id bookings.booking_id%TYPE;
    BEGIN
        SELECT is_booked INTO v_is_booked
        FROM availability_slots
        WHERE slot_id = p_slot_id
        FOR UPDATE;

        IF v_is_booked = 'Y' THEN
            RAISE_APPLICATION_ERROR(-20001, 'That slot is already booked.');
        END IF;

        INSERT INTO bookings (student_id, tutor_id, slot_id, subject_id, status, booked_at)
        VALUES (p_student_id, p_tutor_id, p_slot_id, p_subject_id, 'CONFIRMED', SYSDATE)
        RETURNING booking_id INTO v_new_booking_id;

        INSERT INTO sessions (booking_id, status)
        VALUES (v_new_booking_id, 'SCHEDULED');

        UPDATE availability_slots SET is_booked = 'Y' WHERE slot_id = p_slot_id;

        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'That availability slot does not exist.');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END book_session;

    PROCEDURE list_upcoming_sessions(p_tutor_id NUMBER) IS
        CURSOR c_sessions IS
            SELECT b.booking_id, a.slot_date, a.start_time, a.end_time
            FROM bookings b
            JOIN availability_slots a ON b.slot_id = a.slot_id
            WHERE b.tutor_id = p_tutor_id AND b.status = 'CONFIRMED'
            ORDER BY a.slot_date, a.start_time;
        v_booking_id bookings.booking_id%TYPE;
        v_slot_date  availability_slots.slot_date%TYPE;
        v_start      availability_slots.start_time%TYPE;
        v_end        availability_slots.end_time%TYPE;
    BEGIN
        OPEN c_sessions;
        LOOP
            FETCH c_sessions INTO v_booking_id, v_slot_date, v_start, v_end;
            EXIT WHEN c_sessions%NOTFOUND;
            DBMS_OUTPUT.PUT_LINE('Booking ' || v_booking_id || ' on ' ||
                TO_CHAR(v_slot_date, 'DD-MON-YYYY') || ' ' || v_start || '-' || v_end);
        END LOOP;
        CLOSE c_sessions;
    END list_upcoming_sessions;

END tutoring_pkg;
/

-- ---------------------------------------------------------------------------
-- SIMPLE TRIGGER: reject ratings outside 1-5 (idempotent - safe to re-run)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_validate_rating
BEFORE INSERT ON ratings
FOR EACH ROW
BEGIN
    IF :NEW.score NOT BETWEEN 1 AND 5 THEN
        RAISE_APPLICATION_ERROR(-20004, 'Rating must be between 1 and 5.');
    END IF;
END trg_validate_rating;
/

-- ---------------------------------------------------------------------------
-- Quick sanity check — run after this script to confirm everything compiled
-- ---------------------------------------------------------------------------
-- SELECT object_name, object_type, status FROM user_objects
-- WHERE object_name IN ('BOOK_SESSION','CANCEL_BOOKING','COMPLETE_SESSION',
--   'GET_TUTOR_AVG_RATING','IS_SLOT_AVAILABLE','COUNT_SESSIONS_BY_STATUS',
--   'TUTORING_PKG','TRG_VALIDATE_RATING')
-- ORDER BY object_name;
