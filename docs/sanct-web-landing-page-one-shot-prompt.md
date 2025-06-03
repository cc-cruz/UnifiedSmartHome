# Sanct Web Landing Page - One-Shot Implementation Prompt

## Senior Engineer Instructions for Junior Developer

**Priority Level: P0 - Critical**  
**Estimated Time: 2-3 days**  
**Review Required: Yes, before any commits**

---

## 🎯 **OBJECTIVE**
You will implement a production-ready **web landing page** for our **Sanct** iOS IoT app. This landing page MUST convert visitors to App Store downloads and demo requests. No shortcuts, no "good enough" - this needs to be pixel-perfect, performant, and mobile-responsive.

## 📋 **PREREQUISITES (Do NOT skip these)**
Before you write a single line of code:

1. **Review the marketing materials** in `docs/marketing/` - understand our value props
2. **Study 5 top web landing pages** (Nest.com, SmartThings, Philips Hue, Ring.com, Ecobee)
3. **Set up analytics accounts**: Google Analytics 4, HubSpot, Facebook Pixel (get keys from DevOps)
4. **Get App Store URL** from Product team (placeholder: `https://apps.apple.com/app/sanct/id123456789`)
5. **Confirm browser support**: Chrome 90+, Safari 14+, Firefox 88+, Edge 90+

## 🏗️ **STEP 1: PROJECT SETUP (45 minutes)**

### Create Next.js project with TypeScript:
```bash
npx create-next-app@latest sanct-landing --typescript --tailwind --eslint --app
cd sanct-landing
npm install framer-motion lucide-react @vercel/analytics
```

### Create the folder structure EXACTLY like this:
```
src/
├── app/
│   ├── page.tsx
│   ├── layout.tsx
│   └── globals.css
├── components/
│   ├── Hero/
│   │   ├── HeroSection.tsx
│   │   ├── BackgroundVideo.tsx
│   │   └── AppStoreButton.tsx
│   ├── Features/
│   │   ├── FeatureSection.tsx
│   │   ├── FeatureCard.tsx
│   │   └── FeatureGrid.tsx
│   ├── Social/
│   │   ├── SocialProof.tsx
│   │   ├── LiveCounter.tsx
│   │   └── TestimonialCard.tsx
│   ├── CTA/
│   │   ├── CTASection.tsx
│   │   └── DemoButton.tsx
│   └── Layout/
│       ├── Header.tsx
│       ├── Footer.tsx
│       └── Navigation.tsx
├── lib/
│   ├── analytics.ts
│   ├── constants.ts
│   └── types.ts
├── hooks/
│   ├── useScrollOffset.ts
│   ├── useIntersectionObserver.ts
│   └── useLiveStats.ts
└── styles/
    ├── globals.css
    └── components.css
```

### Add environment variables to `.env.local`:
```bash
NEXT_PUBLIC_GA_ID=your_ga_id
NEXT_PUBLIC_FACEBOOK_PIXEL_ID=your_pixel_id
NEXT_PUBLIC_APP_STORE_URL=https://apps.apple.com/app/sanct/id123456789
```

**❗ VALIDATION CHECKPOINT:** Run `npm run dev`. Site should load with no errors.

## 🎨 **STEP 2: DESIGN SYSTEM & TAILWIND CONFIG (1 hour)**

### Update `tailwind.config.js`:
```javascript
module.exports = {
  content: ['./src/**/*.{js,ts,jsx,tsx,mdx}'],
  theme: {
    extend: {
      colors: {
        sanct: {
          primary: '#3366FF',    // Blue
          secondary: '#CC33CC',  // Purple
          accent: '#00CC66',     // Green
        },
        dark: {
          900: '#0A0A0A',
          800: '#1A1A1A',
          700: '#2A2A2A',
        }
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        display: ['Inter', 'system-ui', 'sans-serif'],
      },
      animation: {
        'fade-up': 'fadeUp 0.6s ease-out forwards',
        'counter': 'counter 2s ease-out forwards',
        'float': 'float 6s ease-in-out infinite',
      }
    },
  },
  plugins: [],
}
```

