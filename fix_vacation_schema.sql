-- 🔧 FIX VACATION_ABSENCES TABLE SCHEMA
-- Run this in Supabase SQL Editor to add missing columns

-- Check current table structure first
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'vacation_absences' 
ORDER BY ordinal_position;

-- Add missing columns if they don't exist
DO $$
BEGIN
    -- Add reason column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vacation_absences' 
        AND column_name = 'reason'
    ) THEN
        ALTER TABLE public.vacation_absences 
        ADD COLUMN reason TEXT;
        RAISE NOTICE 'Added reason column to vacation_absences';
    END IF;

    -- Add notes column if it doesn't exist  
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vacation_absences' 
        AND column_name = 'notes'
    ) THEN
        ALTER TABLE public.vacation_absences 
        ADD COLUMN notes TEXT;
        RAISE NOTICE 'Added notes column to vacation_absences';
    END IF;

    -- Add user_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vacation_absences' 
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.vacation_absences 
        ADD COLUMN user_id UUID REFERENCES auth.users(id);
        RAISE NOTICE 'Added user_id column to vacation_absences';
    END IF;
END $$;

-- Verify the final table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'vacation_absences' 
ORDER BY ordinal_position;

-- Test insert to make sure it works
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
    'test-schema-fix-123',
    'test-employee-456',
    '2024-01-15',
    '2024-01-20',
    'loma',
    'Test vacation after schema fix',
    'Test notes',
    auth.uid()
) ON CONFLICT (vacation_id) DO UPDATE SET
    reason = EXCLUDED.reason;

-- Verify the test record was inserted
SELECT * FROM vacation_absences WHERE vacation_id = 'test-schema-fix-123';

-- Clean up test record
DELETE FROM vacation_absences WHERE vacation_id = 'test-schema-fix-123';

RAISE NOTICE '✅ Vacation schema fix completed successfully!'; 