CREATE OR REPLACE TRIGGER trg_audit_bookings
AFTER INSERT OR UPDATE OR DELETE ON bookings
FOR EACH ROW
DECLARE
    v_action    VARCHAR2(10);
    v_record_id NUMBER;
    v_old_val   VARCHAR2(4000);
    v_new_val   VARCHAR2(4000);
BEGIN
    -- Determine the action type
    IF INSERTING THEN 
        v_action := 'INSERT';
        v_record_id := :NEW.booking_id;
        v_old_val := NULL;
        v_new_val := 'Status: ' || :NEW.status || ', Slot: ' || :NEW.slot_id;
    ELSIF UPDATING THEN 
        v_action := 'UPDATE';
        v_record_id := :NEW.booking_id;
        v_old_val := 'Status: ' || :OLD.status;
        v_new_val := 'Status: ' || :NEW.status;
    ELSE 
        v_action := 'DELETE';
        v_record_id := :OLD.booking_id;
        v_old_val := 'Status: ' || :OLD.status || ', Slot: ' || :OLD.slot_id;
        v_new_val := NULL;
    END IF;

    -- Insert the audit record
    INSERT INTO audit_log (table_name, action, record_id, old_value, new_value, changed_by, changed_at)
    VALUES ('BOOKINGS', v_action, v_record_id, v_old_val, v_new_val, USER, SYSDATE);
END;
/