### Create `src/styles/globals.css`:
```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&display=swap');

@layer base {
  html {
    scroll-behavior: smooth;
  }
  
  body {
    @apply bg-dark-900 text-white antialiased;
  }
}

@layer components {
  .sanct-card {
    @apply bg-white/5 border border-white/10 rounded-2xl backdrop-blur-sm;
  }
  
  .sanct-gradient {
    @apply bg-gradient-to-br from-sanct-primary via-sanct-secondary to-sanct-accent;
  }
}

@keyframes fadeUp {
  from { opacity: 0; transform: translateY(30px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes counter {
  from { transform: scale(0.8); opacity: 0; }
  to { transform: scale(1); opacity: 1; }
}

@keyframes float {
  0%, 100% { transform: translateY(0px); }
  50% { transform: translateY(-20px); }
}
```

**❗ VALIDATION CHECKPOINT:** Styling should be applied. No console errors.

## 📊 **STEP 3: TYPES & CONSTANTS (30 minutes)**

### Create `src/lib/types.ts`:
```typescript
export interface Feature {
  id: string;
  title: string;
  description: string;
  icon: string;
  gradient: string;
}

export interface Benefit {
  id: string;
  title: string;
  description: string;
  value: string;
  icon: string;
}

export interface Testimonial {
  id: string;
  quote: string;
  author: string;
  role: string;
  company: string;
  avatar: string;
}

export interface LiveStats {
  doorsActivated: number;
  metalSaved: number;
  activeBuildersCount: number;
}

export interface AnalyticsEvent {
  name: string;
  parameters?: Record<string, any>;
}
```

### Create `src/lib/constants.ts`:
```typescript
export const FEATURES = [
  {
    id: 'control',
    title: 'One App, Total Control',
    description: 'Your entire home at your fingertips. Locks, thermostats, and sensors — all unified.',
    icon: 'Home',
    gradient: 'from-blue-500 to-purple-600'
  },
  // Add other features from marketing materials
];

export const APP_STORE_URL = process.env.NEXT_PUBLIC_APP_STORE_URL;
export const DEMO_CALENDAR_URL = 'https://calendly.com/sanct/demo'; // Replace with real URL
```

**❗ CRITICAL:** Make sure all data matches the marketing materials exactly.

## 🔧 **STEP 4: ANALYTICS & SERVICES (1 hour)**

### Create `src/lib/analytics.ts`:
```typescript
declare global {
  interface Window {
    gtag: (...args: any[]) => void;
    fbq: (...args: any[]) => void;
  }
}

class AnalyticsService {
  private static instance: AnalyticsService;
  
  static getInstance(): AnalyticsService {
    if (!AnalyticsService.instance) {
      AnalyticsService.instance = new AnalyticsService();
    }
    return AnalyticsService.instance;
  }

  track(eventName: string, parameters?: Record<string, any>) {
    // Google Analytics 4
    if (typeof window !== 'undefined' && window.gtag) {
      window.gtag('event', eventName, parameters);
    }
    
    // Facebook Pixel
    if (typeof window !== 'undefined' && window.fbq) {
      window.fbq('track', eventName, parameters);
    }
    
    // Console log for development
    console.log('Analytics Event:', eventName, parameters);
  }

  trackPageView(path: string) {
    this.track('page_view', { page_path: path });
  }

  trackAppStoreClick() {
    this.track('app_store_click');
  }

  trackDemoRequest() {
    this.track('demo_request');
  }

  trackScrollDepth(depth: number) {
    this.track('scroll_depth', { depth_percentage: depth });
  }
}

export const analytics = AnalyticsService.getInstance();
```

### Create custom hooks in `src/hooks/`:

#### `useScrollOffset.ts`:
```typescript
import { useState, useEffect } from 'react';

export const useScrollOffset = () => {
  const [scrollY, setScrollY] = useState(0);

  useEffect(() => {
    const handleScroll = () => setScrollY(window.scrollY);
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return scrollY;
};
```

#### `useIntersectionObserver.ts`:
```typescript
import { useState, useEffect, useRef } from 'react';

export const useIntersectionObserver = (threshold = 0.1) => {
  const [isInView, setIsInView] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => setIsInView(entry.isIntersecting),
      { threshold }
    );

    if (ref.current) observer.observe(ref.current);
    return () => observer.disconnect();
  }, [threshold]);

  return { ref, isInView };
};
```

**❗ VALIDATION CHECKPOINT:** Analytics should log events to console.

## 🎬 **STEP 5: ANIMATED COMPONENTS (2.5 hours)**

