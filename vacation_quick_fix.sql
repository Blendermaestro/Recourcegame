-- 🔧 VACATION QUICK FIX - Simple column addition without complex queries
-- Run this in Supabase SQL Editor to quickly fix vacation system

-- Add missing columns safely
ALTER TABLE public.vacation_absences 
ADD COLUMN IF NOT EXISTS reason TEXT,
ADD COLUMN IF NOT EXISTS notes TEXT,
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS employee_name TEXT;

-- Make employee_name nullable if it exists and is NOT NULL
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

-- Add unique constraint on vacation_id if it doesn't exist
ALTER TABLE public.vacation_absences 
ADD CONSTRAINT IF NOT EXISTS vacation_absences_vacation_id_unique 
UNIQUE (vacation_id);

-- Enable Row Level Security
ALTER TABLE public.vacation_absences ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own vacation absences" ON public.vacation_absences;
DROP POLICY IF EXISTS "Users can insert their own vacation absences" ON public.vacation_absences;
DROP POLICY IF EXISTS "Users can update their own vacation absences" ON public.vacation_absences;
DROP POLICY IF EXISTS "Users can delete their own vacation absences" ON public.vacation_absences;
DROP POLICY IF EXISTS "Shared vacation absences - SELECT" ON public.vacation_absences;
DROP POLICY IF EXISTS "Shared vacation absences - INSERT" ON public.vacation_absences;
DROP POLICY IF EXISTS "Shared vacation absences - UPDATE" ON public.vacation_absences;
DROP POLICY IF EXISTS "Shared vacation absences - DELETE" ON public.vacation_absences;

-- Create shared access policies
CREATE POLICY "Shared vacation absences - SELECT" 
ON public.vacation_absences FOR SELECT USING (true);

CREATE POLICY "Shared vacation absences - INSERT" 
ON public.vacation_absences FOR INSERT WITH CHECK (true);

CREATE POLICY "Shared vacation absences - UPDATE" 
ON public.vacation_absences FOR UPDATE USING (true);

CREATE POLICY "Shared vacation absences - DELETE" 
ON public.vacation_absences FOR DELETE USING (true);

-- Test insert
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
    'test-quick-fix-123',
    'test-employee-456',
    'Test Employee',
    '2024-01-15',
    '2024-01-20',
    'loma',
    'Test reason',
    'Test notes',
    auth.uid()
) ON CONFLICT (vacation_id) DO UPDATE SET
    reason = EXCLUDED.reason;

-- Verify and clean up
SELECT 'Test worked!' as result, vacation_id, employee_name, reason 
FROM vacation_absences 
WHERE vacation_id = 'test-quick-fix-123';

DELETE FROM vacation_absences WHERE vacation_id = 'test-quick-fix-123';

SELECT '✅ Quick fix completed!' as final_result; 