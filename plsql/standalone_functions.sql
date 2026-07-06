-- ==========================================
-- 1. GET TUTOR AVERAGE RATING
-- ==========================================
CREATE OR REPLACE FUNCTION get_tutor_avg_rating (
    p_tutor_id IN NUMBER
) RETURN NUMBER IS
    v_avg NUMBER;
BEGIN
    SELECT ROUND(AVG(r.score), 2)
    INTO v_avg
    FROM ratings r
    JOIN sessions s ON r.session_id = s.session_id
    JOIN bookings b ON s.booking_id = b.booking_id
    JOIN availability_slots a ON b.slot_id = a.slot_id
    WHERE a.tutor_id = p_tutor_id;

    RETURN NVL(v_avg, 0);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
END get_tutor_avg_rating;
/

-- ==========================================
-- 2. IS SLOT AVAILABLE
-- ==========================================
CREATE OR REPLACE FUNCTION is_slot_available (
    p_slot_id IN NUMBER
) RETURN VARCHAR2 IS
    v_is_booked CHAR(1);
BEGIN
    SELECT is_booked
    INTO v_is_booked
    FROM availability_slots
    WHERE slot_id = p_slot_id;

    IF v_is_booked = 'N' THEN
        RETURN 'Y';   -- Yes, it is available
    ELSE
        RETURN 'N';   -- No, it is already booked
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'INVALID';  -- Slot does not exist
END is_slot_available;
/

-- ==========================================
-- 3. COUNT SESSIONS BY STATUS
-- ==========================================
CREATE OR REPLACE FUNCTION count_sessions_by_status (
    p_status IN VARCHAR2
) RETURN NUMBER IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM sessions
    WHERE status = UPPER(p_status);

    RETURN v_count;
END count_sessions_by_status;
/