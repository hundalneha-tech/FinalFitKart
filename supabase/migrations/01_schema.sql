-- ============================================================
-- FitKart Club — Complete Supabase Database Schema
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";


-- ============================================================
-- 1. USERS & PROFILES
-- ============================================================

CREATE TABLE public.profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  email           TEXT UNIQUE NOT NULL,
  phone           TEXT,
  avatar_url      TEXT,
  city            TEXT,
  state           TEXT,
  date_of_birth   DATE,
  gender          TEXT CHECK (gender IN ('male','female','other','prefer_not_to_say')),
  level           TEXT DEFAULT 'Walker' CHECK (level IN ('Walker','Pro Walker','Elite','Champion')),
  level_num       INT DEFAULT 1,
  is_pro          BOOLEAN DEFAULT FALSE,
  is_suspended    BOOLEAN DEFAULT FALSE,
  suspension_reason TEXT,
  step_length_cm  INT DEFAULT 75,
  weight_kg       NUMERIC(5,2) DEFAULT 70,
  unit_system     TEXT DEFAULT 'metric' CHECK (unit_system IN ('metric','imperial')),
  accent_color    TEXT DEFAULT '#2563EB',
  notifications_enabled BOOLEAN DEFAULT TRUE,
  goal_steps      INT DEFAULT 10000,
  goal_calories   INT DEFAULT 500,
  goal_distance_km NUMERIC(6,2) DEFAULT 7,
  goal_active_minutes INT DEFAULT 30,
  referral_code   TEXT UNIQUE DEFAULT substr(md5(random()::text), 1, 8),
  referred_by     UUID REFERENCES public.profiles(id),
  device_ids      TEXT[] DEFAULT '{}',
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email,'@',1))
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ============================================================
-- 2. STEP EVENTS (Daily aggregates per user)
-- ============================================================

CREATE TABLE public.step_events (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  date            DATE NOT NULL,
  steps           INT NOT NULL DEFAULT 0,
  distance_km     NUMERIC(8,3) DEFAULT 0,
  calories        NUMERIC(8,2) DEFAULT 0,
  active_minutes  INT DEFAULT 0,
  floors          INT DEFAULT 0,
  goal_reached    BOOLEAN DEFAULT FALSE,
  coins_earned    NUMERIC(10,2) DEFAULT 0,
  inr_earned      NUMERIC(10,2) DEFAULT 0,
  source          TEXT DEFAULT 'app' CHECK (source IN ('app','health_connect','apple_health','manual')),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, date)
);

CREATE INDEX idx_step_events_user_date ON public.step_events(user_id, date DESC);
CREATE INDEX idx_step_events_date ON public.step_events(date DESC);

CREATE TRIGGER step_events_updated_at
  BEFORE UPDATE ON public.step_events
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ============================================================
-- 3. STEP BATCHES (Raw sensor data — for anti-cheat)
-- ============================================================

