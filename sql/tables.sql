-- 1. Root tables (no dependencies)
CREATE TABLE students (
    student_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name      VARCHAR2(100) NOT NULL,
    email          VARCHAR2(100) UNIQUE NOT NULL,
    program        VARCHAR2(50) NOT NULL,
    year_of_study  NUMBER NOT NULL CHECK (year_of_study BETWEEN 1 AND 6)
);

CREATE TABLE subjects (
    subject_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    subject_code   VARCHAR2(20) UNIQUE NOT NULL,
    subject_name   VARCHAR2(100) NOT NULL
);

CREATE TABLE holidays (
    holiday_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    holiday_date   DATE UNIQUE NOT NULL,
    description    VARCHAR2(100) NOT NULL
);

-- 2. TUTOR_PROFILES (references STUDENTS)
CREATE TABLE tutor_profiles (
    tutor_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id     NUMBER NOT NULL UNIQUE REFERENCES students(student_id),
    bio            VARCHAR2(500),
    hourly_rate    NUMBER NOT NULL CHECK (hourly_rate > 0),
    verified_flag  CHAR(1) DEFAULT 'N' NOT NULL CHECK (verified_flag IN ('Y','N'))
);

-- 3. TUTOR_SUBJECTS, AVAILABILITY_SLOTS (reference TUTOR_PROFILES)
CREATE TABLE tutor_subjects (
    tutor_id       NUMBER NOT NULL REFERENCES tutor_profiles(tutor_id),
    subject_id     NUMBER NOT NULL REFERENCES subjects(subject_id),
    PRIMARY KEY (tutor_id, subject_id)
);

CREATE TABLE availability_slots (
    slot_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tutor_id       NUMBER NOT NULL REFERENCES tutor_profiles(tutor_id),
    slot_date      DATE NOT NULL,
    start_time     VARCHAR2(5) NOT NULL,
    end_time       VARCHAR2(5) NOT NULL,
    is_booked      CHAR(1) DEFAULT 'N' NOT NULL CHECK (is_booked IN ('Y','N')),
    CHECK (end_time > start_time)
);

-- 4. BOOKINGS (references STUDENTS, AVAILABILITY_SLOTS, etc.)
CREATE TABLE bookings (
    booking_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id     NUMBER NOT NULL REFERENCES students(student_id),
    tutor_id       NUMBER NOT NULL REFERENCES tutor_profiles(tutor_id),
    slot_id        NUMBER NOT NULL UNIQUE REFERENCES availability_slots(slot_id),
    subject_id     NUMBER NOT NULL REFERENCES subjects(subject_id),
    status         VARCHAR2(20) DEFAULT 'PENDING' NOT NULL CHECK (status IN ('PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED')),
    booked_at      DATE DEFAULT SYSDATE NOT NULL
);

-- 5. SESSIONS (references BOOKINGS)
CREATE TABLE sessions (
    session_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id     NUMBER NOT NULL UNIQUE REFERENCES bookings(booking_id),
    status         VARCHAR2(20) DEFAULT 'SCHEDULED' NOT NULL CHECK (status IN ('SCHEDULED', 'COMPLETED', 'CANCELLED')),
    notes          VARCHAR2(500),
    completed_at   DATE
);

-- 6. RATINGS (references SESSIONS)
CREATE TABLE ratings (
    rating_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    session_id     NUMBER NOT NULL UNIQUE REFERENCES sessions(session_id),
    score          NUMBER NOT NULL CHECK (score BETWEEN 1 AND 5),
    comments       VARCHAR2(500),
    rated_at       DATE DEFAULT SYSDATE NOT NULL
);

-- 7. AUDIT_LOG (standalone)
CREATE TABLE audit_log (
    log_id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name     VARCHAR2(50) NOT NULL,
    action         VARCHAR2(20) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    record_id      NUMBER NOT NULL,
    old_value      VARCHAR2(4000),
    new_value      VARCHAR2(4000),
    changed_by     VARCHAR2(50) NOT NULL,
    changed_at     DATE DEFAULT SYSDATE NOT NULL
);