-- simple trigger for rating validation
CREATE OR REPLACE TRIGGER trg_validate_rating
BEFORE INSERT OR UPDATE ON ratings
FOR EACH ROW
BEGIN
    IF :NEW.score NOT BETWEEN 1 AND 5 THEN
        RAISE_APPLICATION_ERROR(-20010, 'Rating must be between 1 and 5');
    END IF;
END;
/

-- compound trigger for blocking holidays and weekdays
CREATE OR REPLACE TRIGGER trg_block_weekday_holiday
FOR INSERT OR UPDATE ON bookings
COMPOUND TRIGGER

    BEFORE STATEMENT IS
        v_day           VARCHAR2(10);
        v_holiday_count NUMBER;
    BEGIN
        -- Get the day of the week in English to avoid language setting issues
        v_day := TO_CHAR(SYSDATE, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH');

        -- Check if today is a public holiday
        SELECT COUNT(*) INTO v_holiday_count
        FROM holidays
        WHERE holiday_date = TRUNC(SYSDATE);

        -- Block if it's a weekday OR if it's a holiday
        IF v_day NOT IN ('SAT', 'SUN') OR v_holiday_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20011, 'Bookings are blocked on weekdays and public holidays.');
        END IF;
    END BEFORE STATEMENT;

END trg_block_weekday_holiday;
/