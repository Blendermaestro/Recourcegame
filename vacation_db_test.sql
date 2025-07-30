-- 🔧 VACATION DATABASE TEST - Run this in Supabase SQL Editor to verify setup

-- Step 1: Check if vacation_absences table exists and has correct structure
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'vacation_absences' 
ORDER BY ordinal_position;

-- Step 2: Check current policies on vacation_absences table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'vacation_absences';

-- Step 3: Check if we can insert a test vacation record
-- (This will help identify any RLS issues)
INSERT INTO vacation_absences (
    vacation_id,
    employee_id,
    start_date,
    end_date,
    type,
    reason,
    notes,
    user_id
) VALUES (
    'test-vacation-123',
    'test-employee-456',
    '2024-01-15',
    '2024-01-20',
    'loma',
    'Test vacation',
    'Test notes',
    auth.uid()
) ON CONFLICT (vacation_id) DO UPDATE SET
    reason = EXCLUDED.reason;

-- Step 4: Try to read back the test record
SELECT * FROM vacation_absences WHERE vacation_id = 'test-vacation-123';

-- Step 5: Clean up test record
DELETE FROM vacation_absences WHERE vacation_id = 'test-vacation-123';

-- Step 6: Show current auth user info
SELECT 
    auth.uid() as current_user_id,
    auth.email() as current_user_email; 