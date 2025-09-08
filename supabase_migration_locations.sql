-- Migration: Add location privacy features and connections table
-- Run this after the initial setup

-- 1. Update profiles table with known location fields
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS known_location JSONB,
ADD COLUMN IF NOT EXISTS known_location_name TEXT,
ADD COLUMN IF NOT EXISTS location_updated_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS location_accuracy TEXT DEFAULT 'city' CHECK (location_accuracy IN ('city', 'region', 'country'));

-- 2. Create connections table for mixed network (app users + non-app contacts)
CREATE TABLE IF NOT EXISTS public.connections (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    connection_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, -- NULL if non-app user
    name TEXT NOT NULL,
    assigned_location JSONB, -- Location assigned by user for this connection
    assigned_location_name TEXT,
    actual_known_location JSONB, -- Their actual known location (if app user)
    actual_known_location_name TEXT,
    location_source TEXT CHECK (location_source IN ('assigned', 'actual', 'both')),
    has_account BOOLEAN DEFAULT FALSE,
    connection_type TEXT DEFAULT 'pending' CHECK (connection_type IN ('pending', 'accepted', 'blocked')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    UNIQUE(user_id, connection_user_id),
    UNIQUE(user_id, name) -- Prevent duplicate names for non-app users
);

-- 3. Enable RLS on connections table
ALTER TABLE public.connections ENABLE ROW LEVEL SECURITY;

-- 4. Create policies for connections table
-- Users can view their own connections
CREATE POLICY "Users can view own connections" ON public.connections
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own connections
CREATE POLICY "Users can insert own connections" ON public.connections
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own connections
CREATE POLICY "Users can update own connections" ON public.connections
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own connections
CREATE POLICY "Users can delete own connections" ON public.connections
    FOR DELETE USING (auth.uid() = user_id);

-- 5. Create indexes for performance
CREATE INDEX IF NOT EXISTS connections_user_id_idx ON public.connections(user_id);
CREATE INDEX IF NOT EXISTS connections_connection_user_id_idx ON public.connections(connection_user_id);
CREATE INDEX IF NOT EXISTS connections_has_account_idx ON public.connections(has_account);
CREATE INDEX IF NOT EXISTS profiles_known_location_idx ON public.profiles USING GIN (known_location);

-- 6. Function to upgrade connection when non-app user joins
CREATE OR REPLACE FUNCTION public.upgrade_connection_on_signup()
RETURNS TRIGGER AS $$
DECLARE
    user_name TEXT;
BEGIN
    -- Get the name from the new user's profile
    SELECT name INTO user_name FROM public.profiles WHERE id = NEW.id;
    
    -- Update any connections that match this user's name to link to their account
    UPDATE public.connections
    SET 
        connection_user_id = NEW.id,
        has_account = TRUE,
        location_source = 'actual',
        updated_at = NOW()
    WHERE 
        connection_user_id IS NULL 
        AND LOWER(name) = LOWER(user_name);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Trigger to auto-upgrade connections when users join
DROP TRIGGER IF EXISTS upgrade_connections_on_user_signup ON public.profiles;
CREATE TRIGGER upgrade_connections_on_user_signup
    AFTER INSERT ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.upgrade_connection_on_signup();

-- 8. View for connection statistics
CREATE OR REPLACE VIEW public.connection_stats AS
SELECT 
    user_id,
    COUNT(*) as total_connections,
    COUNT(CASE WHEN has_account = TRUE THEN 1 END) as app_user_connections,
    COUNT(CASE WHEN has_account = FALSE THEN 1 END) as non_app_connections,
    COUNT(assigned_location) as connections_with_assigned_location,
    COUNT(actual_known_location) as connections_with_actual_location
FROM public.connections
GROUP BY user_id;

GRANT SELECT ON public.connection_stats TO authenticated;

-- 9. Grant permissions
GRANT ALL ON public.connections TO authenticated;