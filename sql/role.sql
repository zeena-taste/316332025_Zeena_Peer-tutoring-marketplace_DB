-- Lower-privileged role for a tutee-facing app user (separate from the schema owner)
CREATE ROLE tutee_role;

GRANT SELECT ON subjects        TO tutee_role;
GRANT SELECT ON tutor_profiles  TO tutee_role;
GRANT SELECT ON availability_slots TO tutee_role;
GRANT SELECT, INSERT ON bookings TO tutee_role;
GRANT SELECT, INSERT ON ratings  TO tutee_role;
GRANT EXECUTE ON book_session    TO tutee_role;
GRANT EXECUTE ON get_tutor_avg_rating TO tutee_role;
GRANT EXECUTE ON is_slot_available TO tutee_role;

-- Demo low-privilege user to show the separation live
CREATE USER tutee_demo_user IDENTIFIED BY DemoPass123;
GRANT CONNECT TO tutee_demo_user;
GRANT tutee_role TO tutee_demo_user;

-- Prove it: connect as tutee_demo_user and confirm this FAILS (no DELETE grant)
-- DELETE FROM bookings WHERE booking_id = 1;   -- should raise ORA-01031: insufficient privileges