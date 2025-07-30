-- Manual fix using the known working user_id
-- We know '5a647fef-b47a-4a11-8c0f-dac1b318a782' works because afsfasdfds employee uses it

-- First, let's check what auth.uid() returns
SELECT auth.uid() as current_user_id;

-- Update all NULL user_ids to the working user_id
UPDATE employees 
SET user_id = '5a647fef-b47a-4a11-8c0f-dac1b318a782'
WHERE user_id IS NULL;

-- Verify the fix
SELECT 
  name,
  category, 
  user_id,
  CASE 
    WHEN user_id = '5a647fef-b47a-4a11-8c0f-dac1b318a782' THEN '✅ FIXED'
    ELSE '❌ STILL NULL'
  END as status
FROM employees 
ORDER BY category, name 
LIMIT 10; 