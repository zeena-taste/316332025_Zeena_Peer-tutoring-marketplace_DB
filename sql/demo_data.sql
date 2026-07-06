-- ==========================================
-- 1. STUDENTS (6 students, 2 will become tutors)
-- ==========================================
INSERT INTO students (full_name, email, program, year_of_study) VALUES ('Alice Kamali', 'alice.kamali@ur.ac.rw', 'Computer Science', 3);
INSERT INTO students (full_name, email, program, year_of_study) VALUES ('Bob Mugisha', 'bob.mugisha@ur.ac.rw', 'Engineering', 4);
INSERT INTO students (full_name, email, program, year_of_study) VALUES ('Charlie Niyonzima', 'charlie.n@ur.ac.rw', 'Business', 2);
INSERT INTO students (full_name, email, program, year_of_study) VALUES ('Diana Uwimana', 'diana.u@ur.ac.rw', 'Medicine', 3);
INSERT INTO students (full_name, email, program, year_of_study) VALUES ('Eve Habimana', 'eve.h@ur.ac.rw', 'Law', 1);
INSERT INTO students (full_name, email, program, year_of_study) VALUES ('Frank Iradukunda', 'frank.i@ur.ac.rw', 'Architecture', 2);

-- ==========================================
-- 2. TUTOR_PROFILES (Alice and Bob are tutors)
-- ==========================================
INSERT INTO tutor_profiles (student_id, bio, hourly_rate, verified_flag) VALUES (1, 'Expert in calculus and mechanics.', 5000, 'Y');
INSERT INTO tutor_profiles (student_id, bio, hourly_rate, verified_flag) VALUES (2, 'Passionate about organic chemistry and biology.', 4500, 'Y');

-- ==========================================
-- 3. SUBJECTS (4 subjects)
-- ==========================================
INSERT INTO subjects (subject_code, subject_name) VALUES ('MATH101', 'Calculus I');
INSERT INTO subjects (subject_code, subject_name) VALUES ('PHY102', 'Classical Mechanics');
INSERT INTO subjects (subject_code, subject_name) VALUES ('CHEM103', 'Organic Chemistry');
INSERT INTO subjects (subject_code, subject_name) VALUES ('BIO104', 'Human Anatomy');

-- ==========================================
-- 4. TUTOR_SUBJECTS (Pairings)
-- ==========================================
-- Alice teaches Math and Physics
INSERT INTO tutor_subjects (tutor_id, subject_id) VALUES (1, 1);
INSERT INTO tutor_subjects (tutor_id, subject_id) VALUES (1, 2);
-- Bob teaches Chemistry and Biology
INSERT INTO tutor_subjects (tutor_id, subject_id) VALUES (2, 3);
INSERT INTO tutor_subjects (tutor_id, subject_id) VALUES (2, 4);

-- ==========================================
-- 5. AVAILABILITY_SLOTS (9 slots across July 2026)
-- ==========================================
-- Alice's slots
INSERT INTO availability_slots (tutor_id, slot_date, start_time, end_time, is_booked) VALUES (1, TO_DATE('2026-07-10','YYYY-MM-DD'), '09:00', '11:00', 'Y');
INSERT INTO availability_slots (tutor_id, slot_date, start_time, end_time, is_booked) VALUES (1, TO_DATE('2026-07-10','YYYY-MM-DD'), '14:00', '16:00', 'Y');
INSERT INTO availability_slots (tutor_id, slot_date, start_time, end_time, is_booked) VALUES (1, TO_DATE('2026-07-12','YYYY-MM-DD'), '10:00', '12:00', 'Y');
INSERT INTO availability_slots (tutor_id, slot_date, start_time, end_time, is_booked) VALUES (1, TO_DATE('2026-07-15','YYYY-MM-DD'), '09:00', '11:00', 'N');
-- Bob's slots
INSERT INTO availability_slots (tutor_id, slot_date, start_time, end_time, is_booked) VALUES (2, TO_DATE('2026-07-11','YYYY-MM-DD'), '13:00', '15:00', 'Y');
INSERT INTO availability_slots (tutor_id, slot_date, start_time, end_time, is_booked) VALUES (2, TO_DATE('2026-07-11','YYYY-MM-DD'), '15:00', '17:00', 'Y');
INSERT INTO availability_slots (tutor_id, slot_date, start_time, end_time, is_booked) VALUES (2, TO_DATE('2026-07-13','YYYY-MM-DD'), '08:00', '10:00', 'N');
INSERT INTO availability_slots (tutor_id, slot_date, start_time, end_time, is_booked) VALUES (2, TO_DATE('2026-07-14','YYYY-MM-DD'), '14:00', '16:00', 'N');
INSERT INTO availability_slots (tutor_id, slot_date, start_time, end_time, is_booked) VALUES (2, TO_DATE('2026-07-16','YYYY-MM-DD'), '09:00', '11:00', 'N');