### Create `src/components/Hero/AppStoreButton.tsx`:
```typescript
'use client';

import { motion } from 'framer-motion';
import { analytics } from '@/lib/analytics';
import { APP_STORE_URL } from '@/lib/constants';

export default function AppStoreButton() {
  const handleClick = () => {
    analytics.trackAppStoreClick();
    window.open(APP_STORE_URL, '_blank');
  };

  return (
    <motion.button
      onClick={handleClick}
      className="bg-black text-white px-8 py-4 rounded-xl flex items-center gap-3 hover:bg-gray-900 transition-colors"
      whileHover={{ scale: 1.05 }}
      whileTap={{ scale: 0.95 }}
    >
      <svg className="w-8 h-8" viewBox="0 0 24 24" fill="currentColor">
        {/* App Store icon SVG */}
      </svg>
      <div className="text-left">
        <div className="text-xs">Download on the</div>
        <div className="text-lg font-semibold">App Store</div>
      </div>
    </motion.button>
  );
}
```

### Create `src/components/Social/LiveCounter.tsx`:
```typescript
'use client';

import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';

interface LiveCounterProps {
  targetValue: number;
  label: string;
  duration?: number;
}

export default function LiveCounter({ targetValue, label, duration = 2000 }: LiveCounterProps) {
  const [count, setCount] = useState(0);

  useEffect(() => {
    const increment = targetValue / (duration / 16);
    const timer = setInterval(() => {
      setCount(prev => {
        if (prev >= targetValue) {
          clearInterval(timer);
          return targetValue;
        }
        return Math.ceil(prev + increment);
      });
    }, 16);

    return () => clearInterval(timer);
  }, [targetValue, duration]);

  return (
    <motion.div 
      className="text-center"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.6 }}
    >
      <div className="text-4xl font-bold text-white font-mono">
        {count.toLocaleString()}
      </div>
      <div className="text-white/80 text-sm mt-2">{label}</div>
    </motion.div>
  );
}
```

### Create `src/components/Features/FeatureCard.tsx`:
```typescript
'use client';

import { motion } from 'framer-motion';
import { useIntersectionObserver } from '@/hooks/useIntersectionObserver';
import { Feature } from '@/lib/types';

interface FeatureCardProps {
  feature: Feature;
  index: number;
}

export default function FeatureCard({ feature, index }: FeatureCardProps) {
  const { ref, isInView } = useIntersectionObserver();

  return (
    <motion.div
      ref={ref}
      className="sanct-card p-8 h-full"
      initial={{ opacity: 0, y: 50 }}
      animate={isInView ? { opacity: 1, y: 0 } : { opacity: 0, y: 50 }}
      transition={{ duration: 0.6, delay: index * 0.2 }}
    >
      <div className={`w-20 h-20 rounded-full bg-gradient-to-br ${feature.gradient} flex items-center justify-center mb-6`}>
        {/* Icon component based on feature.icon */}
      </div>
      
      <h3 className="text-2xl font-bold mb-4">{feature.title}</h3>
      <p className="text-white/80 leading-relaxed">{feature.description}</p>
    </motion.div>
  );
}
```

**❗ VALIDATION CHECKPOINT:** All animations should be smooth. No performance issues.

## 🏠 **STEP 6: MAIN SECTIONS (3.5 hours)**

### Build sections in this EXACT order:

