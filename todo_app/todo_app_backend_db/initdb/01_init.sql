-- Create a simple table for ping counts
CREATE TABLE IF NOT EXISTS todos (
    id SERIAL PRIMARY KEY,
    text TEXT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed one row if table is empty
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM todos) THEN
    INSERT INTO todos(text) VALUES ('Learn JavaScript');
    INSERT INTO todos(text) VALUES ('Learn React');
    INSERT INTO todos(text) VALUES ('Build a project');
  END IF;
END$$;