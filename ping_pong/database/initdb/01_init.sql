-- Create a simple table for ping counts
CREATE TABLE IF NOT EXISTS ping_count (
    id SERIAL PRIMARY KEY,
    count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed one row if table is empty
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM ping_count) THEN
    INSERT INTO ping_count(count) VALUES (0);
  END IF;
END$$;