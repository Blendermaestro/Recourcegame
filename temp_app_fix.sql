-- TEMPORARY: Make all employees visible by giving them any valid user_id
-- Get the user_id from the working employee and apply it to all

UPDATE employees 
SET user_id = (
  SELECT user_id 
  FROM employees 
  WHERE user_id IS NOT NULL 
  LIMIT 1
)
WHERE user_id IS NULL;

-- Verify
SELECT 
  COUNT(*) as total_employees,
  COUNT(DISTINCT user_id) as unique_users,
  user_id
FROM employees 
GROUP BY user_id; 