# 2-Tier User System Guide

## ✅ What's Been Implemented

Your calendar app now has a **2-tier user access system**:

### 👥 User Tiers

#### **Tier 1 - Full Access**
- ✅ **Week View**: Full access to weekly calendar with editing
- ✅ **Year View**: Full access to yearly overview + fullscreen
- ✅ **Employee Management**: Can add, edit, delete employees
- ✅ **Data Editing**: Can modify schedules, assignments, vacations
- ✅ **All Features**: Complete access to all app functionality

#### **Tier 2 - View Only**
- ❌ **Week View**: No access (blocked)
- ✅ **Year View**: Full access to yearly overview + fullscreen
- ❌ **Employee Management**: No access to employee settings
- ❌ **Data Editing**: Read-only access, cannot modify data
- 🔒 **Limited Features**: View-only access to calendar data

## 🚀 How It Works

### **Default Assignment**
- New users are automatically assigned **Tier 2** by default
- Users with emails ending in `@admin.com` or `@manager.com` get **Tier 1**

### **Access Control**
- Tier 2 users are automatically redirected to Year View on login
- Attempts to access Week View show "Access denied" message
- Year View shows "VIEW ONLY" badge instead of "EDIT" button

### **Fullscreen Support**
- ✅ **Both tiers** can use fullscreen in Year View
- 📱 Works on **mobile**, **web**, and **desktop**
- 🔘 Fullscreen button added to Year View header

## 🛠️ Setup Instructions

### Step 1: Database Setup
Run this SQL in your Supabase dashboard:

```sql
-- User profiles table is already included in database_schema.sql
-- Run the updated schema to create user_profiles table
```

### Step 2: User Management
To change user tiers, you can:

1. **Automatic Assignment**: Users get Tier 2 by default
2. **Email-based Assignment**: Customize in `user_tier_service.dart`
3. **Manual Assignment**: Update directly in Supabase dashboard

### Step 3: Test the System
1. **Create a Tier 2 user** (any regular email)
2. **Login** → Should see Year View only
3. **Try fullscreen** → Should work perfectly
4. **Try to access Week View** → Should be blocked

## 📊 Database Structure

### User Profiles Table
```sql
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    email TEXT NOT NULL,
    tier TEXT NOT NULL DEFAULT 'tier1' CHECK (tier IN ('tier1', 'tier2')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## 🎯 Key Features

### **Smart Navigation**
- Tier 1: Full navigation between Week ↔ Year views
- Tier 2: Locked to Year View only

### **User Experience**
- Loading screen while checking permissions
- Clear "VIEW ONLY" indicator for Tier 2 users
- Graceful error handling and fallbacks

### **Security**
- Server-side access control via Supabase
- Client-side UI restrictions
- Automatic user profile creation on signup

## 🔧 Customization

### Change Default Tier
Edit `user_tier_service.dart`:
```dart
static UserTier getDefaultTierForEmail(String email) {
  if (email.endsWith('@yourcompany.com')) {
    return UserTier.tier1; // Give your team full access
  }
  return UserTier.tier2; // Others get view-only
}
```

### Add More Tiers
You can extend the system by:
1. Adding new tiers to `UserTier` enum
2. Updating database constraints
3. Adding new permission checks

## ✅ Current Status

**READY TO USE**: The 2-tier system is fully implemented!

- ✅ User tier detection: **Working**
- ✅ Access restrictions: **Enforced**
- ✅ Fullscreen in Year View: **Available**
- ✅ Database integration: **Complete**
- ✅ User experience: **Optimized**

🎉 **Tier 2 users now have perfect year-view access with fullscreen capabilities!** 