CREATE TABLE public.step_batches (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id             UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  session_id          UUID NOT NULL,
  device_id           TEXT NOT NULL,
  timestamp_start     TIMESTAMPTZ NOT NULL,
  timestamp_end       TIMESTAMPTZ NOT NULL,
  step_count          INT NOT NULL,
  accelerometer_rms   NUMERIC(8,4),
  lat                 NUMERIC(10,7),
  lng                 NUMERIC(10,7),
  accuracy_m          NUMERIC(8,2),
  altitude_m          NUMERIC(8,2),
  is_foreground       BOOLEAN DEFAULT TRUE,
  device_model        TEXT,
  os_version          TEXT,
  app_version         TEXT,
  checksum            TEXT,
  risk_score          NUMERIC(5,2) DEFAULT 0,
  is_valid            BOOLEAN DEFAULT TRUE,
  fraud_flags         TEXT[] DEFAULT '{}',
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_step_batches_user ON public.step_batches(user_id, created_at DESC);
CREATE INDEX idx_step_batches_session ON public.step_batches(session_id);
CREATE INDEX idx_step_batches_risk ON public.step_batches(risk_score DESC) WHERE risk_score > 30;


-- ============================================================
-- 4. WORKOUT SESSIONS
-- ============================================================

CREATE TABLE public.workout_sessions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type            TEXT NOT NULL CHECK (type IN ('walk','run','hike','cycle')),
  start_time      TIMESTAMPTZ NOT NULL,
  end_time        TIMESTAMPTZ,
  duration_secs   INT,
  steps           INT DEFAULT 0,
  distance_km     NUMERIC(8,3) DEFAULT 0,
  calories        NUMERIC(8,2) DEFAULT 0,
  avg_pace_min_km NUMERIC(6,2),
  avg_heart_rate  INT,
  route           JSONB DEFAULT '[]',   -- [{lat, lng, timestamp}]
  coins_earned    NUMERIC(10,2) DEFAULT 0,
  is_completed    BOOLEAN DEFAULT FALSE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_workout_sessions_user ON public.workout_sessions(user_id, start_time DESC);


-- ============================================================
-- 5. FKC COIN WALLET & TRANSACTIONS
-- ============================================================

CREATE TABLE public.wallets (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID UNIQUE NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  balance         NUMERIC(14,2) DEFAULT 0 CHECK (balance >= 0),
  lifetime_earned NUMERIC(14,2) DEFAULT 0,
  lifetime_spent  NUMERIC(14,2) DEFAULT 0,
  inr_value       NUMERIC(12,2) GENERATED ALWAYS AS (balance * 0.33) STORED,
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create wallet on profile creation
CREATE OR REPLACE FUNCTION public.handle_new_profile()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.wallets (user_id) VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_profile_created
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_profile();

CREATE TABLE public.coin_transactions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type            TEXT NOT NULL CHECK (type IN (
                    'EARN_STEPS','EARN_WORKOUT','EARN_CHALLENGE','EARN_REFERRAL','EARN_BONUS',
                    'SPEND_REDEEM','SPEND_DONATE','SPEND_TRANSFER',
                    'ADMIN_CREDIT','ADMIN_DEBIT','REFUND'
                  )),
  amount          NUMERIC(12,2) NOT NULL,         -- positive = credit, negative = debit
  balance_after   NUMERIC(14,2) NOT NULL,
  description     TEXT,
  ref_id          UUID,                            -- step_event_id / perk_id / challenge_id
  ref_type        TEXT,                            -- 'step_event' | 'perk' | 'challenge' | etc.
  session_ids     UUID[] DEFAULT '{}',             -- source step batches
  risk_score      NUMERIC(5,2) DEFAULT 0,
  decision        TEXT DEFAULT 'APPROVE' CHECK (decision IN ('APPROVE','REVIEW','BLOCK','SUSPEND')),
  fraud_flags     TEXT[] DEFAULT '{}',
  ip_address      INET,
  device_id       TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_coin_txn_user ON public.coin_transactions(user_id, created_at DESC);
CREATE INDEX idx_coin_txn_type ON public.coin_transactions(type, created_at DESC);
CREATE INDEX idx_coin_txn_decision ON public.coin_transactions(decision) WHERE decision != 'APPROVE';

-- Safe coin credit/debit function
CREATE OR REPLACE FUNCTION public.transact_coins(
  p_user_id     UUID,
  p_amount      NUMERIC,        -- positive = credit, negative = debit
  p_type        TEXT,
  p_description TEXT DEFAULT NULL,
  p_ref_id      UUID DEFAULT NULL,
  p_ref_type    TEXT DEFAULT NULL,
  p_risk_score  NUMERIC DEFAULT 0,
  p_decision    TEXT DEFAULT 'APPROVE',
  p_session_ids UUID[] DEFAULT '{}'
) RETURNS public.coin_transactions AS $$
DECLARE
  v_wallet   public.wallets;
  v_txn      public.coin_transactions;
BEGIN
  -- Lock wallet row
  SELECT * INTO v_wallet FROM public.wallets
  WHERE user_id = p_user_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
  END IF;

  -- Check sufficient balance for debits
  IF p_amount < 0 AND (v_wallet.balance + p_amount) < 0 THEN
    RAISE EXCEPTION 'Insufficient balance. Current: %, Requested: %', v_wallet.balance, ABS(p_amount);
  END IF;

  -- Update wallet
  UPDATE public.wallets SET
    balance         = balance + p_amount,
    lifetime_earned = CASE WHEN p_amount > 0 THEN lifetime_earned + p_amount ELSE lifetime_earned END,
    lifetime_spent  = CASE WHEN p_amount < 0 THEN lifetime_spent + ABS(p_amount) ELSE lifetime_spent END,
    updated_at      = NOW()
  WHERE user_id = p_user_id;

  -- Record transaction
  INSERT INTO public.coin_transactions (
    user_id, type, amount, balance_after, description,
    ref_id, ref_type, risk_score, decision, session_ids
  ) VALUES (
    p_user_id, p_type, p_amount, v_wallet.balance + p_amount,
    p_description, p_ref_id, p_ref_type, p_risk_score,
    p_decision, p_session_ids
  ) RETURNING * INTO v_txn;

  RETURN v_txn;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 6. PERKS & VOUCHERS
-- ============================================================

CREATE TABLE public.perks (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  brand           TEXT NOT NULL,
  category        TEXT NOT NULL CHECK (category IN ('Fashion','Food','Entertainment','Beauty','Fitness','Travel','Health','Other')),
  description     TEXT,
  discount_label  TEXT,
  coin_price      INT NOT NULL,
  inr_value       NUMERIC(10,2),
  image_url       TEXT,
  terms           TEXT,
  stock           INT,                             -- NULL = unlimited
  redeemed_count  INT DEFAULT 0,
  is_active       BOOLEAN DEFAULT TRUE,
  is_featured     BOOLEAN DEFAULT FALSE,
  valid_from      TIMESTAMPTZ DEFAULT NOW(),
  valid_until     TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.redemptions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  perk_id         UUID NOT NULL REFERENCES public.perks(id),
  coins_spent     INT NOT NULL,
  voucher_code    TEXT,
  status          TEXT DEFAULT 'pending' CHECK (status IN ('pending','active','used','expired','refunded')),
  expires_at      TIMESTAMPTZ,
  used_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_redemptions_user ON public.redemptions(user_id, created_at DESC);
CREATE INDEX idx_redemptions_perk ON public.redemptions(perk_id, created_at DESC);


-- ============================================================
-- 7. DONATIONS & CAUSES
-- ============================================================

CREATE TABLE public.causes (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title           TEXT NOT NULL,
  description     TEXT,
  ngo_name        TEXT NOT NULL,
  ngo_city        TEXT,
  image_url       TEXT,
  page_url        TEXT,
  target_coins    BIGINT NOT NULL,
  current_coins   BIGINT DEFAULT 0,
  inr_raised      NUMERIC(14,2) DEFAULT 0,
  is_active       BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.donations (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  cause_id        UUID NOT NULL REFERENCES public.causes(id),
  coins_donated   INT NOT NULL,
  inr_value       NUMERIC(10,2) NOT NULL,
  status          TEXT DEFAULT 'pending' CHECK (status IN ('pending','transferred','failed')),
  transferred_at  TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_donations_user ON public.donations(user_id, created_at DESC);
CREATE INDEX idx_donations_cause ON public.donations(cause_id, created_at DESC);

-- Auto-update cause totals on donation
CREATE OR REPLACE FUNCTION public.update_cause_totals()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.causes SET
    current_coins = current_coins + NEW.coins_donated,
    inr_raised    = inr_raised + NEW.inr_value,
    updated_at    = NOW()
  WHERE id = NEW.cause_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_donation_created
  AFTER INSERT ON public.donations
  FOR EACH ROW EXECUTE FUNCTION public.update_cause_totals();

-- Seed causes
INSERT INTO public.causes (title, description, ngo_name, ngo_city, page_url, target_coins, image_url) VALUES
('Stray Animals Fund',      'Feed, vaccinate and rehome stray dogs and cats across India', 'Animal Aid Unlimited', 'Udaipur',   'https://fitkart.club/donate-stray-animals/', 50000000,  ''),
('Clean Water Initiative',  'Provide clean drinking water to rural communities',            'Water.org India',     'Mumbai',    '', 100000000, ''),
('Plant a Forest',          'Plant trees across degraded forest land in India',             'Green Yatra',         'Bengaluru', '', 200000000, '');


-- ============================================================
-- 8. CHALLENGES
-- ============================================================

CREATE TABLE public.challenges (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title           TEXT NOT NULL,
  description     TEXT,
  type            TEXT NOT NULL CHECK (type IN ('steps','distance','calories','streak','active_minutes')),
  image_url       TEXT,
  target_value    NUMERIC(12,2) NOT NULL,
  reward_coins    INT NOT NULL DEFAULT 0,
  is_global       BOOLEAN DEFAULT FALSE,
  max_participants INT,
  participant_count INT DEFAULT 0,
  start_time      TIMESTAMPTZ NOT NULL,
  end_time        TIMESTAMPTZ,
  is_active       BOOLEAN DEFAULT TRUE,
  created_by      UUID REFERENCES public.profiles(id),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.challenge_participants (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  challenge_id    UUID NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  current_value   NUMERIC(12,2) DEFAULT 0,
  is_completed    BOOLEAN DEFAULT FALSE,
  completed_at    TIMESTAMPTZ,
  reward_claimed  BOOLEAN DEFAULT FALSE,
  joined_at       TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(challenge_id, user_id)
);

CREATE INDEX idx_challenge_parts_user ON public.challenge_participants(user_id, joined_at DESC);
CREATE INDEX idx_challenge_parts_challenge ON public.challenge_participants(challenge_id, current_value DESC);


-- ============================================================
-- 9. LEADERBOARD (Materialised daily snapshot)
-- ============================================================

CREATE TABLE public.leaderboard_entries (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period          TEXT NOT NULL CHECK (period IN ('daily','weekly','monthly','alltime')),
  period_key      TEXT NOT NULL,           -- '2026-03-18' / '2026-W11' / '2026-03' / 'all'
  steps           BIGINT DEFAULT 0,
  distance_km     NUMERIC(10,3) DEFAULT 0,
  coins_earned    NUMERIC(12,2) DEFAULT 0,
  rank            INT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, period, period_key)
);

CREATE INDEX idx_lb_period ON public.leaderboard_entries(period, period_key, steps DESC);
CREATE INDEX idx_lb_user ON public.leaderboard_entries(user_id, period);


-- ============================================================
-- 10. SOCIAL — FRIENDS & ACTIVITY FEED
-- ============================================================

CREATE TABLE public.friendships (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  friend_id       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status          TEXT DEFAULT 'pending' CHECK (status IN ('pending','accepted','blocked')),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, friend_id)
);

CREATE TABLE public.activity_feed (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type            TEXT NOT NULL CHECK (type IN (
                    'step_goal','challenge_complete','streak_milestone',
                    'donation','redemption','level_up','new_record'
                  )),
  title           TEXT NOT NULL,
  body            TEXT,
  badge           TEXT,
  ref_id          UUID,
  ref_type        TEXT,
  is_public       BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_feed_user ON public.activity_feed(user_id, created_at DESC);
CREATE INDEX idx_feed_public ON public.activity_feed(created_at DESC) WHERE is_public = TRUE;


-- ============================================================
-- 11. FRAUD / ANTI-CHEAT LOG
-- ============================================================

CREATE TABLE public.fraud_logs (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  txn_id          UUID,
  batch_id        UUID,
  cheat_types     TEXT[] NOT NULL,
  risk_score      NUMERIC(5,2) NOT NULL,
  decision        TEXT NOT NULL CHECK (decision IN ('APPROVE','REVIEW','BLOCK','SUSPEND')),
  evidence        JSONB DEFAULT '{}',
  audit_trail     TEXT[] DEFAULT '{}',
  reviewed_by     UUID REFERENCES public.profiles(id),
  reviewed_at     TIMESTAMPTZ,
  review_action   TEXT CHECK (review_action IN ('approved','confirmed_fraud','false_positive')),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_fraud_user ON public.fraud_logs(user_id, created_at DESC);
CREATE INDEX idx_fraud_decision ON public.fraud_logs(decision, created_at DESC);
CREATE INDEX idx_fraud_score ON public.fraud_logs(risk_score DESC);


-- ============================================================
-- 12. NOTIFICATIONS
-- ============================================================

CREATE TABLE public.notifications (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID REFERENCES public.profiles(id) ON DELETE CASCADE,  -- NULL = broadcast
  title           TEXT NOT NULL,
  body            TEXT NOT NULL,
  type            TEXT DEFAULT 'general' CHECK (type IN (
                    'general','goal_reached','challenge','donation',
                    'coin_earned','fraud_alert','system','promotional'
                  )),
  deep_link       TEXT,
  is_read         BOOLEAN DEFAULT FALSE,
  sent_at         TIMESTAMPTZ,
  open_rate       NUMERIC(5,2),
  target_segment  TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notif_user ON public.notifications(user_id, created_at DESC) WHERE user_id IS NOT NULL;


-- ============================================================
-- 13. BRAND PARTNERS
-- ============================================================

CREATE TABLE public.brand_partners (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name            TEXT NOT NULL,
  category        TEXT,
  logo_url        TEXT,
  contact_email   TEXT,
  partnership_type TEXT CHECK (partnership_type IN ('reward','campaign','exclusive')),
  revenue_mtd     NUMERIC(14,2) DEFAULT 0,
  contract_until  DATE,
  is_active       BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- 14. APP SETTINGS (Admin-configurable platform config)
-- ============================================================

CREATE TABLE public.app_settings (
  key             TEXT PRIMARY KEY,
  value           TEXT NOT NULL,
  description     TEXT,
  updated_by      UUID REFERENCES public.profiles(id),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO public.app_settings (key, value, description) VALUES
('coins_per_100_steps',    '1.00',  'FKC coins earned per 100 steps'),
('inr_per_coin',           '0.33',  'INR value of 1 FKC coin'),
('boost_multiplier',       '2.00',  '2x boost multiplier value'),
('max_coins_per_day',      '10000', 'Maximum FKC coins a user can earn in one day'),
('min_steps_to_earn',      '100',   'Minimum steps before coins are awarded'),
('referral_bonus_coins',   '500',   'FKC coins awarded for successful referral'),
('maintenance_mode',       'false', 'Set to true to enable maintenance mode'),
('min_app_version_android','1.0.0', 'Minimum supported Android app version'),
('min_app_version_ios',    '1.0.0', 'Minimum supported iOS app version'),
('fraud_review_threshold', '30',    'Risk score above which transactions go to REVIEW'),
('fraud_block_threshold',  '60',    'Risk score above which transactions are BLOCKED'),
('fraud_suspend_threshold','85',    'Risk score above which accounts are SUSPENDED');


-- ============================================================
-- 15. ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Enable RLS on all user tables
ALTER TABLE public.profiles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.step_events           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.step_batches          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sessions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coin_transactions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.redemptions           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.donations             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboard_entries   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_feed         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fraud_logs            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications         ENABLE ROW LEVEL SECURITY;

-- PROFILES: users see own record; update own record
CREATE POLICY "profiles_own_read"   ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_own_update" ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_own_insert" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- STEP EVENTS: own only
CREATE POLICY "step_events_select" ON public.step_events FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "step_events_insert" ON public.step_events FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "step_events_update" ON public.step_events FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- STEP BATCHES: own only
CREATE POLICY "step_batches_select" ON public.step_batches FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "step_batches_insert" ON public.step_batches FOR INSERT WITH CHECK (auth.uid() = user_id);

-- WORKOUTS: own only
CREATE POLICY "workouts_select" ON public.workout_sessions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "workouts_insert" ON public.workout_sessions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "workouts_update" ON public.workout_sessions FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- WALLETS: own only
CREATE POLICY "wallets_select" ON public.wallets FOR SELECT USING (auth.uid() = user_id);

-- COIN TRANSACTIONS: own only
CREATE POLICY "coin_txn_select" ON public.coin_transactions FOR SELECT USING (auth.uid() = user_id);

-- REDEMPTIONS: own only
CREATE POLICY "redemptions_select" ON public.redemptions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "redemptions_insert" ON public.redemptions FOR INSERT WITH CHECK (auth.uid() = user_id);

-- DONATIONS: own only
CREATE POLICY "donations_select" ON public.donations FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "donations_insert" ON public.donations FOR INSERT WITH CHECK (auth.uid() = user_id);

-- CHALLENGE PARTICIPANTS: own only
CREATE POLICY "chal_parts_select" ON public.challenge_participants FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "chal_parts_insert" ON public.challenge_participants FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "chal_parts_update" ON public.challenge_participants FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- LEADERBOARD: all authenticated users can read; own rows writeable
CREATE POLICY "lb_read_all" ON public.leaderboard_entries
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "lb_own_insert" ON public.leaderboard_entries
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "lb_own_update" ON public.leaderboard_entries
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- FRIENDSHIPS: own
CREATE POLICY "friendships_select" ON public.friendships
  FOR SELECT USING (auth.uid() = user_id OR auth.uid() = friend_id);
CREATE POLICY "friendships_insert" ON public.friendships
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "friendships_update" ON public.friendships
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ACTIVITY FEED: own + public posts readable by all
CREATE POLICY "feed_select" ON public.activity_feed
  FOR SELECT USING (auth.uid() = user_id OR is_public = TRUE);
CREATE POLICY "feed_insert" ON public.activity_feed
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- NOTIFICATIONS: own
CREATE POLICY "notif_own" ON public.notifications
  FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

-- FRAUD LOGS: admins only (service_role bypasses RLS)
CREATE POLICY "fraud_logs_admin" ON public.fraud_logs
  USING (FALSE);  -- only accessible via service_role key


-- ============================================================
-- 16. PUBLIC READ-ONLY VIEWS (for leaderboard, challenges)
-- ============================================================

CREATE OR REPLACE VIEW public.public_profiles AS
SELECT
  id, name, avatar_url, city, level, level_num, is_pro,
  created_at
FROM public.profiles
WHERE is_suspended = FALSE;

CREATE OR REPLACE VIEW public.active_challenges AS
SELECT * FROM public.challenges
WHERE is_active = TRUE
  AND (end_time IS NULL OR end_time > NOW());

CREATE OR REPLACE VIEW public.active_causes AS
SELECT * FROM public.causes WHERE is_active = TRUE;

CREATE OR REPLACE VIEW public.active_perks AS
SELECT * FROM public.perks
WHERE is_active = TRUE
  AND (valid_until IS NULL OR valid_until > NOW())
  AND (stock IS NULL OR redeemed_count < stock);


-- ============================================================
-- 17. ADMIN ANALYTICS VIEWS (used by admin dashboard)
-- ============================================================

CREATE OR REPLACE VIEW public.admin_daily_stats AS
SELECT
  date,
  COUNT(DISTINCT user_id)        AS active_users,
  SUM(steps)                     AS total_steps,
  SUM(coins_earned)              AS coins_issued,
  SUM(CASE WHEN goal_reached THEN 1 ELSE 0 END) AS goals_reached,
  AVG(steps)                     AS avg_steps_per_user,
  SUM(distance_km)               AS total_distance_km
FROM public.step_events
GROUP BY date
ORDER BY date DESC;

CREATE OR REPLACE VIEW public.admin_fraud_summary AS
SELECT
  decision,
  COUNT(*)                       AS count,
  AVG(risk_score)                AS avg_risk_score,
  DATE_TRUNC('day', created_at)  AS day
FROM public.fraud_logs
GROUP BY decision, DATE_TRUNC('day', created_at)
ORDER BY day DESC;

CREATE OR REPLACE VIEW public.admin_donation_summary AS
SELECT
  c.title,
  c.ngo_name,
  COUNT(d.id)                    AS total_donations,
  SUM(d.coins_donated)           AS total_coins,
  SUM(d.inr_value)               AS total_inr,
  c.target_coins,
  c.current_coins,
  ROUND(c.current_coins::NUMERIC / c.target_coins * 100, 1) AS progress_pct
FROM public.causes c
LEFT JOIN public.donations d ON d.cause_id = c.id
GROUP BY c.id, c.title, c.ngo_name, c.target_coins, c.current_coins;


-- ============================================================
-- Done! Run this entire file in Supabase SQL Editor.
-- ============================================================
