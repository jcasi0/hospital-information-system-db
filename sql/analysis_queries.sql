-- 1. Выбрать все карты больных (номера), 
-- проходивших в текущем месяце обследование «ЭКГ» (название действия).
SELECT DISTINCT patient_id 
FROM periods JOIN results USING(period_id)
WHERE action_name = 'ЭКГ'
AND action_date >= date_trunc('month', current_date)
AND action_date < date_trunc('month', current_date) + interval '1 month';


-- 2. Рассчитать суммарное количество «платных» больных, 
-- размещённых на текущий момент в палатах больницы.
SELECT COUNT(DISTINCT patient_id) 
FROM patients JOIN periods USING(patient_id)
WHERE is_paid = true
AND wd_id IS NOT NULL
AND admission_date<=current_date
AND (discharge_date IS NULL OR discharge_date>=current_date);

-- 3. Выбрать последний пять назначений больного с ФИО Иванов Иван Иванович.
SELECT treatment_plan 
FROM results 
JOIN periods USING(period_id)
JOIN patients USING(patient_id)
WHERE last_name||' '||first_name||' '||middle_name = 'Иванов Иван Иванович'
ORDER BY result_id DESC
LIMIT 5;

-- 4. Измените во всех назначениях обследований, содержащих название лекарства «альбуцид», 
-- слово «альбуцид» на «сульфацетамид».
UPDATE results SET treatment_plan = 
replace(treatment_plan, 'альбуцид', 'сульфацетамид');

-- 5. Определить для каждой палаты количество мест и количество свободных мест.
WITH t AS(
	SELECT wd.ward_id
	FROM periods p JOIN wards_departments wd USING (wd_id)
	WHERE current_date >= admission_date
	AND (discharge_date IS NULL OR discharge_date>=current_date)
)
SELECT ward_id "номер палаты",
	   capacity "кол-во мест",
	   capacity - 
	   (SELECT count(ward_id) FROM t
	   WHERE t.ward_id = wards.ward_id) "кол-во свободных мест"
FROM wards;

-- 6. Для каждого пациента получить список проведённых обследований за текущий год и их общее количество.
WITH t AS(
	SELECT patient_id, action_name
	FROM periods JOIN results USING(period_id)
	WHERE EXTRACT(YEAR FROM action_date) = EXTRACT(YEAR FROM current_date)
)
SELECT patient_id, 
	   string_agg(action_name, ', ') "обследования",
	   count(patient_id)
FROM t
GROUP BY patient_id;