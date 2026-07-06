-- because this will be used with a UI later on it's better to package it up
CREATE OR REPLACE PACKAGE tutor_pkg IS
    
    -- PROCEDURES
    PROCEDURE book_session (
        p_student_id IN NUMBER,
        p_slot_id    IN NUMBER,
        p_subject_id IN NUMBER
    );

    PROCEDURE cancel_booking (
        p_booking_id IN NUMBER
    );

    PROCEDURE complete_session (
        p_session_id IN NUMBER,
        p_notes      IN VARCHAR2 DEFAULT NULL
    );

    -- NEW PROCEDURE WITH EXPLICIT CURSOR
    PROCEDURE print_tutor_schedule (
        p_tutor_id IN NUMBER
    );

    -- FUNCTIONS
    FUNCTION get_tutor_avg_rating (
        p_tutor_id IN NUMBER
    ) RETURN NUMBER;

    FUNCTION is_slot_available (
        p_slot_id IN NUMBER
    ) RETURN VARCHAR2;

    FUNCTION count_sessions_by_status (
        p_status IN VARCHAR2
    ) RETURN NUMBER;

END tutor_pkg;
/