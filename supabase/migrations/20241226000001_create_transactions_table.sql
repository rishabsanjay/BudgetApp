-- Create transactions table
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date TIMESTAMP WITH TIME ZONE NOT NULL,
    description TEXT NOT NULL,
    amount NUMERIC(10,2) NOT NULL,
    category TEXT NOT NULL DEFAULT 'Uncategorized',
    type TEXT NOT NULL DEFAULT 'expense',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_transactions_date ON public.transactions(date);
CREATE INDEX IF NOT EXISTS idx_transactions_category ON public.transactions(category);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON public.transactions(type);

-- Enable Row Level Security
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all operations for now (you can restrict this later)
CREATE POLICY "Allow all operations on transactions" ON public.transactions
    FOR ALL USING (true);

-- Create trigger to automatically update updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON public.transactions
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();