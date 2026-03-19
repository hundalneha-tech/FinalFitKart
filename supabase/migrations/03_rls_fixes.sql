-- FitKart RLS Fixes
-- Run after 01_schema.sql and 02_seed_data.sql

-- Fix profiles trigger to handle OAuth users (Google/Apple)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(
      NEW.raw_user_meta_data->>'full_name',
      NEW.raw_user_meta_data->>'name',
      NEW.raw_user_meta_data->>'user_name',
      split_part(NEW.email,'@',1)
    )
  )
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    email = EXCLUDED.email;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Backfill missing profiles for existing OAuth users
INSERT INTO public.profiles (id, email, name)
SELECT 
  u.id,
  u.email,
  COALESCE(
    u.raw_user_meta_data->>'full_name',
    u.raw_user_meta_data->>'name',
    split_part(u.email,'@',1)
  )
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- Allow admin dashboard to read all profiles
DROP POLICY IF EXISTS "profiles_own_read" ON public.profiles;
DROP POLICY IF EXISTS "profiles_public_read" ON public.profiles;

CREATE POLICY "profiles_own_read" ON public.profiles 
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "profiles_all_read" ON public.profiles 
  FOR SELECT USING (auth.role() = 'authenticated');

-- Allow admin dashboard to read all wallets
DROP POLICY IF EXISTS "wallets_select" ON public.wallets;
CREATE POLICY "wallets_own_select" ON public.wallets
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "wallets_all_read" ON public.wallets
  FOR SELECT USING (auth.role() = 'authenticated');
