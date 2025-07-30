-- 🔧 FIX VACATION CONSTRAINTS - Resolves ON CONFLICT error
-- Run this in Supabase SQL Editor to fix the unique constraint issue

-- Step 1: Check current constraints
SELECT 'Current constraints on vacation_absences:' as info;
SELECT 
    constraint_name, 
    constraint_type, 
    column_name
FROM information_schema.table_constraints tc
JOIN information_schema.constraint_column_usage ccu 
    ON tc.constraint_name = ccu.constraint_name
WHERE tc.table_name = 'vacation_absences'
ORDER BY constraint_type, constraint_name;

-- Step 2: Add unique constraint on vacation_id if it doesn't exist
DO $$
BEGIN
    -- Check if unique constraint on vacation_id exists
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints tc
        JOIN information_schema.constraint_column_usage ccu 
            ON tc.constraint_name = ccu.constraint_name
        WHERE tc.table_name = 'vacation_absences' 
        AND tc.constraint_type = 'UNIQUE'
        AND ccu.column_name = 'vacation_id'
    ) THEN
        -- Add unique constraint
        ALTER TABLE public.vacation_absences 
        ADD CONSTRAINT vacation_absences_vacation_id_unique 
        UNIQUE (vacation_id);
        
        RAISE NOTICE '✅ Added unique constraint on vacation_id';
    ELSE
        RAISE NOTICE 'ℹ️ Unique constraint on vacation_id already exists';
    END IF;
END $$;

-- Step 3: Verify constraints after fix
SELECT 'Updated constraints on vacation_absences:' as info;
SELECT 
    constraint_name, 
    constraint_type, 
    column_name
FROM information_schema.table_constraints tc
JOIN information_schema.constraint_column_usage ccu 
    ON tc.constraint_name = ccu.constraint_name
WHERE tc.table_name = 'vacation_absences'
ORDER BY constraint_type, constraint_name;

-- Step 4: Test insert with ON CONFLICT (should work now)
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
    'test-constraint-fix-123',
    'test-employee-456',
    '2024-01-15',
    '2024-01-20',
    'loma',
    'Test vacation - constraint fix',
    'Test notes',
    auth.uid()
) ON CONFLICT (vacation_id) DO UPDATE SET
    reason = EXCLUDED.reason;

-- Step 5: Verify the insert worked
SELECT 'Test record after constraint fix:' as info;
SELECT vacation_id, employee_id, type, reason, start_date, end_date
FROM vacation_absences 
WHERE vacation_id = 'test-constraint-fix-123';

-- Step 6: Try the same insert again (should trigger ON CONFLICT)
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
    'test-constraint-fix-123',
    'test-employee-456',
    '2024-01-15',
    '2024-01-20',
    'loma',
    'Test vacation - UPDATED REASON',
    'Test notes',
    auth.uid()
) ON CONFLICT (vacation_id) DO UPDATE SET
    reason = EXCLUDED.reason;

-- Step 7: Verify the update worked
SELECT 'Test record after ON CONFLICT update:' as info;
SELECT vacation_id, employee_id, type, reason, start_date, end_date
FROM vacation_absences 
WHERE vacation_id = 'test-constraint-fix-123';

-- Step 8: Clean up test record
DELETE FROM vacation_absences WHERE vacation_id = 'test-constraint-fix-123';

SELECT '✅ Constraint fix completed - ON CONFLICT should work now!' as result; 