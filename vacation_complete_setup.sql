-- 🔧 VACATION COMPLETE SETUP - Fixes ALL database issues at once
-- Run this in Supabase SQL Editor to completely set up the vacation system

-- Step 1: Drop the existing table if it has issues (ONLY if needed)
-- Uncomment the next line ONLY if you want to start completely fresh
-- DROP TABLE IF EXISTS public.vacation_absences;

-- Step 2: Create the complete table with ALL required columns
CREATE TABLE IF NOT EXISTS public.vacation_absences (
    id BIGSERIAL PRIMARY KEY,
    vacation_id UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,
    employee_name TEXT, -- Made nullable to avoid constraint issues
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('loma', 'poissaolo')),
    reason TEXT, -- Optional field for vacation reason
    notes TEXT, -- Optional field for additional notes
    user_id UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 3: Add any missing columns to existing table (safe for existing data)
DO $$
BEGIN
    -- Add reason column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vacation_absences' AND column_name = 'reason'
    ) THEN
        ALTER TABLE public.vacation_absences ADD COLUMN reason TEXT;
        RAISE NOTICE '✅ Added reason column';
    END IF;

    -- Add notes column if it doesn't exist  
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vacation_absences' AND column_name = 'notes'
    ) THEN
        ALTER TABLE public.vacation_absences ADD COLUMN notes TEXT;
        RAISE NOTICE '✅ Added notes column';
    END IF;

    -- Add user_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vacation_absences' AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.vacation_absences ADD COLUMN user_id UUID REFERENCES auth.users(id);
        RAISE NOTICE '✅ Added user_id column';
    END IF;

    -- Add employee_name column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vacation_absences' AND column_name = 'employee_name'
    ) THEN
        ALTER TABLE public.vacation_absences ADD COLUMN employee_name TEXT;
        RAISE NOTICE '✅ Added employee_name column';
    END IF;

    -- Make employee_name nullable if it's NOT NULL
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vacation_absences' 
        AND column_name = 'employee_name'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.vacation_absences ALTER COLUMN employee_name DROP NOT NULL;
        RAISE NOTICE '✅ Made employee_name column nullable';
    END IF;
END $$;

-- Step 4: Add unique constraint on vacation_id if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.constraint_column_usage ccu 
            ON tc.constraint_name = ccu.constraint_name
        WHERE tc.table_name = 'vacation_absences' 
        AND tc.constraint_type = 'UNIQUE'
        AND ccu.column_name = 'vacation_id'
    ) THEN
        ALTER TABLE public.vacation_absences 
        ADD CONSTRAINT vacation_absences_vacation_id_unique 
        UNIQUE (vacation_id);
        RAISE NOTICE '✅ Added unique constraint on vacation_id';
    END IF;
END $$;

-- Step 5: Enable Row Level Security
ALTER TABLE public.vacation_absences ENABLE ROW LEVEL SECURITY;

-- Step 6: Drop all existing policies to avoid conflicts
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can view their own vacation absences" ON public.vacation_absences;
    DROP POLICY IF EXISTS "Users can insert their own vacation absences" ON public.vacation_absences;
    DROP POLICY IF EXISTS "Users can update their own vacation absences" ON public.vacation_absences;
    DROP POLICY IF EXISTS "Users can delete their own vacation absences" ON public.vacation_absences;
    DROP POLICY IF EXISTS "Shared vacation absences - SELECT" ON public.vacation_absences;
    DROP POLICY IF EXISTS "Shared vacation absences - INSERT" ON public.vacation_absences;
    DROP POLICY IF EXISTS "Shared vacation absences - UPDATE" ON public.vacation_absences;
    DROP POLICY IF EXISTS "Shared vacation absences - DELETE" ON public.vacation_absences;
    RAISE NOTICE '🧹 Cleaned up all existing policies';
END $$;

-- Step 7: Create fresh shared access policies
CREATE POLICY "Shared vacation absences - SELECT" 
ON public.vacation_absences FOR SELECT 
USING (true);

CREATE POLICY "Shared vacation absences - INSERT" 
ON public.vacation_absences FOR INSERT 
WITH CHECK (true);

CREATE POLICY "Shared vacation absences - UPDATE" 
ON public.vacation_absences FOR UPDATE 
USING (true);

CREATE POLICY "Shared vacation absences - DELETE" 
ON public.vacation_absences FOR DELETE 
USING (true);

-- Step 8: Verify the final table structure
SELECT '=== FINAL TABLE STRUCTURE ===' as info;
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'vacation_absences' 
ORDER BY ordinal_position;

-- Step 9: Verify constraints
SELECT '=== TABLE CONSTRAINTS ===' as info;
SELECT 
    constraint_name, 
    constraint_type, 
    column_name
FROM information_schema.table_constraints tc
JOIN information_schema.constraint_column_usage ccu 
    ON tc.constraint_name = ccu.constraint_name
WHERE tc.table_name = 'vacation_absences'
ORDER BY constraint_type, constraint_name;

-- Step 10: Verify policies
SELECT '=== TABLE POLICIES ===' as info;
SELECT policyname, cmd, permissive
FROM pg_policies 
WHERE tablename = 'vacation_absences';

-- Step 11: Test complete insert with all fields
INSERT INTO vacation_absences (
    vacation_id,
    employee_id,
    employee_name,
    start_date,
    end_date,
    type,
    reason,
    notes,
    user_id
) VALUES (
    'test-complete-setup-' || gen_random_uuid()::text,
    'test-employee-' || gen_random_uuid()::text,
    'Test Employee Name',
    '2024-01-15',
    '2024-01-20',
    'loma',
    'Test vacation reason',
    'Test vacation notes',
    auth.uid()
);

-- Step 12: Verify the test record
SELECT '=== TEST RECORD ===' as info;
SELECT 
    vacation_id, 
    employee_id,
    employee_name,
    type, 
    reason,
    notes,
    start_date, 
    end_date
FROM vacation_absences 
WHERE vacation_id LIKE 'test-complete-setup-%';

-- Step 13: Test ON CONFLICT functionality
INSERT INTO vacation_absences (
    vacation_id,
    employee_id,
    employee_name,
    start_date,
    end_date,
    type,
    reason,
    notes,
    user_id
) 
SELECT 
    vacation_id,
    employee_id,
    'Updated Employee Name',
    start_date,
    end_date,
    type,
    'Updated vacation reason',
    'Updated vacation notes',
    user_id
FROM vacation_absences 
WHERE vacation_id LIKE 'test-complete-setup-%'
LIMIT 1
ON CONFLICT (vacation_id) DO UPDATE SET
    reason = EXCLUDED.reason,
    notes = EXCLUDED.notes,
    employee_name = EXCLUDED.employee_name;

-- Step 14: Verify the update worked
SELECT '=== UPDATED TEST RECORD ===' as info;
SELECT 
    vacation_id, 
    employee_id,
    employee_name,
    type, 
    reason,
    notes,
    start_date, 
    end_date
FROM vacation_absences 
WHERE vacation_id LIKE 'test-complete-setup-%';

-- Step 15: Clean up test records
DELETE FROM vacation_absences WHERE vacation_id LIKE 'test-complete-setup-%';

-- Step 16: Final verification
SELECT 
    '✅ VACATION SYSTEM SETUP COMPLETED SUCCESSFULLY!' as result,
    COUNT(*) as total_vacation_records
FROM vacation_absences; 