-- 1. Добавление в базу данных информацию о стоимости обследования.
ALTER TABLE results
ADD COLUMN IF NOT EXISTS treatment_cost numeric(9,2);

-- 2. Добавление в базу данных ограничения целостности, 
-- не позволяющего выставлять стоимость обследования больше 100000 руб. и меньше 10 руб.
ALTER TABLE results
DROP CONSTRAINT IF EXISTS check_treatment_cost;
ALTER TABLE results
ADD CONSTRAINT check_treatment_cost
CHECK(treatment_cost<=100000 AND treatment_cost>=10);

-- 3. Триггер не позволяет назначать «бесплатным» больным лечение дороже 5000 руб.
DROP TRIGGER IF EXISTS check_paid_patient_cost ON results;
DROP FUNCTION IF EXISTS check_paid_patient_cost;

CREATE FUNCTION check_paid_patient_cost() RETURNS trigger AS $$
DECLARE 
	p_id integer;
	paid boolean;
BEGIN
	SELECT patient_id INTO p_id
	FROM periods WHERE period_id = NEW.period_id;
	SELECT is_paid INTO paid
	FROM patients WHERE patient_id = p_id;
	IF paid is false
		THEN RAISE EXCEPTION 'Запрещено: бесплатный пациент (patient_id=%) не может иметь лечение стоимостью % руб.',
    		p_id,
    		NEW.treatment_cost;
	END IF;
	RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE trigger check_paid_patient_cost
BEFORE INSERT OR UPDATE ON results
FOR EACH ROW
WHEN (NEW.treatment_cost>5000)
EXECUTE FUNCTION check_paid_patient_cost();

-- 4. Написать функцию, которая позволяет по номеру карты пациента 
-- вычислить суммарную стоимость оказанных ему услуг (действий). Результат – число.
DROP FUNCTION IF EXISTS get_patient_total_cost;
CREATE FUNCTION get_patient_total_cost(p_id integer) RETURNS numeric AS $$
BEGIN
	RETURN COALESCE((SELECT sum(treatment_cost)
	FROM results JOIN periods USING(period_id) WHERE patient_id = p_id),0);
END; $$ LANGUAGE plpgsql;

-- 5. Написать агрегатную функцию, которая для множества пациентов (номера карт), 
-- определяет суммарное количество выполненных действий (обследований и т.д.).
DROP AGGREGATE IF EXISTS result_count(integer);
DROP FUNCTION IF EXISTS result_count_step;

CREATE FUNCTION result_count_step(integer, integer) RETURNS integer AS $$
BEGIN
	IF $2 IS NOT NULL THEN
		RETURN $1+1;
	ELSE
		RETURN $1;
	END IF;
END; $$ LANGUAGE plpgsql; 

CREATE AGGREGATE result_count(integer)(
	initcond = 0,
	stype = integer,
	sfunc = result_count_step
);

SELECT p.patient_id, result_count(result_id) 
FROM patients p LEFT JOIN periods USING(patient_id) 
LEFT JOIN results USING(period_id)
GROUP BY p.patient_id
ORDER BY p.patient_id;

-- 6. Создать представление, отображающее ФИО больного, дату его поступления, номер палаты,
-- и ключевые поля таблицы, описывающей периоды пребывания больного.
-- Реализуйте возможность изменения номера палаты через это представление в реальной таблице.
DROP TRIGGER IF EXISTS t6 ON v;
DROP FUNCTION IF EXISTS update_ward_from_view;
DROP VIEW IF EXISTS v;

CREATE VIEW v AS
SELECT last_name||' '||first_name||' '||middle_name "ФИО",
	   admission_date, ward_id, period_id, patient_id
FROM patients JOIN periods USING(patient_id) JOIN wards_departments USING(wd_id);

-- надо поменять wd_id на wd_id, где будет нужная палата
CREATE FUNCTION update_ward_from_view() RETURNS TRIGGER AS $$
DECLARE
	new_wd_id integer;
BEGIN
	SELECT wd_id INTO new_wd_id
	FROM wards_departments WHERE ward_id = NEW.ward_id LIMIT 1;

	IF NEW.ward_id = OLD.ward_id OR new_wd_id IS NULL THEN
		RETURN OLD;
	ELSE
		UPDATE periods SET wd_id = new_wd_id
		WHERE period_id = OLD.period_id;
		RETURN NEW;
	END IF;
END; $$ LANGUAGE plpgsql;

CREATE trigger t6
INSTEAD OF UPDATE ON v
FOR EACH ROW
EXECUTE FUNCTION update_ward_from_view();