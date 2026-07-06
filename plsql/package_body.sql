CREATE OR REPLACE PACKAGE BODY tutor_pkg IS

    -- ==========================================
    -- 1. BOOK SESSION
    -- ==========================================
    PROCEDURE book_session (
        p_student_id IN NUMBER,
        p_slot_id    IN NUMBER,
        p_subject_id IN NUMBER
    ) IS
        v_is_booked CHAR(1);
        v_tutor_id  NUMBER;
    BEGIN
        SELECT is_booked, tutor_id 
        INTO v_is_booked, v_tutor_id 
        FROM availability_slots 
        WHERE slot_id = p_slot_id;

        IF v_is_booked = 'Y' THEN
            RAISE_APPLICATION_ERROR(-20001, 'Slot already booked');
        END IF;

        INSERT INTO bookings (student_id, tutor_id, slot_id, subject_id, status, booked_at)
        VALUES (p_student_id, v_tutor_id, p_slot_id, p_subject_id, 'CONFIRMED', SYSDATE);

        UPDATE availability_slots SET is_booked = 'Y' WHERE slot_id = p_slot_id;
        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'Slot not found');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END book_session;

    -- ==========================================
    -- 2. CANCEL BOOKING
    -- ==========================================
    PROCEDURE cancel_booking (
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

        UPDATE bookings SET status = 'CANCELLED' WHERE booking_id = p_booking_id;
        UPDATE availability_slots SET is_booked = 'N' WHERE slot_id = v_slot_id;
        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20005, 'Booking not found');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END cancel_booking;

    -- ==========================================
    -- 3. COMPLETE SESSION
    -- ==========================================
    PROCEDURE complete_session (
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

        UPDATE sessions 
        SET status = 'COMPLETED', 
            notes = NVL(p_notes, notes), 
            completed_at = SYSDATE 
        WHERE session_id = p_session_id;
        
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
    END complete_session;

    -- ==========================================
    -- 4. PRINT TUTOR SCHEDULE (EXPLICIT CURSOR)
    -- ==========================================
    PROCEDURE print_tutor_schedule (
        p_tutor_id IN NUMBER
    ) IS
        -- STEP 1: DECLARE the explicit cursor
        CURSOR c_tutor_slots IS
            SELECT slot_date, start_time, end_time, is_booked
            FROM availability_slots
            WHERE tutor_id = p_tutor_id
            ORDER BY slot_date, start_time;
        
        -- Variable to hold the fetched row data
        v_slot c_tutor_slots%ROWTYPE;
    BEGIN
        -- STEP 2: OPEN the cursor (executes the query)
        OPEN c_tutor_slots;
        
        DBMS_OUTPUT.PUT_LINE('--- Schedule for Tutor ID: ' || p_tutor_id || ' ---');
        
        -- STEP 3: FETCH rows in a loop
        LOOP
            FETCH c_tutor_slots INTO v_slot;
            
            -- Exit the loop when there are no more rows to fetch
            EXIT WHEN c_tutor_slots%NOTFOUND; 
            
            DBMS_OUTPUT.PUT_LINE('Date: ' || v_slot.slot_date || 
                                 ' | Time: ' || v_slot.start_time || ' - ' || v_slot.end_time || 
                                 ' | Booked: ' || v_slot.is_booked);
        END LOOP;
        
        -- STEP 4: CLOSE the cursor (frees up memory)
        CLOSE c_tutor_slots;
        DBMS_OUTPUT.PUT_LINE('--- End of Schedule ---');
    END print_tutor_schedule;

    -- ==========================================
    -- 5. GET TUTOR AVERAGE RATING
    -- ==========================================
    FUNCTION get_tutor_avg_rating (
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

    -- ==========================================
    -- 6. IS SLOT AVAILABLE
    -- ==========================================
    FUNCTION is_slot_available (
        p_slot_id IN NUMBER
    ) RETURN VARCHAR2 IS
        v_is_booked CHAR(1);
    BEGIN
        SELECT is_booked
        INTO v_is_booked
        FROM availability_slots
        WHERE slot_id = p_slot_id;

        IF v_is_booked = 'N' THEN
            RETURN 'Y';
        ELSE
            RETURN 'N';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'INVALID';
    END is_slot_available;

    -- ==========================================
    -- 7. COUNT SESSIONS BY STATUS
    -- ==========================================
    FUNCTION count_sessions_by_status (
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

END tutor_pkg;
/