-- Fix the missing user_id issue
-- Update all employees to have the same user_id as the working employee

UPDATE employees 
SET user_id = '5a647fef-b47a-4a11-8c0f-dac1b318a782' 
WHERE user_id IS NULL OR user_id = '';

-- Verify the fix
SELECT 
  name, 
  category,
  CASE 
    WHEN user_id IS NULL THEN 'NULL'
    WHEN user_id = '' THEN 'EMPTY'
    ELSE 'HAS USER_ID'
  END as user_id_status,
  COUNT(*) OVER (PARTITION BY category) as category_count
FROM employees 
ORDER BY category, name; 