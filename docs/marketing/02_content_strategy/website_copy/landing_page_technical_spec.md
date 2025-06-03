# Landing Page Technical Specification

## Tech Stack
- **Framework:** Next.js 14 (App Router)
- **Styling:** Tailwind CSS + Framer Motion
- **Deployment:** Vercel
- **Analytics:** Vercel Analytics + Google Analytics 4
- **Forms:** React Hook Form + Zod validation
- **CRM:** HubSpot
- **Monitoring:** Sentry
- **A/B Testing:** Vercel A/B Testing

## Project Structure
```
src/
├── app/
│   ├── page.tsx                 # Main landing page
│   ├── layout.tsx               # Root layout
│   └── api/                     # API routes
├── components/
│   ├── sections/               
│   │   ├── Hero.tsx
│   │   ├── Features.tsx
│   │   ├── Pricing.tsx
│   │   ├── Testimonials.tsx
│   │   └── EnvironmentalImpact.tsx
│   ├── shared/
│   │   ├── Navigation.tsx
│   │   ├── Footer.tsx
│   │   └── CTAButton.tsx
│   └── calculators/
│       ├── ROICalculator.tsx
│       └── EnvironmentalImpact.tsx
└── lib/
    ├── analytics/
    ├── crm/
    └── utils/
```

## Key Components

### 1. Hero Section
```typescript
interface HeroProps {
  variant: 'builder' | 'property-manager' | 'homeowner';
  headline: string;
  subheadline: string;
}

// Dynamic content based on user segment
const headlines = {
  builder: "Turn Smart Homes into Smart Revenue",
  propertyManager: "Smart Access. Smarter Planet.",
  homeowner: "One App. Total Control."
};
```

### 2. Environmental Impact Calculator
```typescript
interface ImpactCalcProps {
  units: number;
  turnoverRate: number;
  currentSystem: 'traditional' | 'smart' | 'mixed';
}

interface ImpactMetrics {
  metalWaste: number;
  carbonSaved: number;
  costSavings: number;
}
```

### 3. Pricing Comparison
```typescript
interface PricingTier {
  name: string;
  price: number;
  features: string[];
  comparisonMatrix: CompetitorComparison[];
}

interface CompetitorComparison {
  competitor: string;
  price: number;
  limitations: string[];
}
```

## Integration Points

### 1. Calendly Integration
```typescript
// Meeting types
const MEETING_TYPES = {
  BUILDER_DEMO: 'builder-consultation',
  PROPERTY_MANAGER_DEMO: 'property-manager-demo',
  ENTERPRISE_DEMO: 'enterprise-consultation'
};

// Embed with dynamic prefill
<CalendlyEmbed
  url={`https://calendly.com/${MEETING_TYPES[userType]}`}
  prefill={{
    email: userEmail,
    name: userName,
    customAnswers: {
      propertyUnits: unitCount
    }
  }}
/>
```

### 2. App Store Deep Linking
```typescript
const APP_STORE_ID = 'your.app.id';
const APP_STORE_URLS = {
  ios: `https://apps.apple.com/app/id${APP_STORE_ID}`,
  web: `https://apps.apple.com/app/apple-store/id${APP_STORE_ID}`,
};

// Smart deep linking
const getAppStoreURL = (device: Device) => {
  return device.ios ? APP_STORE_URLS.ios : APP_STORE_URLS.web;
};
```

### 3. HubSpot Forms
```typescript
interface LeadFormData {
  email: string;
  name: string;
  company?: string;
  propertyUnits?: number;
  userType: 'builder' | 'property-manager' | 'homeowner';
  source: string;
}

const HUBSPOT_PORTAL_ID = 'your_portal_id';
const HUBSPOT_FORM_ID = 'your_form_id';
```

## Analytics Implementation

### 1. Event Tracking
```typescript
const TRACK_EVENTS = {
  PAGE_VIEW: 'page_view',
  CTA_CLICK: 'cta_click',
  CALC_INTERACTION: 'calculator_interaction',
  FORM_START: 'form_start',
  FORM_COMPLETE: 'form_complete',
  APP_STORE_CLICK: 'app_store_click'
};

interface EventProperties {
  userSegment: string;
  source: string;
  element?: string;
  value?: number;
}
```

### 2. A/B Test Configuration
```typescript
const AB_TESTS = {
  HERO_VARIANT: {
    variants: ['A', 'B', 'C'],
    weights: [0.33, 0.33, 0.34]
  },
  CTA_COLOR: {
    variants: ['green', 'blue'],
    weights: [0.5, 0.5]
  }
};
```

## Performance Optimizations

### 1. Image Optimization
```typescript
// Next.js Image configuration
const imageLoader = {
  domains: ['assets.yourdomain.com'],
  sizes: [640, 750, 828, 1080, 1200],
  formats: ['image/avif', 'image/webp']
};
```

### 2. Component Loading
```typescript
// Dynamic imports for heavy components
const ROICalculator = dynamic(() => import('@/components/calculators/ROICalculator'), {
  loading: () => <CalculatorSkeleton />,
  ssr: false
});
```

## Environment Variables
```env
# API Keys
NEXT_PUBLIC_GA_ID=
HUBSPOT_API_KEY=
SENTRY_DSN=

# Feature Flags
ENABLE_AB_TESTING=
ENABLE_ANALYTICS=

# Integration URLs
CALENDLY_BASE_URL=
APP_STORE_ID=
```

## Deployment Configuration
```json
{
  "build": {
    "env": {
      "NEXT_TELEMETRY_DISABLED": "1"
    }
  },
  "git": {
    "deploymentEnabled": {
      "main": true,
      "staging": true,
      "dev": false
    }
  },
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "X-Content-Type-Options",
          "value": "nosniff"
        },
        {
          "key": "X-Frame-Options",
          "value": "DENY"
        }
      ]
    }
  ]
}
```

## Launch Checklist
- [ ] SEO meta tags implementation
- [ ] Open Graph tags for social sharing
- [ ] Schema.org markup for rich results
- [ ] Core Web Vitals optimization
- [ ] Cross-browser testing
- [ ] Mobile responsiveness
- [ ] Form validation
- [ ] Analytics events verification
- [ ] A/B test setup
- [ ] Security headers
- [ ] Performance monitoring
- [ ] Error tracking
- [ ] Accessibility audit 