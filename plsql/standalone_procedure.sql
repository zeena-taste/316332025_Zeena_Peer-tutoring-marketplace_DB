-- ==========================================
-- 1. BOOK SESSION
-- ==========================================
CREATE OR REPLACE PROCEDURE book_session (
    p_student_id IN NUMBER,
    p_slot_id    IN NUMBER,
    p_subject_id IN NUMBER  -- Added because subject_id is NOT NULL in bookings
) IS
    v_is_booked CHAR(1);
    v_tutor_id  NUMBER;
BEGIN
    -- Fetch slot details to check availability and get the tutor_id
    SELECT is_booked, tutor_id 
    INTO v_is_booked, v_tutor_id 
    FROM availability_slots 
    WHERE slot_id = p_slot_id;

    IF v_is_booked = 'Y' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Slot already booked');
    END IF;

    -- Insert booking (includes tutor_id and subject_id)
    INSERT INTO bookings (student_id, tutor_id, slot_id, subject_id, status, booked_at)
    VALUES (p_student_id, v_tutor_id, p_slot_id, p_subject_id, 'CONFIRMED', SYSDATE);

    -- Mark slot as booked
    UPDATE availability_slots SET is_booked = 'Y' WHERE slot_id = p_slot_id;
    
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'Slot not found');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

-- ==========================================
-- 2. CANCEL BOOKING
-- ==========================================
CREATE OR REPLACE PROCEDURE cancel_booking (
    p_booking_id IN NUMBER
) IS
    v_status  VARCHAR2(20);
    v_slot_id NUMBER;
BEGIN
    SELECT status, slot_id 
    INTO v_status, v_slot_id 
    FROM bookings 
    WHERE booking_id = p_booking_id;

    IF v_status = 'CANCELLED' THEN
        RAISE_APPLICATION_ERROR(-20003, 'Booking is already cancelled');
    ELSIF v_status = 'COMPLETED' THEN
        RAISE_APPLICATION_ERROR(-20004, 'Cannot cancel a completed booking');
    END IF;

    -- Update booking status
    UPDATE bookings SET status = 'CANCELLED' WHERE booking_id = p_booking_id;
    
    -- Free up the availability slot
    UPDATE availability_slots SET is_booked = 'N' WHERE slot_id = v_slot_id;
    
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20005, 'Booking not found');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

-- ==========================================
-- 3. COMPLETE SESSION
-- ==========================================
CREATE OR REPLACE PROCEDURE complete_session (
    p_session_id IN NUMBER,
    p_notes      IN VARCHAR2 DEFAULT NULL
) IS
    v_status     VARCHAR2(20);
    v_booking_id NUMBER;
BEGIN
    SELECT status, booking_id 
    INTO v_status, v_booking_id 
    FROM sessions 
    WHERE session_id = p_session_id;

    IF v_status = 'COMPLETED' THEN
        RAISE_APPLICATION_ERROR(-20006, 'Session is already completed');
    END IF;

    -- Update session details
    UPDATE sessions 
    SET status = 'COMPLETED', 
        notes = NVL(p_notes, notes), -- Keeps old notes if p_notes is null
        completed_at = SYSDATE 
    WHERE session_id = p_session_id;
    
    -- Update the underlying booking status to COMPLETED
    UPDATE bookings 
    SET status = 'COMPLETED' 
    WHERE booking_id = v_booking_id;
    
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20007, 'Session not found');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/