-- ==========================================
-- 6. BOOKINGS (5 bookings with mixed statuses)
-- ==========================================
INSERT INTO bookings (student_id, tutor_id, slot_id, subject_id, status, booked_at) VALUES (3, 1, 1, 1, 'COMPLETED', TO_DATE('2026-07-05','YYYY-MM-DD'));
INSERT INTO bookings (student_id, tutor_id, slot_id, subject_id, status, booked_at) VALUES (4, 1, 2, 2, 'COMPLETED', TO_DATE('2026-07-06','YYYY-MM-DD'));
INSERT INTO bookings (student_id, tutor_id, slot_id, subject_id, status, booked_at) VALUES (5, 2, 5, 3, 'CANCELLED', TO_DATE('2026-07-07','YYYY-MM-DD'));
INSERT INTO bookings (student_id, tutor_id, slot_id, subject_id, status, booked_at) VALUES (6, 2, 6, 4, 'CONFIRMED', TO_DATE('2026-07-07','YYYY-MM-DD'));
INSERT INTO bookings (student_id, tutor_id, slot_id, subject_id, status, booked_at) VALUES (3, 1, 3, 1, 'PENDING', TO_DATE('2026-07-08','YYYY-MM-DD'));

-- ==========================================
-- 7. SESSIONS (For the completed bookings)
-- ==========================================
INSERT INTO sessions (booking_id, status, notes, completed_at) VALUES (1, 'COMPLETED', 'Great session, finally understood integrals.', TO_DATE('2026-07-10','YYYY-MM-DD'));
INSERT INTO sessions (booking_id, status, notes, completed_at) VALUES (2, 'COMPLETED', 'Good progress on Newton laws of motion.', TO_DATE('2026-07-10','YYYY-MM-DD'));

-- ==========================================
-- 8. RATINGS (For the completed sessions)
-- ==========================================
INSERT INTO ratings (session_id, score, comments, rated_at) VALUES (1, 5, 'Alice explains things very clearly!', TO_DATE('2026-07-10','YYYY-MM-DD'));
INSERT INTO ratings (session_id, score, comments, rated_at) VALUES (2, 4, 'Very helpful, but went a bit fast at the end.', TO_DATE('2026-07-10','YYYY-MM-DD'));

-- ==========================================
-- 9. HOLIDAYS (6 Rwandan Public Holidays for 2026)
-- ==========================================
INSERT INTO holidays (holiday_date, description) VALUES (TO_DATE('2026-01-01','YYYY-MM-DD'), 'New Year''s Day');
INSERT INTO holidays (holiday_date, description) VALUES (TO_DATE('2026-02-01','YYYY-MM-DD'), 'National Heroes Day');
INSERT INTO holidays (holiday_date, description) VALUES (TO_DATE('2026-04-07','YYYY-MM-DD'), 'Genocide against the Tutsi Memorial Day');
INSERT INTO holidays (holiday_date, description) VALUES (TO_DATE('2026-05-01','YYYY-MM-DD'), 'Labour Day');
INSERT INTO holidays (holiday_date, description) VALUES (TO_DATE('2026-07-01','YYYY-MM-DD'), 'Independence Day');
INSERT INTO holidays (holiday_date, description) VALUES (TO_DATE('2026-07-04','YYYY-MM-DD'), 'Liberation Day');

-- ==========================================
-- 10. AUDIT_LOG (A couple of dummy tracking rows)
-- ==========================================
INSERT INTO audit_log (table_name, action, record_id, old_value, new_value, changed_by, changed_at) VALUES ('STUDENTS', 'INSERT', 1, NULL, 'Alice Kamali added', 'ADMIN', TO_DATE('2026-07-01','YYYY-MM-DD'));
INSERT INTO audit_log (table_name, action, record_id, old_value, new_value, changed_by, changed_at) VALUES ('BOOKINGS', 'UPDATE', 1, 'PENDING', 'COMPLETED', 'SYSTEM', TO_DATE('2026-07-10','YYYY-MM-DD'));

COMMIT;