#### 6.1 Hero Section (`src/components/Hero/HeroSection.tsx`) - 1 hour:
```typescript
'use client';

import { motion } from 'framer-motion';
import AppStoreButton from './AppStoreButton';
import BackgroundVideo from './BackgroundVideo';

export default function HeroSection() {
  return (
    <section className="relative min-h-screen flex items-center justify-center overflow-hidden">
      <BackgroundVideo />
      
      {/* Gradient Overlay */}
      <div className="absolute inset-0 bg-gradient-to-b from-black/70 via-black/30 to-black/80" />
      
      {/* Content */}
      <div className="relative z-10 text-center max-w-4xl mx-auto px-6">
        <motion.h1 
          className="text-5xl md:text-7xl font-bold mb-6"
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 1, delay: 0.3 }}
        >
          The Smartest Thing in Your Home is You
        </motion.h1>
        
        <motion.p 
          className="text-xl md:text-2xl text-white/90 mb-12 max-w-3xl mx-auto"
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 1, delay: 0.6 }}
        >
          Unified control for every door. No hardware lock-in. Real revenue for builders.
        </motion.p>
        
        <motion.div 
          className="flex flex-col sm:flex-row gap-6 items-center justify-center"
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 1, delay: 0.9 }}
        >
          <AppStoreButton />
          
          <button className="border border-white/30 text-white px-8 py-4 rounded-xl hover:bg-white/10 transition-colors">
            Schedule a Demo
          </button>
        </motion.div>
        
        {/* Scroll Indicator */}
        <motion.div 
          className="absolute bottom-8 left-1/2 transform -translate-x-1/2"
          animate={{ y: [0, 10, 0] }}
          transition={{ duration: 2, repeat: Infinity }}
        >
          <div className="text-white/60 text-sm mb-2">Discover Sanct</div>
          <svg className="w-6 h-6 text-white/60 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 14l-7 7m0 0l-7-7m7 7V3" />
          </svg>
        </motion.div>
      </div>
    </section>
  );
}
```

#### 6.2 Social Proof Section - 45 minutes:
- **Live counter animations** for doors activated & metal saved
- **Trusted by builders** logos and messaging
- **Background styling** to separate from hero

#### 6.3 Features Section - 1 hour:
- **"Why Choose Sanct?" headline**
- **Responsive grid** of feature cards
- **Intersection observer animations**
- **Use the 3 core features** from marketing materials

#### 6.4 Role-Based Benefits Section - 45 minutes:
- **Three target audiences**: Builders, Property Managers, Homeowners
- **Benefit cards** with icons and value props
- **Horizontal scroll** on mobile

#### 6.5 Final CTA Section - 30 minutes:
- **Conversion-focused copy**
- **Large App Store button**
- **Demo scheduling integration**
- **Urgency-creating design**

**❗ VALIDATION CHECKPOINT:** All sections render correctly and are responsive.

## 🏗️ **STEP 7: PAGE ASSEMBLY & LAYOUT (1 hour)**

### Create `src/app/page.tsx`:
```typescript
import HeroSection from '@/components/Hero/HeroSection';
import SocialProof from '@/components/Social/SocialProof';
import FeatureSection from '@/components/Features/FeatureSection';
import CTASection from '@/components/CTA/CTASection';

export default function HomePage() {
  return (
    <main className="overflow-x-hidden">
      <HeroSection />
      <SocialProof />
      <FeatureSection />
      {/* Other sections */}
      <CTASection />
    </main>
  );
}
```

### Create `src/app/layout.tsx`:
```typescript
import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'Sanct - Smart Home Control for Everyone',
  description: 'The smartest thing in your home is you. Unified control for every door. No hardware lock-in.',
  keywords: 'smart home, IoT, home automation, door control, smart locks',
  openGraph: {
    title: 'Sanct - Smart Home Control for Everyone',
    description: 'The smartest thing in your home is you.',
    url: 'https://sanct.app',
    siteName: 'Sanct',
    type: 'website',
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="scroll-smooth">
      <body className={inter.className}>
        {children}
      </body>
    </html>
  );
}
```

**❗ VALIDATION CHECKPOINT:** Full page loads without errors. Smooth scrolling works.

## 📱 **STEP 8: RESPONSIVE DESIGN & MOBILE OPTIMIZATION (1.5 hours)**

### Test on ALL breakpoints:
- **Mobile (320px-767px)**: Ensure touch targets are 44px minimum
- **Tablet (768px-1023px)**: Adjust grid layouts and spacing
- **Desktop (1024px+)**: Prevent excessive white space, optimize for large screens

### Mobile-specific optimizations:
```css
@media (max-width: 767px) {
  .hero-text {
    @apply text-4xl;
  }
  
  .feature-grid {
    @apply grid-cols-1 gap-6;
  }
  
  .cta-buttons {
    @apply flex-col space-y-4;
  }
}
```

### Performance optimizations:
- **Image optimization** with Next.js Image component
- **Lazy loading** for all sections below the fold
- **Code splitting** for non-critical components
- **Font optimization** with Next.js font loading

**❗ VALIDATION CHECKPOINT:** Site works perfectly on all device sizes.

## 🔥 **STEP 9: PERFORMANCE & SEO (1 hour)**

