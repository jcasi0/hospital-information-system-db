-- =========================================
-- АНАЛИТИКА ЗАТРАТ И ДАННЫХ
-- =========================================

-- 1. Общие расходы на лечение
-- Задача: рассчитать суммарные затраты на лечение всех пациентов
-- (что показывает: общий объём расходов)
SELECT SUM(treatment_cost) AS total_cost 
FROM results;

-- 2. Средняя стоимость лечения пациента
-- Задача: определить среднюю стоимость лечения
-- (что показывает: типичный уровень затрат)
SELECT AVG(patient_total_cost) AS avg_patient_cost FROM
(SELECT patient_id, SUM(treatment_cost) patient_total_cost
FROM periods JOIN results USING(period_id)
GROUP BY patient_id) t;

-- 3. Самые дорогие процедуры
-- Задача: найти процедуры с наибольшей стоимостью
-- (что показывает: основные источники затрат)
SELECT action_name, SUM(treatment_cost) total_cost
FROM results
GROUP BY action_name
ORDER BY total_cost DESC;

-- 4. Зависимость стоимости от длительности лечения
-- Задача: проанализировать, как длительность лечения влияет на стоимость
-- (что показывает: связь времени и затрат)
SELECT (CASE WHEN discharge_date IS NOT NULL
	   		THEN discharge_date - admission_date
			ELSE current_date - admission_date
		END) days_in_hospital,
		AVG(treatment_cost) avg_cost
FROM periods JOIN results USING(period_id)
GROUP BY days_in_hospital
ORDER BY days_in_hospital;

-- =========================================
-- ПРИКЛАДНЫЕ SQL-ЗАПРОСЫ
-- =========================================

-- 5. Выбрать все карты больных (номера), 
-- проходивших в текущем месяце обследование «ЭКГ» (название действия).
SELECT DISTINCT patient_id 
FROM periods JOIN results USING(period_id)
WHERE action_name = 'ЭКГ'
AND action_date >= date_trunc('month', current_date)
AND action_date < date_trunc('month', current_date) + interval '1 month';


-- 6. Рассчитать суммарное количество «платных» больных, 
-- размещённых на текущий момент в палатах больницы.
SELECT COUNT(DISTINCT patient_id) 
FROM patients JOIN periods USING(patient_id)
WHERE is_paid = true
AND wd_id IS NOT NULL
AND admission_date<=current_date
AND (discharge_date IS NULL OR discharge_date>=current_date);

-- 7. Выбрать последний пять назначений больного с ФИО Иванов Иван Иванович.
SELECT treatment_plan 
FROM results 
JOIN periods USING(period_id)
JOIN patients USING(patient_id)
WHERE last_name||' '||first_name||' '||middle_name = 'Иванов Иван Иванович'
ORDER BY result_id DESC
LIMIT 5;

-- 8. Измените во всех назначениях обследований, содержащих название лекарства «альбуцид», 
-- слово «альбуцид» на «сульфацетамид».
UPDATE results SET treatment_plan = 
replace(treatment_plan, 'альбуцид', 'сульфацетамид');

-- 9. Определить для каждой палаты количество мест и количество свободных мест.
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

-- 10. Для каждого пациента получить список проведённых обследований за текущий год и их общее количество.
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
