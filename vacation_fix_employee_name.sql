-- 🔧 FIX EMPLOYEE_NAME COLUMN - Resolves NOT NULL constraint error
-- Run this in Supabase SQL Editor to fix the employee_name column issue

-- Step 1: Check current table structure to see all columns
SELECT 'Current vacation_absences columns:' as info;
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'vacation_absences' 
ORDER BY ordinal_position;

-- Step 2: Check if employee_name column exists and is NOT NULL
SELECT 'Employee_name column details:' as info;
SELECT 
    column_name,
    is_nullable,
    data_type
FROM information_schema.columns 
WHERE table_name = 'vacation_absences' 
AND column_name = 'employee_name';

-- Step 3: Make employee_name column nullable (safest approach)
DO $$
BEGIN
    -- Check if employee_name column exists and is NOT NULL
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vacation_absences' 
        AND column_name = 'employee_name'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.vacation_absences 
        ALTER COLUMN employee_name DROP NOT NULL;
        
        RAISE NOTICE '✅ Made employee_name column nullable';
    ELSE
        RAISE NOTICE 'ℹ️ employee_name column is already nullable or does not exist';
    END IF;
END $$;

-- Step 4: Verify the change
SELECT 'Updated employee_name column:' as info;
SELECT 
    column_name,
    is_nullable,
    data_type
FROM information_schema.columns 
WHERE table_name = 'vacation_absences' 
AND column_name = 'employee_name';

-- Step 5: Test insert without employee_name (should work now)
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
    'test-employee-name-fix-' || gen_random_uuid()::text,
    'test-employee-' || gen_random_uuid()::text,
    '2024-01-15',
    '2024-01-20',
    'loma',
    'Test vacation - employee_name fix',
    'Test notes',
    auth.uid()
);

-- Step 6: Verify the insert worked
SELECT 'Test record after employee_name fix:' as info;
SELECT 
    vacation_id, 
    employee_id, 
    employee_name,
    type, 
    reason, 
    start_date, 
    end_date
FROM vacation_absences 
WHERE vacation_id LIKE 'test-employee-name-fix-%';

-- Step 7: Clean up test record
DELETE FROM vacation_absences WHERE vacation_id LIKE 'test-employee-name-fix-%';

SELECT '✅ Employee_name constraint fix completed successfully!' as result; 