### Performance targets:
- **Lighthouse Score**: 90+ on all metrics
- **First Contentful Paint**: < 1.5s
- **Largest Contentful Paint**: < 2.5s
- **Cumulative Layout Shift**: < 0.1

### SEO optimizations:
```typescript
// Add structured data
const jsonLd = {
  '@context': 'https://schema.org',
  '@type': 'SoftwareApplication',
  name: 'Sanct',
  description: 'Smart home control app',
  applicationCategory: 'Lifestyle',
  operatingSystem: 'iOS',
  url: APP_STORE_URL,
};
```

### Analytics integration:
- **Google Analytics 4** pageview tracking
- **Facebook Pixel** conversion tracking
- **HubSpot** form tracking
- **Scroll depth tracking** for engagement metrics

**❗ VALIDATION CHECKPOINT:** Lighthouse audit passes. Analytics events fire correctly.

## 🧪 **STEP 10: TESTING & VALIDATION (1 hour)**

### Manual testing checklist:
- [ ] All animations complete smoothly on all devices
- [ ] App Store button opens correct URL in new tab
- [ ] Demo button triggers proper analytics tracking
- [ ] All text is readable with proper contrast ratios
- [ ] No horizontal scroll on any device size
- [ ] Form submissions work (if applicable)
- [ ] Page loads in under 3 seconds on 3G
- [ ] All images have proper alt text
- [ ] Site works with JavaScript disabled (graceful degradation)

### Cross-browser testing:
- [ ] Chrome (latest)
- [ ] Safari (latest)
- [ ] Firefox (latest)
- [ ] Edge (latest)
- [ ] Mobile Safari
- [ ] Chrome Mobile

## 🚀 **STEP 11: DEPLOYMENT & PRODUCTION (45 minutes)**

### Deploy to Vercel:
```bash
npm install -g vercel
vercel --prod
```

### Environment variables for production:
- Set real analytics IDs
- Configure proper App Store URL
- Set up custom domain

### Performance monitoring:
- **Vercel Analytics** for Core Web Vitals
- **Real User Monitoring** for performance tracking
- **Error tracking** with Sentry (optional)

## ✅ **STEP 12: PRE-LAUNCH CHECKLIST**

**STOP. Do NOT deploy until ALL items are checked:**

- [ ] Lighthouse score 90+ on all metrics
- [ ] All analytics events tracked correctly
- [ ] App Store button opens correct URL
- [ ] Site loads in under 3 seconds on mobile
- [ ] No console errors or warnings
- [ ] All images optimized and have alt text
- [ ] Responsive design works on all devices
- [ ] Cross-browser compatibility verified
- [ ] SEO meta tags are complete
- [ ] Legal pages linked (Privacy Policy, Terms)

## 🚨 **CRITICAL SUCCESS CRITERIA**

Your implementation will be rejected if ANY of these fail:

1. **Performance**: Lighthouse score must be 90+ on all metrics
2. **Responsive**: Must look perfect on all device sizes
3. **Analytics**: All user interactions must be tracked
4. **Conversion**: App Store CTA must work flawlessly
5. **SEO**: Must rank well for target keywords
6. **Accessibility**: Must meet WCAG 2.1 AA standards
7. **Speed**: Must load in under 3 seconds on 3G
8. **Cross-browser**: Must work identically across all major browsers

## 📞 **WHEN TO ASK FOR HELP**

**ASK IMMEDIATELY if:**
- Lighthouse scores are below targets after optimization
- Animations are janky on mobile devices
- Analytics integration is not working
- Any step takes >50% longer than estimated time
- Cross-browser compatibility issues

**DO NOT ask about:**
- Basic React/Next.js syntax (Google it)
- Tailwind CSS classes (check documentation)
- Marketing copy (it's in the docs/marketing/ folder)

## 🎯 **SUCCESS DEFINITION**

You've succeeded when:
1. **Marketing team** approves the visual design and copy
2. **Lighthouse audit** scores 90+ on all metrics
3. **QA testing** finds zero critical issues
4. **Analytics dashboard** shows events firing correctly
5. **Product manager** approves for production deployment

**Remember**: This landing page will be the first impression for thousands of potential users and the primary driver of App Store downloads. Make it count.

---

**Questions? Slack me immediately. Do not struggle in silence.**

**- Senior Full-Stack Engineer** 