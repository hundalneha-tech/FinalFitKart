-- ============================================================
-- FitKart — Seed Data
-- Run AFTER 01_schema_fixed.sql in Supabase SQL Editor
-- ============================================================

-- Perks / Vouchers
INSERT INTO public.perks (brand, category, description, discount_label, coin_price, is_featured, is_active) VALUES
('Myntra',      'Fashion',       'Fashion & Lifestyle',        '₹500 OFF',    450, TRUE,  TRUE),
('Starbucks',   'Food',          'Free beverage up to ₹350',   'Free Drink',  150, TRUE,  TRUE),
('Zomato',      'Food',          'Food Delivery',              '₹200 OFF',    180, FALSE, TRUE),
('PVR Cinemas', 'Entertainment', 'Entertainment',              'Buy 1 Get 1', 300, FALSE, TRUE),
('Nykaa',       'Beauty',        'Beauty & Care',              '25% OFF',     220, FALSE, TRUE),
('Nike Store',  'Fashion',       'Extra discount on footwear', '20% OFF',     500, TRUE,  TRUE),
('Amazon',      'Fashion',       'Online Shopping',            '10% OFF',     400, FALSE, TRUE),
('Adidas',      'Fashion',       'Sports & Fashion',           '20% OFF',     350, FALSE, TRUE);

-- Challenges
INSERT INTO public.challenges (title, description, type, target_value, reward_coins, is_global, start_time, end_time) VALUES
('Weekend Warrior',  'Walk 50,000 steps this weekend',          'steps',    50000,  500,  FALSE, NOW(), NOW() + INTERVAL '2 days'),
('Morning Streak',   'Achieve your step goal 7 days in a row',  'streak',   7,      300,  FALSE, NOW(), NOW() + INTERVAL '5 days'),
('Walk to the Moon', 'Global community walks 384,400 km total', 'distance', 384400, 1000, TRUE,  NOW(), NULL),
('Calorie Crusher',  'Burn 3,000 calories this week',           'calories', 3000,   200,  FALSE, NOW(), NOW() + INTERVAL '3 days');

-- Causes (donation targets)
INSERT INTO public.causes (title, description, ngo_name, ngo_city, page_url, target_coins) VALUES
('Stray Animals Fund',     'Feed, vaccinate and rehome stray dogs and cats across India', 'Animal Aid Unlimited', 'Udaipur',   'https://fitkart.club/donate-stray-animals/', 50000000),
('Clean Water Initiative', 'Provide clean drinking water to rural communities',           'Water.org India',      'Mumbai',    '', 100000000),
('Plant a Forest',         'Plant trees across degraded forest land in India',            'Green Yatra',          'Bengaluru', '', 200000000);

-- App settings (coin economy)
-- Already seeded by schema, but update here if needed:
UPDATE public.app_settings SET value = '1.00' WHERE key = 'coins_per_100_steps';
UPDATE public.app_settings SET value = '0.33' WHERE key = 'inr_per_coin';

SELECT 'Seed data inserted successfully!' AS status;
