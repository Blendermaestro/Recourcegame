-- 🔥 VACATION SHARED ACCESS - Complete table setup and policies
-- Run this in Supabase SQL Editor to fix schema and enable shared vacation access

-- Step 1: Ensure vacation_absences table exists with correct structure
CREATE TABLE IF NOT EXISTS public.vacation_absences (
    id BIGSERIAL PRIMARY KEY,
    vacation_id UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('loma', 'poissaolo')),
    reason TEXT,
    notes TEXT,
    user_id UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 2: Add missing columns if they don't exist (safe operation)
DO $$
BEGIN
    -- Add reason column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vacation_absences' AND column_name = 'reason'
    ) THEN
        ALTER TABLE public.vacation_absences ADD COLUMN reason TEXT;
    END IF;

    -- Add notes column if it doesn't exist  
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vacation_absences' AND column_name = 'notes'
    ) THEN
        ALTER TABLE public.vacation_absences ADD COLUMN notes TEXT;
    END IF;

    -- Add user_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vacation_absences' AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.vacation_absences ADD COLUMN user_id UUID REFERENCES auth.users(id);
    END IF;
END $$;

-- Step 3: Enable Row Level Security
ALTER TABLE public.vacation_absences ENABLE ROW LEVEL SECURITY;

-- Step 4: Update vacation_absences policies for shared access (PRESERVES ALL DATA)
DROP POLICY IF EXISTS "Users can view their own vacation absences" ON public.vacation_absences;
CREATE POLICY "Shared vacation absences - SELECT" 
ON public.vacation_absences FOR SELECT 
USING (true);

DROP POLICY IF EXISTS "Users can insert their own vacation absences" ON public.vacation_absences;  
CREATE POLICY "Shared vacation absences - INSERT" 
ON public.vacation_absences FOR INSERT 
WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update their own vacation absences" ON public.vacation_absences;
CREATE POLICY "Shared vacation absences - UPDATE" 
ON public.vacation_absences FOR UPDATE 
USING (true);

DROP POLICY IF EXISTS "Users can delete their own vacation absences" ON public.vacation_absences;
CREATE POLICY "Shared vacation absences - DELETE" 
ON public.vacation_absences FOR DELETE 
USING (true);

-- Step 2: Verify existing data is preserved
SELECT 
    COUNT(*) as total_vacations,
    COUNT(DISTINCT employee_id) as employees_with_vacations
FROM vacation_absences;

-- Step 3: Show sample data (if any exists)
SELECT 
    vacation_id,
    employee_id, 
    type,
    start_date,
    end_date,
    reason
FROM vacation_absences 
ORDER BY start_date DESC 
LIMIT 5; 