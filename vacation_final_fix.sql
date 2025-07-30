-- 🔧 VACATION FINAL FIX - Fixes ALL constraint issues
-- This is getting ridiculous, let's just fix everything at once

-- Step 1: Add missing columns
ALTER TABLE public.vacation_absences 
ADD COLUMN IF NOT EXISTS reason TEXT,
ADD COLUMN IF NOT EXISTS notes TEXT,
ADD COLUMN IF NOT EXISTS user_id UUID,
ADD COLUMN IF NOT EXISTS employee_name TEXT;

-- Step 2: Drop the fucking check constraint that's blocking 'loma'
ALTER TABLE public.vacation_absences 
DROP CONSTRAINT IF EXISTS vacation_absences_type_check;

-- Step 3: Add the correct check constraint
ALTER TABLE public.vacation_absences 
ADD CONSTRAINT vacation_absences_type_check 
CHECK (type IN ('loma', 'poissaolo'));

-- Step 4: Make employee_name nullable
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vacation_absences' 
        AND column_name = 'employee_name'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.vacation_absences ALTER COLUMN employee_name DROP NOT NULL;
    END IF;
END $$;

-- Step 5: Add unique constraint properly
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'vacation_absences_vacation_id_unique'
    ) THEN
        ALTER TABLE public.vacation_absences 
        ADD CONSTRAINT vacation_absences_vacation_id_unique 
        UNIQUE (vacation_id);
    END IF;
END $$;

-- Step 6: Enable RLS and create policies
ALTER TABLE public.vacation_absences ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies
DROP POLICY IF EXISTS "Users can view their own vacation absences" ON public.vacation_absences;
DROP POLICY IF EXISTS "Users can insert their own vacation absences" ON public.vacation_absences;
DROP POLICY IF EXISTS "Users can update their own vacation absences" ON public.vacation_absences;
DROP POLICY IF EXISTS "Users can delete their own vacation absences" ON public.vacation_absences;
DROP POLICY IF EXISTS "Shared vacation absences - SELECT" ON public.vacation_absences;
DROP POLICY IF EXISTS "Shared vacation absences - INSERT" ON public.vacation_absences;
DROP POLICY IF EXISTS "Shared vacation absences - UPDATE" ON public.vacation_absences;
DROP POLICY IF EXISTS "Shared vacation absences - DELETE" ON public.vacation_absences;

-- Create shared policies
CREATE POLICY "Shared vacation absences - SELECT" ON public.vacation_absences FOR SELECT USING (true);
CREATE POLICY "Shared vacation absences - INSERT" ON public.vacation_absences FOR INSERT WITH CHECK (true);
CREATE POLICY "Shared vacation absences - UPDATE" ON public.vacation_absences FOR UPDATE USING (true);
CREATE POLICY "Shared vacation absences - DELETE" ON public.vacation_absences FOR DELETE USING (true);

-- Step 7: Test that 'loma' works now
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
    'test-final-loma-123',
    'test-employee-456',
    'Test Employee',
    '2024-01-15',
    '2024-01-20',
    'loma',
    'Test loma reason',
    'Test notes',
    auth.uid()
);

-- Verify it worked
SELECT 'LOMA TEST WORKED!' as result, type, reason FROM vacation_absences WHERE vacation_id = 'test-final-loma-123';

-- Test poissaolo too
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
    'test-final-poissaolo-123',
    'test-employee-789',
    'Test Employee 2',
    '2024-02-15',
    '2024-02-20',
    'poissaolo',
    'Test poissaolo reason',
    'Test notes',
    auth.uid()
);

-- Verify poissaolo worked too
SELECT 'POISSAOLO TEST WORKED!' as result, type, reason FROM vacation_absences WHERE vacation_id = 'test-final-poissaolo-123';

-- Clean up test records
DELETE FROM vacation_absences WHERE vacation_id IN ('test-final-loma-123', 'test-final-poissaolo-123');

SELECT '✅ FINAL FIX COMPLETED - Both loma and poissaolo should work now!' as final_result; 