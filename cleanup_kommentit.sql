-- 🔥 CLEANUP KOMMENTIT - Remove all old kommentit profession entries

-- Remove kommentit from old per-user week_settings table
DELETE FROM public.week_settings 
WHERE profession = 'kommentit';

-- Remove kommentit from new shared week_settings table  
DELETE FROM public.shared_week_settings 
WHERE profession = 'kommentit';

-- Remove kommentit from custom professions tables
DELETE FROM public.custom_professions 
WHERE profession_id = 'kommentit';

DELETE FROM public.shared_custom_professions 
WHERE profession_id = 'kommentit';

-- Show how many rows were cleaned up
SELECT 
  'Cleanup complete - kommentit profession entries removed from all tables' as result; 