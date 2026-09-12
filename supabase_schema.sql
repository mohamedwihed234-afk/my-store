-- ==============================================================================
-- منصة QR للمحلات (Shop QR Platform) - Supabase Database Schema
-- قم بنسخ هذا الملف ولصقه في Supabase SQL Editor ثم اضغط RUN
-- ==============================================================================

-- 1. تفعيل الامتدادات اللازمة
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. إنشاء جدول المحلات (shops)
CREATE TABLE IF NOT EXISTS public.shops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    phone TEXT,
    whatsapp TEXT,
    snapchat_url TEXT,
    tiktok_url TEXT,
    instagram_url TEXT,
    facebook_url TEXT,
    google_maps_url TEXT,
    google_review_url TEXT,
    menu_url TEXT,
    menu_qr_url TEXT,
    address TEXT,
    logo_url TEXT,
    cover_url TEXT,
    opening_hours TEXT, -- يستخدم أيضاً كنص أسفل الصفحة (Footer/Promo text)
    primary_color TEXT DEFAULT '#0d7a72',
    secondary_color TEXT DEFAULT '#14b8a6',
    colors JSONB DEFAULT '["#0d7a72", "#14b8a6"]'::jsonb,
    custom_links JSONB DEFAULT '[]'::jsonb,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    visible_stats JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. إنشاء جدول تحليلات الأحداث والمشاهدات (analytics_events)
CREATE TABLE IF NOT EXISTS public.analytics_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id UUID REFERENCES public.shops(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL, -- page_view, tiktok_click, whatsapp_click, etc.
    device_type TEXT DEFAULT 'mobile',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. إنشاء الفهارس لتحسين سرعة الاستعلامات
CREATE INDEX IF NOT EXISTS idx_shops_slug ON public.shops(slug);
CREATE INDEX IF NOT EXISTS idx_shops_status ON public.shops(status);
CREATE INDEX IF NOT EXISTS idx_analytics_shop_id ON public.analytics_events(shop_id);
CREATE INDEX IF NOT EXISTS idx_analytics_created_at ON public.analytics_events(created_at);
CREATE INDEX IF NOT EXISTS idx_analytics_event_type ON public.analytics_events(event_type);

-- 5. وظيفة تحديث تاريخ التعديل التلقائي (updated_at trigger)
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_shops_updated_at ON public.shops;
CREATE TRIGGER tr_shops_updated_at
    BEFORE UPDATE ON public.shops
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- 6. تفعيل حماية الصفوف Row Level Security (RLS)
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

-- سياسات جدول المحلات:
-- أ. السماح لأي زائر بقراءة المحلات النشطة
CREATE POLICY "Public shops are viewable by everyone" 
ON public.shops FOR SELECT 
USING (status = 'active' OR auth.role() = 'authenticated');

-- ب. السماح للمستخدمين المسجلين (الأدمن) بجميع العمليات على المحلات
CREATE POLICY "Authenticated users can insert shops" 
ON public.shops FOR INSERT 
TO authenticated 
WITH CHECK (true);

CREATE POLICY "Authenticated users can update shops" 
ON public.shops FOR UPDATE 
TO authenticated 
USING (true);

CREATE POLICY "Authenticated users can delete shops" 
ON public.shops FOR DELETE 
TO authenticated 
USING (true);

-- سياسات جدول التحليلات:
-- أ. السماح لأي زائر بتسجيل حدث أو مشاهدة
CREATE POLICY "Anyone can insert analytics events" 
ON public.analytics_events FOR INSERT 
WITH CHECK (true);

-- ب. السماح للمستخدم المسجل بقراءة كل التحليلات في لوحة التحكم
CREATE POLICY "Authenticated users can view analytics" 
ON public.analytics_events FOR SELECT 
TO authenticated 
USING (true);

-- 7. إضافة بيانات متجر تجريبي للمعاينة الأولية (اختياري)
INSERT INTO public.shops (
    slug,
    name,
    description,
    phone,
    whatsapp,
    instagram_url,
    tiktok_url,
    google_maps_url,
    opening_hours,
    primary_color,
    secondary_color,
    colors,
    custom_links,
    status
) VALUES (
    'demo-cafe',
    'كافيه الأفق - Demo Café',
    'أجود أنواع القهوة المختصة والحلويات الفاخرة • أهلاً بكم',
    '218910000000',
    '218910000000',
    'https://instagram.com',
    'https://tiktok.com',
    'https://maps.google.com',
    'اسحب الزر للدخول • خصم 10% عند طلبك عبر الواتساب',
    '#0d7a72',
    '#14b8a6',
    '["#0d7a72", "#14b8a6", "#f59e0b"]'::jsonb,
    '[{"name": "المتجر الإلكتروني", "url": "https://example.com", "type": "store", "color": "#f97316"}]'::jsonb,
    'active'
) ON CONFLICT (slug) DO NOTHING;
