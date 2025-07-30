-- Check what's currently in the employees table
SELECT * FROM employees LIMIT 10;

-- Check the table structure
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'employees';

-- Count employees by category
SELECT category, COUNT(*) as count 
FROM employees 
GROUP BY category;

-- Check if any of our target employees already exist
SELECT name, category 
FROM employees 
WHERE name IN (
  'Mika Kumpulainen', 'Eetu Savunen', 'Anssi Tumelius', 'Kaarlo Kyngäs'
); 