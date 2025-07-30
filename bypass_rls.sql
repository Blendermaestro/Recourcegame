-- Check if RLS is blocking the update
-- Run these as separate queries

-- 1. Check RLS policies on employees table
SELECT policyname, cmd, permissive, roles, qual 
FROM pg_policies 
WHERE tablename = 'employees';

-- 2. Try updating with RLS bypassed (if you have admin access)
SET row_security = off;
UPDATE employees 
SET user_id = '5a647fef-b47a-4a11-8c0f-dac1b318a782'
WHERE user_id IS NULL;
SET row_security = on;

-- 3. Alternative: Delete and recreate the problematic employee that works
-- First, save the working employee data
SELECT * FROM employees WHERE name = 'afsfasdfds';

-- 4. If all else fails, we can delete all NULL employees and recreate them through the app
-- DELETE FROM employees WHERE user_id IS NULL; 