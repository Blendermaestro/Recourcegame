-- 🔥 FORCE SHARED DATA ACCESS - Run this in Supabase SQL Editor
-- This script forcibly removes restrictive policies and enables shared access

-- Step 1: Temporarily disable RLS to ensure we can make changes
SET row_security = off;

-- Step 2: FORCIBLY DROP ALL RESTRICTIVE POLICIES
DROP POLICY IF EXISTS "Users can view their own employees" ON public.employees;
DROP POLICY IF EXISTS "Users can insert their own employees" ON public.employees;
DROP POLICY IF EXISTS "Users can update their own employees" ON public.employees;
DROP POLICY IF EXISTS "Users can delete their own employees" ON public.employees;
DROP POLICY IF EXISTS "Anyone can view shared assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Anyone can insert shared assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Anyone can update shared assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Anyone can delete shared assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Users can view their own settings" ON public.week_settings;
DROP POLICY IF EXISTS "Users can insert their own settings" ON public.week_settings;
DROP POLICY IF EXISTS "Users can update their own settings" ON public.week_settings;
DROP POLICY IF EXISTS "Users can delete their own settings" ON public.week_settings;
DROP POLICY IF EXISTS "Users can view their own custom professions" ON public.custom_professions;
DROP POLICY IF EXISTS "Users can insert their own custom professions" ON public.custom_professions;
DROP POLICY IF EXISTS "Users can update their own custom professions" ON public.custom_professions;
DROP POLICY IF EXISTS "Users can delete their own custom professions" ON public.custom_professions;

-- Also drop any policies with the shared names in case they exist
DROP POLICY IF EXISTS "Allow all users to view all employees" ON public.employees;
DROP POLICY IF EXISTS "Allow all users to insert employees" ON public.employees;
DROP POLICY IF EXISTS "Allow all users to update employees" ON public.employees;
DROP POLICY IF EXISTS "Allow all users to delete employees" ON public.employees;
DROP POLICY IF EXISTS "Allow all users to view all assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Allow all users to insert assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Allow all users to update assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Allow all users to delete assignments" ON public.work_assignments;

-- Step 3: CREATE SHARED ACCESS POLICIES FOR EMPLOYEES
CREATE POLICY "Shared employees - SELECT"
ON public.employees FOR SELECT
USING (true);

CREATE POLICY "Shared employees - INSERT"
ON public.employees FOR INSERT
WITH CHECK (true);

CREATE POLICY "Shared employees - UPDATE"
ON public.employees FOR UPDATE
USING (true);

CREATE POLICY "Shared employees - DELETE"
ON public.employees FOR DELETE
USING (true);

-- Step 4: CREATE SHARED ACCESS POLICIES FOR ASSIGNMENTS
CREATE POLICY "Shared assignments - SELECT"
ON public.work_assignments FOR SELECT
USING (true);

CREATE POLICY "Shared assignments - INSERT"
ON public.work_assignments FOR INSERT
WITH CHECK (true);

CREATE POLICY "Shared assignments - UPDATE"
ON public.work_assignments FOR UPDATE
USING (true);

CREATE POLICY "Shared assignments - DELETE"
ON public.work_assignments FOR DELETE
USING (true);

-- Step 5: CREATE SHARED ACCESS POLICIES FOR WEEK SETTINGS
CREATE POLICY "Shared settings - SELECT"
ON public.week_settings FOR SELECT
USING (true);

CREATE POLICY "Shared settings - INSERT"
ON public.week_settings FOR INSERT
WITH CHECK (true);

CREATE POLICY "Shared settings - UPDATE"
ON public.week_settings FOR UPDATE
USING (true);

CREATE POLICY "Shared settings - DELETE"
ON public.week_settings FOR DELETE
USING (true);

-- Step 6: CREATE SHARED ACCESS POLICIES FOR CUSTOM PROFESSIONS
CREATE POLICY "Shared professions - SELECT"
ON public.custom_professions FOR SELECT
USING (true);

CREATE POLICY "Shared professions - INSERT"
ON public.custom_professions FOR INSERT
WITH CHECK (true);

CREATE POLICY "Shared professions - UPDATE"
ON public.custom_professions FOR UPDATE
USING (true);

CREATE POLICY "Shared professions - DELETE"
ON public.custom_professions FOR DELETE
USING (true);

-- Step 7: Re-enable RLS
SET row_security = on;

-- Step 8: Verify the policies are correctly set
SELECT 
    tablename, 
    policyname, 
    permissive, 
    cmd,
    qual
FROM pg_policies 
WHERE tablename IN ('employees', 'work_assignments', 'week_settings', 'custom_professions')
ORDER BY tablename, cmd;

-- Step 9: Fix any employees with NULL user_id (they won't show up otherwise)
UPDATE employees 
SET user_id = (SELECT id FROM auth.users LIMIT 1)
WHERE user_id IS NULL;

-- Done! All users should now be able to see and edit the same data. 