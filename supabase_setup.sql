-- ====================================
-- DigiVault — Supabase Database Setup
-- Safe to run multiple times (uses DROP IF EXISTS)
-- ====================================

-- 1. PROFILES TABLE
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  avatar TEXT,
  plan TEXT DEFAULT 'free' CHECK (plan IN ('free', 'pro', 'enterprise')),
  plan_status TEXT DEFAULT 'active',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. PRODUCTS TABLE
CREATE TABLE IF NOT EXISTS products (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  short_description TEXT,
  category TEXT DEFAULT 'course',
  tags TEXT[] DEFAULT '{}',
  price NUMERIC DEFAULT 0,
  sale_price NUMERIC,
  thumbnail TEXT,
  required_plan TEXT DEFAULT 'free',
  features TEXT[] DEFAULT '{}',
  is_featured BOOLEAN DEFAULT false,
  is_published BOOLEAN DEFAULT true,
  downloads INTEGER DEFAULT 0,
  views INTEGER DEFAULT 0,
  rating_avg NUMERIC DEFAULT 0,
  rating_count INTEGER DEFAULT 0,
  version TEXT DEFAULT '1.0',
  license TEXT DEFAULT 'personal',
  author_id UUID REFERENCES auth.users(id),
  author_name TEXT DEFAULT 'Admin',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. REVIEWS TABLE
CREATE TABLE IF NOT EXISTS reviews (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. WISHLISTS TABLE
CREATE TABLE IF NOT EXISTS wishlists (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, product_id)
);

-- 5. DOWNLOADS TABLE
CREATE TABLE IF NOT EXISTS downloads (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  count INTEGER DEFAULT 1,
  downloaded_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. ORDERS TABLE
CREATE TABLE IF NOT EXISTS orders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  invoice_number TEXT,
  products JSONB DEFAULT '[]',
  total_amount NUMERIC DEFAULT 0,
  status TEXT DEFAULT 'completed',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ====================================
-- ENABLE RLS
-- ====================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE wishlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE downloads ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- ====================================
-- DROP ALL EXISTING POLICIES (safe cleanup)
-- ====================================
DROP POLICY IF EXISTS "Anyone can view profiles" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
DROP POLICY IF EXISTS "Admins can update any profile" ON profiles;

DROP POLICY IF EXISTS "Anyone can view published products" ON products;
DROP POLICY IF EXISTS "Admins can insert products" ON products;
DROP POLICY IF EXISTS "Admins can update products" ON products;
DROP POLICY IF EXISTS "Admins can delete products" ON products;

DROP POLICY IF EXISTS "Anyone can view reviews" ON reviews;
DROP POLICY IF EXISTS "Users can create reviews" ON reviews;

DROP POLICY IF EXISTS "Users can view own wishlists" ON wishlists;
DROP POLICY IF EXISTS "Users can add to wishlist" ON wishlists;
DROP POLICY IF EXISTS "Users can remove from wishlist" ON wishlists;

DROP POLICY IF EXISTS "Users can view own downloads" ON downloads;
DROP POLICY IF EXISTS "Users can track downloads" ON downloads;
DROP POLICY IF EXISTS "Users can update own downloads" ON downloads;

DROP POLICY IF EXISTS "Users can view own orders" ON orders;

-- ====================================
-- CREATE POLICIES
-- ====================================

-- PROFILES
CREATE POLICY "Anyone can view profiles" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Admins can update any profile" ON profiles FOR UPDATE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- PRODUCTS
CREATE POLICY "Anyone can view published products" ON products FOR SELECT USING (true);
CREATE POLICY "Admins can insert products" ON products FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Admins can update products" ON products FOR UPDATE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Admins can delete products" ON products FOR DELETE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- REVIEWS
CREATE POLICY "Anyone can view reviews" ON reviews FOR SELECT USING (true);
CREATE POLICY "Users can create reviews" ON reviews FOR INSERT WITH CHECK (auth.uid() = user_id);

-- WISHLISTS
CREATE POLICY "Users can view own wishlists" ON wishlists FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can add to wishlist" ON wishlists FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can remove from wishlist" ON wishlists FOR DELETE USING (auth.uid() = user_id);

-- DOWNLOADS
CREATE POLICY "Users can view own downloads" ON downloads FOR SELECT USING (
  auth.uid() = user_id OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Users can track downloads" ON downloads FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own downloads" ON downloads FOR UPDATE USING (auth.uid() = user_id);

-- ORDERS
CREATE POLICY "Users can view own orders" ON orders FOR SELECT USING (
  auth.uid() = user_id OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ====================================
-- FUNCTION: Increment Downloads
-- ====================================
CREATE OR REPLACE FUNCTION increment_downloads(product_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE products SET downloads = downloads + 1 WHERE id = product_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ====================================
-- AUTO-CREATE PROFILE ON SIGNUP
-- ====================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, name, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'User'),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'user')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ====================================
-- SEED PRODUCTS (skip if already seeded)
-- ====================================
INSERT INTO products (title, description, short_description, category, tags, price, sale_price, thumbnail, required_plan, features, is_featured, downloads, views, rating_avg, rating_count, author_name)
SELECT * FROM (VALUES
('Complete React Developer Course', 'Master React.js from beginner to advanced. Build 15 real-world projects including Netflix, Stripe, and more.', 'Master React.js with 15 real-world projects', 'course', ARRAY['react','javascript','frontend'], 8299::numeric, 4199::numeric, 'https://images.unsplash.com/photo-1633356122544-f134324a6cee?w=400&h=250&fit=crop', 'free', ARRAY['15 real-world projects','Hooks & Context API','Redux Toolkit','Testing with Jest','Certificate'], true, 1240, 5600, 4.8::numeric, 324, 'Admin'),
('Professional UI Kit - 500+ Components', 'A comprehensive Figma UI kit with 500+ ready-to-use components.', '500+ Figma components with dark/light mode', 'template', ARRAY['figma','ui-kit','design'], 6699::numeric, NULL::numeric, 'https://images.unsplash.com/photo-1561070791-2526d30994b5?w=400&h=250&fit=crop', 'pro', ARRAY['500+ components','Dark & Light mode','Auto-layout','Design tokens','Free updates forever'], true, 890, 3200, 4.9::numeric, 187, 'Admin'),
('Node.js & MongoDB REST API Boilerplate', 'Production-ready Node.js REST API boilerplate with authentication and more.', 'Production-ready Node.js API starter', 'software', ARRAY['nodejs','mongodb','api'], 4999::numeric, 3299::numeric, 'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?w=400&h=250&fit=crop', 'free', ARRAY['JWT Authentication','Role-based access','Rate limiting','File uploads','Swagger docs'], true, 2100, 7800, 4.7::numeric, 512, 'Admin'),
('The Art of Machine Learning - eBook', 'A comprehensive 450-page guide to machine learning.', '450-page ML guide with Python examples', 'ebook', ARRAY['machine learning','python','ai'], 2899::numeric, NULL::numeric, 'https://images.unsplash.com/photo-1677442135703-1787eea5ce01?w=400&h=250&fit=crop', 'pro', ARRAY['450 pages','Python code examples','Real-world case studies','Exercises & solutions','PDF + EPUB'], true, 3400, 9100, 4.6::numeric, 891, 'Admin'),
('Chill Lo-Fi Music Pack - 50 Tracks', 'Royalty-free lo-fi hip hop music pack with 50 tracks.', '50 royalty-free lo-fi tracks for creators', 'audio', ARRAY['lo-fi','music','audio'], 2499::numeric, 1499::numeric, 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=250&fit=crop', 'free', ARRAY['50 unique tracks','WAV & MP3 formats','Royalty-free license','Commercial use','Regular updates'], false, 1560, 4200, 4.5::numeric, 234, 'Admin'),
('Premium Motion Graphics Templates', 'Professional After Effects templates for YouTube intros.', '100 After Effects templates for creators', 'video', ARRAY['after effects','motion graphics','video'], 12499::numeric, 8299::numeric, 'https://images.unsplash.com/photo-1536240478700-b869ad10e128?w=400&h=250&fit=crop', 'enterprise', ARRAY['100 AE templates','Easy customization','Tutorial videos','24/7 support','Quarterly updates'], true, 670, 2800, 4.9::numeric, 156, 'Admin'),
('Full-Stack Next.js SaaS Starter Kit', 'Launch your SaaS in days, not months.', 'SaaS boilerplate with auth, billing & dashboard', 'software', ARRAY['nextjs','saas','stripe'], 16699::numeric, 12499::numeric, 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=400&h=250&fit=crop', 'pro', ARRAY['Next.js 14 App Router','Stripe subscriptions','Auth with NextAuth','Admin dashboard','SEO optimized'], true, 1890, 6400, 4.8::numeric, 445, 'Admin'),
('Python for Data Science Masterclass', 'Complete Python DS course with 25 hands-on projects.', 'Python DS course with 25 hands-on projects', 'course', ARRAY['python','data science','pandas'], 7499::numeric, 4999::numeric, 'https://images.unsplash.com/photo-1526379095098-d400fd0bf935?w=400&h=250&fit=crop', 'free', ARRAY['25 real projects','NumPy & Pandas','Machine learning basics','Data visualization','Certificate'], false, 2340, 8900, 4.7::numeric, 678, 'Admin'),
('3D Icon Pack - 200 Animated Icons', 'Modern 3D animated icon pack in multiple formats.', '200 animated 3D icons in multiple formats', 'graphics', ARRAY['icons','3d','animated'], 4199::numeric, NULL::numeric, 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=400&h=250&fit=crop', 'pro', ARRAY['200 animated icons','Lottie + GIF + SVG','Customizable colors','60fps animations','Regular additions'], false, 1120, 3800, 4.6::numeric, 289, 'Admin'),
('Cybersecurity Fundamentals eBook', 'Learn cybersecurity from zero to hero.', 'Complete cybersecurity guide for beginners', 'ebook', ARRAY['cybersecurity','hacking','security'], 1999::numeric, NULL::numeric, 'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?w=400&h=250&fit=crop', 'free', ARRAY['380 pages','Lab exercises','Tool walkthroughs','Career guidance','PDF + EPUB'], false, 4500, 12000, 4.5::numeric, 1023, 'Admin'),
('Cinematic LUT Pack - 50 Color Grades', 'Professional cinematic color grading LUTs.', '50 cinematic LUTs for professional grading', 'video', ARRAY['luts','color grading','video editing'], 3299::numeric, 1999::numeric, 'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?w=400&h=250&fit=crop', 'free', ARRAY['50 unique LUTs','Works with all NLEs','Before/after previews','Installation guide','Free updates'], false, 2890, 7600, 4.4::numeric, 567, 'Admin'),
('Ambient Sound Effects Library', 'Professional 300+ ambient sounds for films and games.', '300+ ambient sounds for films & games', 'audio', ARRAY['sound effects','ambient','sfx'], 4999::numeric, NULL::numeric, 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400&h=250&fit=crop', 'pro', ARRAY['300+ sound effects','24-bit WAV quality','Categorized library','Royalty-free','Monthly additions'], false, 980, 3100, 4.7::numeric, 198, 'Admin'),
('E-Commerce Dashboard Template', 'Beautiful React dashboard for e-commerce platforms.', 'React e-commerce admin dashboard template', 'template', ARRAY['react','dashboard','ecommerce'], 5999::numeric, 3799::numeric, 'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=400&h=250&fit=crop', 'pro', ARRAY['40+ chart variants','Dark & light modes','Responsive design','Real-time updates','Invoice generator'], false, 1650, 5400, 4.8::numeric, 342, 'Admin'),
('Docker & Kubernetes Masterclass', 'Learn containerization and orchestration from scratch.', 'Container orchestration with Docker & K8s', 'course', ARRAY['docker','kubernetes','devops'], 9999::numeric, 6699::numeric, 'https://images.unsplash.com/photo-1667372393119-3d4c48d07fc9?w=400&h=250&fit=crop', 'pro', ARRAY['30+ hours content','Hands-on labs','Cloud deployments','CI/CD pipelines','Certificate'], false, 1890, 6700, 4.9::numeric, 456, 'Admin'),
('Flutter Mobile App Template Bundle', 'Collection of 10 production-ready Flutter app templates.', '10 production-ready Flutter app templates', 'template', ARRAY['flutter','dart','mobile'], 10999::numeric, NULL::numeric, 'https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=400&h=250&fit=crop', 'enterprise', ARRAY['10 complete apps','Firebase integration','Push notifications','Payment gateway','Dark mode'], false, 780, 2900, 4.7::numeric, 167, 'Admin'),
('Startup Pitch Deck Template', 'Investor-ready pitch deck with 50 unique slides.', '50-slide investor pitch deck template', 'template', ARRAY['pitch deck','startup','presentation'], 2499::numeric, 1699::numeric, 'https://images.unsplash.com/photo-1557804506-669a67965ba0?w=400&h=250&fit=crop', 'free', ARRAY['50 unique slides','Keynote + PowerPoint','Fully editable','Chart templates','Icon pack included'], false, 5600, 15000, 4.6::numeric, 890, 'Admin')
) AS v(title, description, short_description, category, tags, price, sale_price, thumbnail, required_plan, features, is_featured, downloads, views, rating_avg, rating_count, author_name)
WHERE NOT EXISTS (SELECT 1 FROM products LIMIT 1);
