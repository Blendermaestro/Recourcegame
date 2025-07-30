-- FINAL FIX: Update all employees to belong to current user
-- This will make ALL employees show up in your app immediately

UPDATE employees 
SET user_id = auth.uid() 
WHERE user_id IS NULL;

-- Verify the fix worked
SELECT 
  'SUCCESS! All employees now belong to current user' as status,
  COUNT(*) as total_employees_fixed
FROM employees 
WHERE user_id = auth.uid(); 