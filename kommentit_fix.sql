-- Fix database constraints to allow kommentit category and role

-- Drop existing check constraints
ALTER TABLE public.employees DROP CONSTRAINT IF EXISTS employees_category_check;
ALTER TABLE public.employees DROP CONSTRAINT IF EXISTS employees_role_check;

-- Add new check constraints with kommentit included
ALTER TABLE public.employees ADD CONSTRAINT employees_category_check 
    CHECK (category IN ('ab', 'cd', 'huolto', 'sijainen', 'kommentit'));

ALTER TABLE public.employees ADD CONSTRAINT employees_role_check 
    CHECK (role IN ('tj', 'varu1', 'varu2', 'varu3', 'varu4', 'pasta1', 'pasta2', 'ict', 'tarvike', 'pora', 'huolto', 'kommentit'));

-- Also update week_settings and custom_professions tables to include kommentit in their constraints
ALTER TABLE public.week_settings DROP CONSTRAINT IF EXISTS week_settings_profession_check;
ALTER TABLE public.week_settings ADD CONSTRAINT week_settings_profession_check 
    CHECK (profession IN ('tj', 'varu1', 'varu2', 'varu3', 'varu4', 'pasta1', 'pasta2', 'ict', 'tarvike', 'pora', 'huolto', 'kommentit')); 