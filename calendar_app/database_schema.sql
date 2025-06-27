-- Calendar App Database Schema for Supabase
-- This creates all the necessary tables for the work schedule calendar app

-- Create employees table
CREATE TABLE IF NOT EXISTS public.employees (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('ab', 'cd', 'huolto', 'sijainen')),
    type TEXT NOT NULL CHECK (type IN ('vakityontekija', 'sijainen')),
    role TEXT NOT NULL CHECK (role IN ('tj', 'varu1', 'varu2', 'varu3', 'varu4', 'pasta1', 'pasta2', 'ict', 'tarvike', 'pora', 'huolto')),
    shift_cycle TEXT NOT NULL CHECK (shift_cycle IN ('a', 'b', 'c', 'd', 'none')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create work assignments table
CREATE TABLE IF NOT EXISTS public.work_assignments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    employee_id UUID REFERENCES public.employees(id) ON DELETE CASCADE,
    week_number INTEGER NOT NULL CHECK (week_number >= 1 AND week_number <= 52),
    day_index INTEGER NOT NULL CHECK (day_index >= 0 AND day_index <= 6),
    shift_type TEXT NOT NULL CHECK (shift_type IN ('day', 'night')),
    lane INTEGER NOT NULL CHECK (lane >= 0),
    shift_title TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, week_number, day_index, shift_type, lane)
);

-- Create week settings table for profession configurations
CREATE TABLE IF NOT EXISTS public.week_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    week_number INTEGER NOT NULL CHECK (week_number >= 1 AND week_number <= 52),
    shift_type TEXT NOT NULL CHECK (shift_type IN ('day', 'night')),
    profession TEXT NOT NULL CHECK (profession IN ('tj', 'varu1', 'varu2', 'varu3', 'varu4', 'pasta1', 'pasta2', 'ict', 'tarvike', 'pora', 'huolto')),
    is_visible BOOLEAN DEFAULT TRUE,
    row_count INTEGER DEFAULT 1 CHECK (row_count >= 1 AND row_count <= 4),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, week_number, shift_type, profession)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employees_user_id ON public.employees(user_id);
CREATE INDEX IF NOT EXISTS idx_employees_category ON public.employees(category);
CREATE INDEX IF NOT EXISTS idx_work_assignments_user_id ON public.work_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_work_assignments_week ON public.work_assignments(week_number);
CREATE INDEX IF NOT EXISTS idx_work_assignments_employee ON public.work_assignments(employee_id);
CREATE INDEX IF NOT EXISTS idx_week_settings_user_id ON public.week_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_week_settings_week ON public.week_settings(week_number);

-- Function to update updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Enable Row Level Security
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.week_settings ENABLE ROW LEVEL SECURITY;

-- Row Level Security Policies for employees table
DROP POLICY IF EXISTS "Users can view their own employees" ON public.employees;
CREATE POLICY "Users can view their own employees" 
ON public.employees FOR SELECT 
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own employees" ON public.employees;
CREATE POLICY "Users can insert their own employees" 
ON public.employees FOR INSERT 
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own employees" ON public.employees;
CREATE POLICY "Users can update their own employees" 
ON public.employees FOR UPDATE 
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own employees" ON public.employees;
CREATE POLICY "Users can delete their own employees" 
ON public.employees FOR DELETE 
USING (auth.uid() = user_id);

-- Row Level Security Policies for work_assignments table
DROP POLICY IF EXISTS "Users can view their own assignments" ON public.work_assignments;
CREATE POLICY "Users can view their own assignments" 
ON public.work_assignments FOR SELECT 
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own assignments" ON public.work_assignments;
CREATE POLICY "Users can insert their own assignments" 
ON public.work_assignments FOR INSERT 
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own assignments" ON public.work_assignments;
CREATE POLICY "Users can update their own assignments" 
ON public.work_assignments FOR UPDATE 
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own assignments" ON public.work_assignments;
CREATE POLICY "Users can delete their own assignments" 
ON public.work_assignments FOR DELETE 
USING (auth.uid() = user_id);

-- Row Level Security Policies for week_settings table
DROP POLICY IF EXISTS "Users can view their own settings" ON public.week_settings;
CREATE POLICY "Users can view their own settings" 
ON public.week_settings FOR SELECT 
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own settings" ON public.week_settings;
CREATE POLICY "Users can insert their own settings" 
ON public.week_settings FOR INSERT 
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own settings" ON public.week_settings;
CREATE POLICY "Users can update their own settings" 
ON public.week_settings FOR UPDATE 
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own settings" ON public.week_settings;
CREATE POLICY "Users can delete their own settings" 
ON public.week_settings FOR DELETE 
USING (auth.uid() = user_id);

-- Create triggers for updated_at
DROP TRIGGER IF EXISTS update_employees_updated_at ON public.employees;
CREATE TRIGGER update_employees_updated_at
    BEFORE UPDATE ON public.employees
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_work_assignments_updated_at ON public.work_assignments;
CREATE TRIGGER update_work_assignments_updated_at
    BEFORE UPDATE ON public.work_assignments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_week_settings_updated_at ON public.week_settings;
CREATE TRIGGER update_week_settings_updated_at
    BEFORE UPDATE ON public.week_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default week settings for professions
-- This will be handled by the app when a user first logs in 