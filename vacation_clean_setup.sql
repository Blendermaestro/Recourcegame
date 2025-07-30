-- 🔧 VACATION CLEAN SETUP - Handles existing policies safely
-- Run this in Supabase SQL Editor to ensure vacation system works

-- Step 1: Check current table structure
SELECT 'Current vacation_absences columns:' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'vacation_absences' 
ORDER BY ordinal_position;

-- Step 2: Safely add missing columns (if they don't exist)
DO $$
BEGIN
    -- Add reason column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vacation_absences' AND column_name = 'reason'
    ) THEN
        ALTER TABLE public.vacation_absences ADD COLUMN reason TEXT;
        RAISE NOTICE '✅ Added reason column';
    ELSE
        RAISE NOTICE 'ℹ️ reason column already exists';
    END IF;

    -- Add notes column if it doesn't exist  
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vacation_absences' AND column_name = 'notes'
    ) THEN
        ALTER TABLE public.vacation_absences ADD COLUMN notes TEXT;
        RAISE NOTICE '✅ Added notes column';
    ELSE
        RAISE NOTICE 'ℹ️ notes column already exists';
    END IF;

    -- Add user_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vacation_absences' AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.vacation_absences ADD COLUMN user_id UUID REFERENCES auth.users(id);
        RAISE NOTICE '✅ Added user_id column';
    ELSE
        RAISE NOTICE 'ℹ️ user_id column already exists';
    END IF;
END $$;

-- Step 3: Enable RLS (safe if already enabled)
ALTER TABLE public.vacation_absences ENABLE ROW LEVEL SECURITY;

-- Step 4: Clean up and recreate all policies (safe approach)
DO $$
BEGIN
    -- Drop all existing policies
    DROP POLICY IF EXISTS "Users can view their own vacation absences" ON public.vacation_absences;
    DROP POLICY IF EXISTS "Users can insert their own vacation absences" ON public.vacation_absences;
    DROP POLICY IF EXISTS "Users can update their own vacation absences" ON public.vacation_absences;
    DROP POLICY IF EXISTS "Users can delete their own vacation absences" ON public.vacation_absences;
    DROP POLICY IF EXISTS "Shared vacation absences - SELECT" ON public.vacation_absences;
    DROP POLICY IF EXISTS "Shared vacation absences - INSERT" ON public.vacation_absences;
    DROP POLICY IF EXISTS "Shared vacation absences - UPDATE" ON public.vacation_absences;
    DROP POLICY IF EXISTS "Shared vacation absences - DELETE" ON public.vacation_absences;
    
    RAISE NOTICE '🧹 Cleaned up existing policies';
END $$;

-- Step 5: Create fresh shared access policies
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

-- Step 6: Verify final table structure
SELECT 'Final vacation_absences structure:' as info;
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'vacation_absences' 
ORDER BY ordinal_position;

-- Step 7: Verify policies
SELECT 'Current policies:' as info;
SELECT policyname, cmd, permissive
FROM pg_policies 
WHERE tablename = 'vacation_absences';

-- Step 8: Test insert (this should work now)
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
    'test-final-' || gen_random_uuid()::text,
    'test-employee-' || gen_random_uuid()::text,
    '2024-01-15',
    '2024-01-20',
    'loma',
    'Test vacation - clean setup',
    'Test notes',
    auth.uid()
) ON CONFLICT (vacation_id) DO NOTHING;

-- Step 9: Show test data (should show at least one record)
SELECT 'Test records in vacation_absences:' as info;
SELECT vacation_id, employee_id, type, reason, start_date, end_date
FROM vacation_absences 
WHERE vacation_id LIKE 'test-%'
ORDER BY vacation_id DESC
LIMIT 3;

-- Step 10: Clean up test records
DELETE FROM vacation_absences WHERE vacation_id LIKE 'test-%';

SELECT '✅ Vacation system setup completed successfully!' as result; 