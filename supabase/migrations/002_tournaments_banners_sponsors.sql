-- Migration 002: Banners, Sponsors, Tournaments, Scrims, and Wallet Transactions

CREATE TABLE IF NOT EXISTS public.banners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(100) NOT NULL,
    subtitle VARCHAR(200),
    image_url TEXT NOT NULL,
    action_type VARCHAR(50) DEFAULT 'tournament',
    action_target TEXT,
    tag VARCHAR(30) DEFAULT 'FEATURED',
    is_active BOOLEAN DEFAULT true,
    order_index INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.sponsors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    logo_url TEXT NOT NULL,
    website_url TEXT,
    tier VARCHAR(50) DEFAULT 'partner',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.tournaments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(150) NOT NULL,
    game VARCHAR(50) NOT NULL,
    banner_url TEXT NOT NULL,
    entry_fee NUMERIC(10,2) DEFAULT 0.00,
    prize_pool NUMERIC(10,2) DEFAULT 0.00,
    per_kill NUMERIC(10,2) DEFAULT 0.00,
    format VARCHAR(50) DEFAULT 'Squad (Battle Royale)',
    map_name VARCHAR(50) DEFAULT 'Bermuda',
    max_slots INT DEFAULT 48,
    filled_slots INT DEFAULT 0,
    start_time TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'live', 'completed', 'cancelled')),
    rules TEXT,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.scrims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(150) NOT NULL,
    game VARCHAR(50) NOT NULL,
    match_time TIMESTAMPTZ NOT NULL,
    total_slots INT DEFAULT 24,
    filled_slots INT DEFAULT 0,
    room_id VARCHAR(50),
    room_password VARCHAR(50),
    is_locked BOOLEAN DEFAULT false,
    status VARCHAR(20) DEFAULT 'upcoming',
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount NUMERIC(10,2) NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('deposit', 'withdrawal', 'prize_credit', 'entry_fee')),
    description TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'completed',
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sponsors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scrims ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can view active banners" ON public.banners FOR SELECT USING (is_active = true);
CREATE POLICY "Public can view active sponsors" ON public.sponsors FOR SELECT USING (is_active = true);
CREATE POLICY "Public can view tournaments" ON public.tournaments FOR SELECT USING (true);
CREATE POLICY "Public can view scrims" ON public.scrims FOR SELECT USING (true);
CREATE POLICY "Users can view own transactions" ON public.wallet_transactions FOR SELECT USING (auth.uid() = user_id);
