Ваша задача — смоделировать изменение балансов студентов.
Баланс — это количество уроков, которое есть у каждого студента. 
В результате должен получиться запрос, который собирает данные о балансах студентов за каждый "прожитый" ими день.
WITH first_payments AS --дата первой оплаты
        (
        SELECT user_id, DATE_TRUNC('day', MIN (transaction_datetime)) AS first_payment_date
        FROM skyeng_db.payments 
        WHERE status_name = 'success' AND id_transaction IS NOT NULL
        GROUP BY user_id
        ORDER BY user_id
        ),
all_dates AS --все дни 2016 года, уникальные даты уроков
        (
        SELECT DISTINCT DATE_TRUNC ('day',
                    class_start_datetime
                    ) AS dt
        FROM skyeng_db.classes AS cl
        WHERE EXTRACT(YEAR FROM class_start_datetime) = '2016'  
        ORDER BY dt
        ),
payments_by_dates AS --агрегацию, в которой для каждого клиента на каждую дату необходимо вывести сумму поля classes (только для успешных транзакций)
        (
        SELECT
            transaction_date,
            user_id,
            SUM(classes) AS transaction_balance_change  
        FROM (
            SELECT DATE_TRUNC ('day', transaction_datetime) transaction_date, user_id, classes
            FROM skyeng_db.payments
            WHERE status_name = 'success' AND id_transaction IS NOT NULL
            ) as tb 
        GROUP BY tb.transaction_date, tb.user_id
        ORDER BY user_id,transaction_date
        ),
all_dates_by_user AS --где будут храниться все даты жизни студента после того, как произошла его первая транзакция.
        (
        SELECT  user_id, dt
        FROM all_dates 
        JOIN first_payments
        ON first_payment_date <= dt
        ORDER BY user_id, dt
        ),
classes_by_dates AS --посчитав в таблице classes количество уроков за каждый день для каждого ученика, умножить на -1, чтобы отразить, что - — это списания с баланса
        (
        SELECT user_id
                , DATE_TRUNC ('day', class_start_datetime) AS class_date
                , COUNT (id_class)*-1 AS classes
        FROM skyeng_db.classes
        WHERE class_type != 'trial' AND class_status IN ('success','failed_by_student')
        GROUP BY user_id, class_date
        ORDER BY user_id, class_date
        ),
payments_by_dates_cumsum AS -- найти кумулятивную сумму по полю transaction_balance_change для всех строк до текущей включительно с разбивкой по user_id и сортировкой по dt
        (
        SELECT a.user_id
                 , dt
                 , transaction_balance_change 
                , SUM (CASE WHEN transaction_balance_change IS NULL THEN 0 else transaction_balance_change END) OVER (PARTITION BY a.user_id ORDER BY dt) AS transaction_balance_change_cs
        FROM all_dates_by_user AS a
        LEFT JOIN payments_by_dates AS b
                ON a.dt = b.transaction_date AND a.user_id = b.user_id
       ),
classes_by_dates_dates_cumsumс  AS --CTE для хранения кумулятивной суммы количества пройденных уроков. 
        (
        SELECT c.user_id
                , dt
                , classes  
                , SUM (CASE WHEN classes IS NULL THEN 0 else classes END) OVER (PARTITION BY c.user_id ORDER BY c.dt) AS classes_cs
        FROM all_dates_by_user AS c
        LEFT JOIN classes_by_dates AS d
        ON c.dt = d.class_date AND c.user_id = d.user_id
        ),
balances  AS --с вычисленными балансами каждого студента
        (
        SELECT e.user_id
            , e.dt
            , transaction_balance_change
            , transaction_balance_change_cs
            , classes
            , classes_cs
            ,classes_cs + transaction_balance_change_cs AS balance
        FROM payments_by_dates_cumsum AS e
        JOIN classes_by_dates_dates_cumsumс AS f
        ON e.dt = f.dt AND e.user_id = f.user_id
        ORDER BY e.user_id, e.dt
         )
SELECT dt  --Посмотрим, как менялось общее количество уроков на балансах студентов.
        , SUM (transaction_balance_change) AS transaction_balance_change_sum
        , SUM (transaction_balance_change_cs) AS transaction_balance_change_cs_sum
        , SUM (classes) AS classes_sum
        , SUM (classes_cs) AS classes_cs_sum
        , SUM (balance) AS balance_sum
FROM balances
GROUP BY dt
ORDER BY dt

