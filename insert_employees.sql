-- INSERT employees into the table with correct TEXT values
-- Based on database_schema.sql constraints:
-- category: 'ab', 'cd', 'huolto', 'sijainen'
-- type: 'vakityontekija', 'sijainen'
-- role: 'tj', 'varu1', 'varu2', etc.
-- shift_cycle: 'a', 'b', 'c', 'd', 'none'

-- A-B VUORO employees (category: 'ab')
INSERT INTO employees (id, user_id, name, category, type, role, shift_cycle) VALUES
(gen_random_uuid(), auth.uid(), 'Mika Kumpulainen', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Eetu Savunen', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Ossi Littow', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Tomi Peltoniemi', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Julius Kasurinen', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Esa Vaattovaara', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Elias Hauta-Heikkilä', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Mikko Korpela', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Miikka Ylitalo', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Henri Tyrväinen', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Morten Labba', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Eemeli Kirkkala', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Janne Haara', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Sauli Juntikka', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Jarno Haapapuro', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Juho Yliportimo', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Sami Svenn', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Arttu Örn', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Juho Keinänen', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Marko Keränen', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Arttu Lahdenperä', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Toni Hannuniemi', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Mikko Pirttimaa', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Hannu Jauhojarvi', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Vili Pahkamaa', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Jarno Ylipekkala', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Elmer Tofferi', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Tero Kallijarvi', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Robert Päivinen', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Tiina Romppanen', 'ab', 'vakityontekija', 'varu1', 'a'),
(gen_random_uuid(), auth.uid(), 'Pasi Palosaari', 'ab', 'vakityontekija', 'varu1', 'a');

-- C-D VUORO employees (category: 'cd')
INSERT INTO employees (id, user_id, name, category, type, role, shift_cycle) VALUES
(gen_random_uuid(), auth.uid(), 'Anssi Tumelius', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Janne Joensuu', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Ella-Maria Heikinmatti', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Aki Marjetta', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Veikka Tikkanen', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Viljami Pakanen', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Maria Kuronen', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Jimmy Arnberg', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Ville Seilola', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Joni Alakulppi', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Tuomo Vanhatapio', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Samuli Syvärvi', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Antti Lehto', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Mikko Tammela', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Pekka Palosaari', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Ville Ojala', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Joni Väätäinen', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Joona Rissanen', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Asko Tammela', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Eemeli Körkko', 'cd', 'vakityontekija', 'varu1', 'c'),
(gen_random_uuid(), auth.uid(), 'Niko Kymäläinen', 'cd', 'vakityontekija', 'varu1', 'c');

-- SIJAISET employees (category: 'sijainen')
INSERT INTO employees (id, user_id, name, category, type, role, shift_cycle) VALUES
(gen_random_uuid(), auth.uid(), 'Kaarlo Kyngäs', 'sijainen', 'sijainen', 'varu1', 'none'),
(gen_random_uuid(), auth.uid(), 'Manu Haukilahti', 'sijainen', 'sijainen', 'varu1', 'none'),
(gen_random_uuid(), auth.uid(), 'Noora Isokangas', 'sijainen', 'sijainen', 'varu1', 'none'),
(gen_random_uuid(), auth.uid(), 'Santtu Sieppi', 'sijainen', 'sijainen', 'varu1', 'none'),
(gen_random_uuid(), auth.uid(), 'Jussi Satta', 'sijainen', 'sijainen', 'varu1', 'none'),
(gen_random_uuid(), auth.uid(), 'Mikko Yritys', 'sijainen', 'sijainen', 'varu1', 'none'),
(gen_random_uuid(), auth.uid(), 'Toni Kortesalmi', 'sijainen', 'sijainen', 'varu1', 'none');

-- Verify the insertions
SELECT 
  name, 
  category,
  type,
  role,
  shift_cycle,
  COUNT(*) OVER (PARTITION BY category) as category_count
FROM employees 
ORDER BY category, name; 