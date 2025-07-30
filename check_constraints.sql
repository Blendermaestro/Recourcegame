-- Check the actual constraints on the employees table
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'employees'::regclass;

-- Check what enum values are actually allowed for category
SELECT 
    t.typname as enum_name,
    e.enumlabel as enum_value,
    e.enumsortorder as sort_order
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid 
WHERE t.typname LIKE '%category%' OR t.typname LIKE '%employee%';

-- Check the table structure to see actual column types
\d employees; 