-- Enable shared access to all data across users
-- Remove user-specific Row Level Security policies

-- EMPLOYEES TABLE - Allow all users to access all employee data
DROP POLICY IF EXISTS "Users can view their own employees" ON public.employees;
DROP POLICY IF EXISTS "Users can insert their own employees" ON public.employees;
DROP POLICY IF EXISTS "Users can update their own employees" ON public.employees;
DROP POLICY IF EXISTS "Users can delete their own employees" ON public.employees;

-- Create shared access policies for employees
CREATE POLICY "Allow all users to view all employees" 
ON public.employees FOR SELECT 
USING (true);

CREATE POLICY "Allow all users to insert employees" 
ON public.employees FOR INSERT 
WITH CHECK (true);

CREATE POLICY "Allow all users to update employees" 
ON public.employees FOR UPDATE 
USING (true);

CREATE POLICY "Allow all users to delete employees" 
ON public.employees FOR DELETE 
USING (true);

-- WORK ASSIGNMENTS TABLE - Allow all users to access all assignment data
DROP POLICY IF EXISTS "Users can view their own assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Users can insert their own assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Users can update their own assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Users can delete their own assignments" ON public.work_assignments;

-- Create shared access policies for work assignments
CREATE POLICY "Allow all users to view all assignments" 
ON public.work_assignments FOR SELECT 
USING (true);

CREATE POLICY "Allow all users to insert assignments" 
ON public.work_assignments FOR INSERT 
WITH CHECK (true);

CREATE POLICY "Allow all users to update assignments" 
ON public.work_assignments FOR UPDATE 
USING (true);

CREATE POLICY "Allow all users to delete assignments" 
ON public.work_assignments FOR DELETE 
USING (true);

-- WEEK SETTINGS TABLE - Allow all users to access all settings
DROP POLICY IF EXISTS "Users can view their own settings" ON public.week_settings;
DROP POLICY IF EXISTS "Users can insert their own settings" ON public.week_settings;
DROP POLICY IF EXISTS "Users can update their own settings" ON public.week_settings;
DROP POLICY IF EXISTS "Users can delete their own settings" ON public.week_settings;

-- Create shared access policies for week settings
CREATE POLICY "Allow all users to view all settings" 
ON public.week_settings FOR SELECT 
USING (true);

CREATE POLICY "Allow all users to insert settings" 
ON public.week_settings FOR INSERT 
WITH CHECK (true);

CREATE POLICY "Allow all users to update settings" 
ON public.week_settings FOR UPDATE 
USING (true);

CREATE POLICY "Allow all users to delete settings" 
ON public.week_settings FOR DELETE 
USING (true); 