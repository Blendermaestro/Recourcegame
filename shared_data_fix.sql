-- 🔥 SHARED DATA FIX - Convert per-user data to shared data for multi-user sync

-- 1. Create new shared week lock states table
CREATE TABLE IF NOT EXISTS public.week_lock_states (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    week_number INTEGER NOT NULL CHECK (week_number >= 1 AND week_number <= 52),
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    locked_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    locked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(week_number)
);

-- 2. Create new shared week settings table (without user_id)
CREATE TABLE IF NOT EXISTS public.shared_week_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    week_number INTEGER NOT NULL CHECK (week_number >= 1 AND week_number <= 52),
    shift_type TEXT NOT NULL CHECK (shift_type IN ('day', 'night')),
    profession TEXT NOT NULL CHECK (profession IN ('tj', 'varu1', 'varu2', 'varu3', 'varu4', 'pasta1', 'pasta2', 'ict', 'tarvike', 'pora', 'huolto', 'kommentit')),
    is_visible BOOLEAN DEFAULT TRUE,
    row_count INTEGER DEFAULT 1 CHECK (row_count >= 1 AND row_count <= 4),
    last_updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(week_number, shift_type, profession)
);

-- 3. Create new shared custom professions table (without user_id)
CREATE TABLE IF NOT EXISTS public.shared_custom_professions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    profession_id TEXT NOT NULL, -- matches CustomProfession.id
    name TEXT NOT NULL,
    short_name TEXT NOT NULL,
    default_day_visible BOOLEAN DEFAULT TRUE,
    default_night_visible BOOLEAN DEFAULT TRUE,
    default_rows INTEGER DEFAULT 1 CHECK (default_rows >= 1 AND default_rows <= 4),
    last_updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(profession_id)
);

-- 4. Migrate existing data from per-user tables to shared tables
-- (Take data from the first user found for each setting)

-- Migrate week settings
INSERT INTO public.shared_week_settings (week_number, shift_type, profession, is_visible, row_count, last_updated_by, created_at)
SELECT DISTINCT ON (week_number, shift_type, profession) 
    week_number, shift_type, profession, is_visible, row_count, user_id, created_at
FROM public.week_settings
ORDER BY week_number, shift_type, profession, created_at ASC
ON CONFLICT (week_number, shift_type, profession) DO NOTHING;

-- Migrate custom professions 
INSERT INTO public.shared_custom_professions (profession_id, name, short_name, default_day_visible, default_night_visible, default_rows, last_updated_by, created_at)
SELECT DISTINCT ON (profession_id)
    profession_id, name, short_name, default_day_visible, default_night_visible, default_rows, user_id, created_at
FROM public.custom_professions
ORDER BY profession_id, created_at ASC
ON CONFLICT (profession_id) DO NOTHING;

-- 5. Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_week_lock_states_week ON public.week_lock_states(week_number);
CREATE INDEX IF NOT EXISTS idx_shared_week_settings_week ON public.shared_week_settings(week_number);
CREATE INDEX IF NOT EXISTS idx_shared_week_settings_profession ON public.shared_week_settings(profession);
CREATE INDEX IF NOT EXISTS idx_shared_custom_professions_id ON public.shared_custom_professions(profession_id);

-- 6. Enable Row Level Security (but allow all authenticated users to read/write shared data)
ALTER TABLE public.week_lock_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shared_week_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shared_custom_professions ENABLE ROW LEVEL SECURITY;

-- 7. Create RLS policies for shared access
-- Week lock states - all authenticated users can read/write
CREATE POLICY "week_lock_states_select" ON public.week_lock_states FOR SELECT TO authenticated USING (true);
CREATE POLICY "week_lock_states_insert" ON public.week_lock_states FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "week_lock_states_update" ON public.week_lock_states FOR UPDATE TO authenticated USING (true);
CREATE POLICY "week_lock_states_delete" ON public.week_lock_states FOR DELETE TO authenticated USING (true);

-- Shared week settings - all authenticated users can read/write
CREATE POLICY "shared_week_settings_select" ON public.shared_week_settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "shared_week_settings_insert" ON public.shared_week_settings FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "shared_week_settings_update" ON public.shared_week_settings FOR UPDATE TO authenticated USING (true);
CREATE POLICY "shared_week_settings_delete" ON public.shared_week_settings FOR DELETE TO authenticated USING (true);

-- Shared custom professions - all authenticated users can read/write
CREATE POLICY "shared_custom_professions_select" ON public.shared_custom_professions FOR SELECT TO authenticated USING (true);
CREATE POLICY "shared_custom_professions_insert" ON public.shared_custom_professions FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "shared_custom_professions_update" ON public.shared_custom_professions FOR UPDATE TO authenticated USING (true);
CREATE POLICY "shared_custom_professions_delete" ON public.shared_custom_professions FOR DELETE TO authenticated USING (true);

-- 8. Add triggers for updating timestamps
CREATE TRIGGER update_week_lock_states_updated_at BEFORE UPDATE ON public.week_lock_states FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER update_shared_week_settings_updated_at BEFORE UPDATE ON public.shared_week_settings FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER update_shared_custom_professions_updated_at BEFORE UPDATE ON public.shared_custom_professions FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- 9. Optional: Drop old per-user tables after confirming migration worked
-- UNCOMMENT THESE LINES AFTER TESTING:
-- DROP TABLE IF EXISTS public.week_settings;
-- DROP TABLE IF EXISTS public.custom_professions; 