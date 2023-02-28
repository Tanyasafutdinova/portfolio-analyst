Есть 2 таблицы с данными. В таблице tasks лежат заявки от клиентов, в таблице calls лежат звонки от менеджеров клиентам.
📁 Таблица tasks
client_id (идентификатор клиента)
created_datetime (время клиентской заявки)
title (тема обращения)
📁 Таблица calls
manager_id (идентификатор менеджера)
client_id (идентификатор клиента, которому звонят)
call_datetime (время менеджерского звонка)

--1. Сколько заявок приходило каждый день в июне 2022 года.
SELECT created_datetime, COUNT (client_id) AS count_tasks
FROM tasks
WHERE created_datetime >='01-06-2022' AND  created_datetime <'01-07-2022' 
GROUP BY created_datetime;

--2. Список тем, для которых обращений было больше 10 в апреле 2022 года
SELECT title, COUNT (client_id) AS count_tasks
FROM tasks
WHERE created_datetime >='01-04-2022' AND  created_datetime <'01-05-2022'
GROUP BY  title
HAVING COUNT (client_id) > 10; 

--3.Список клиентов, которые оставляли заявку, но которым не звонил менеджер ни разу.
SELECT tasks.client_id 
FROM tasks
LEFT JOIN calls ON tasks.client_id = calls.client_id 
WHERE calls.client_id IS NULL; 

--4. Список клиентов, последние заявки которых не обработаны. Считаем, что если менеджер позвонил клиенту после заявки,то он ее обработал. Если заявок до звонка было несколько, то при звонке обрабатываются все заявки сразу.
SELECT tasks.client_id
FROM tasks
LEFT JOIN calls ON tasks.client_id = calls.client_id AND tasks.created_datetime <= calls.call_datetime
WHERE calls.client_id IS NULL; 

--5. Минимальную разницу между обращениями для каждого клиента. Затем выведите среднее по полученным значениям.
WITH min_time AS 
        (
        SELECT a.client_id, MIN(difference_time) as min_dif_time
        FROM
            (
            SELECT client_id, created_datetime,
            created_datetime - LAG(created_datetime) over (partition by client_id order by created_datetime) AS difference_time
            FROM tasks
            ) a
		WHERE difference_time IS NOT NULL
        GROUP BY a.client_id
        ) 
SELECT AVG (min_dif_time) AS avg_min_time
FROM min_time;
