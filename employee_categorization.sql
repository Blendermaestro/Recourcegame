-- SQL script to properly categorize employees in Supabase
-- Run this in your Supabase SQL Editor

-- A-B VUORO employees (vakityontekija category)
UPDATE employees SET category = 'vakityontekija' WHERE name IN (
  'Mika Kumpulainen',
  'Eetu Savunen',
  'Ossi Littow',
  'Tomi Peltoniemi', 
  'Julius Kasurinen',
  'Esa Vaattovaara',
  'Elias Hauta-Heikkilä',
  'Mikko Korpela',
  'Miikka Ylitalo',
  'Henri Tyrväinen',
  'Morten Labba',
  'Eemeli Kirkkala',
  'Janne Haara',
  'Sauli Juntikka',
  'Jarno Haapapuro',
  'Juho Yliportimo',
  'Sami Svenn',
  'Arttu Örn',
  'Juho Keinänen',
  'Marko Keränen',
  'Arttu Lahdenperä',
  'Toni Hannuniemi',
  'Mikko Pirttimaa',
  'Hannu Jauhojarvi',
  'Vili Pahkamaa',
  'Jarno Ylipekkala',
  'Elmer Tofferi',
  'Tero Kallijarvi',
  'Robert Päivinen',
  'Tiina Romppanen',
  'Pasi Palosaari'
);

-- C-D VUORO employees (cdVuorot category)
UPDATE employees SET category = 'cdVuorot' WHERE name IN (
  'Anssi Tumelius',
  'Janne Joensuu',
  'Ella-Maria Heikinmatti',
  'Aki Marjetta',
  'Veikka Tikkanen',
  'Viljami Pakanen',
  'Maria Kuronen',
  'Jimmy Arnberg',
  'Ville Seilola',
  'Joni Alakulppi',
  'Tuomo Vanhatapio',
  'Samuli Syvärvi',
  'Antti Lehto',
  'Mikko Tammela',
  'Pekka Palosaari',
  'Ville Ojala',
  'Joni Väätäinen',
  'Joona Rissanen',
  'Asko Tammela',
  'Eemeli Körkko',
  'Niko Kymäläinen'
);

-- SIJAISET employees (sijaiset category)
UPDATE employees SET category = 'sijaiset' WHERE name IN (
  'Kaarlo Kyngäs',
  'Manu Haukilahti', 
  'Noora Isokangas'
);

-- Others that might need categorization (you can adjust these as needed)
-- These appear to have no clear category in the list
UPDATE employees SET category = 'sijaiset' WHERE name IN (
  'Santtu Sieppi',
  'Jussi Satta',
  'Mikko Yritys',
  'Toni Kortesalmi'
);

-- Verify the changes
SELECT name, category, COUNT(*) OVER (PARTITION BY category) as category_count
FROM employees 
WHERE name IN (
  'Mika Kumpulainen', 'Eetu Savunen', 'Ossi Littow', 'Tomi Peltoniemi', 'Julius Kasurinen',
  'Esa Vaattovaara', 'Elias Hauta-Heikkilä', 'Mikko Korpela', 'Miikka Ylitalo', 'Henri Tyrväinen',
  'Morten Labba', 'Eemeli Kirkkala', 'Janne Haara', 'Sauli Juntikka', 'Jarno Haapapuro',
  'Juho Yliportimo', 'Sami Svenn', 'Arttu Örn', 'Juho Keinänen', 'Marko Keränen',
  'Arttu Lahdenperä', 'Toni Hannuniemi', 'Mikko Pirttimaa', 'Hannu Jauhojarvi', 'Vili Pahkamaa',
  'Jarno Ylipekkala', 'Elmer Tofferi', 'Tero Kallijarvi', 'Robert Päivinen', 'Tiina Romppanen',
  'Pasi Palosaari', 'Anssi Tumelius', 'Janne Joensuu', 'Ella-Maria Heikinmatti', 'Aki Marjetta',
  'Veikka Tikkanen', 'Viljami Pakanen', 'Maria Kuronen', 'Jimmy Arnberg', 'Ville Seilola',
  'Joni Alakulppi', 'Tuomo Vanhatapio', 'Samuli Syvärvi', 'Antti Lehto', 'Mikko Tammela',
  'Pekka Palosaari', 'Ville Ojala', 'Joni Väätäinen', 'Joona Rissanen', 'Asko Tammela',
  'Eemeli Körkko', 'Niko Kymäläinen', 'Kaarlo Kyngäs', 'Manu Haukilahti', 'Noora Isokangas',
  'Santtu Sieppi', 'Jussi Satta', 'Mikko Yritys', 'Toni Kortesalmi'
)
ORDER BY category, name; 