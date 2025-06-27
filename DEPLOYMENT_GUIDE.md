# 🚀 Complete Deployment Guide

This guide will help you deploy the Työaikakalenteri (Work Schedule Calendar) app to GitHub Pages with Supabase backend.

## 📋 Prerequisites Checklist

- [ ] GitHub account
- [ ] Supabase account (free tier is sufficient)
- [ ] Git installed on your computer
- [ ] Flutter SDK 3.24.3+ installed

## 🗃 Step 1: Database Setup

### 1.1 Create Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Click "Start your project"
3. Sign in/up and create a new project
4. Wait for the project to be ready (2-3 minutes)

### 1.2 Configure Database

1. In your Supabase dashboard, go to **SQL Editor**
2. Click **"New query"**
3. Copy and paste the entire contents of `calendar_app/database_schema.sql`
4. Click **"Run"** to execute the SQL
5. Verify tables were created by going to **Table Editor**

### 1.3 Get Connection Details

1. Go to **Settings > API**
2. Copy your **Project URL** (looks like: `https://xxxxx.supabase.co`)
3. Copy your **anon public** key (long JWT token)

## ⚙️ Step 2: App Configuration

### 2.1 Update Supabase Config

1. Open `calendar_app/lib/services/supabase_config.dart`
2. Replace the URL and key with your values:

```dart
static const String supabaseUrl = 'YOUR_PROJECT_URL_HERE';
static const String supabaseAnonKey = 'YOUR_ANON_KEY_HERE';
```

### 2.2 Test Locally (Optional)

```bash
cd calendar_app
flutter pub get
flutter config --enable-web
flutter run -d chrome
```

## 🔧 Step 3: GitHub Setup

### 3.1 Repository Setup

1. Go to [github.com](https://github.com) and create a new repository named `CalendarApp`
2. Make it **public** (required for free GitHub Pages)
3. Don't initialize with README (we'll push existing code)

### 3.2 Push Code

```bash
# In the CalendarApp root directory (not calendar_app subdirectory)
git init
git add .
git commit -m "Initial commit with Supabase integration"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/CalendarApp.git
git push -u origin main
```

### 3.3 Enable GitHub Pages

1. Go to your repository on GitHub
2. Click **Settings** tab
3. Scroll to **Pages** section (left sidebar)
4. Under **Source**, select **"GitHub Actions"**
5. The GitHub Action will automatically deploy when you push to main

## 🌐 Step 4: Access Your App

1. After the GitHub Action completes (2-3 minutes), your app will be available at:
   `https://YOUR_USERNAME.github.io/CalendarApp/`

2. The first user to sign up will create their own isolated data space

## ✅ Verification Checklist

Test these features after deployment:

- [ ] **Authentication**: Sign up with email/password
- [ ] **Employee Management**: Add/edit/delete employees  
- [ ] **Week Navigation**: Navigate between weeks 1-52
- [ ] **Shift Assignment**: Drag employees to time slots
- [ ] **Data Persistence**: Refresh page, data should remain
- [ ] **Year View**: View all 52 weeks in grid format
- [ ] **Logout**: Sign out and sign back in

## 🔧 Troubleshooting

### Build Fails
```bash
flutter clean
flutter pub get
flutter build web --release
```

### Database Connection Issues
1. Check Supabase project is running (not paused)
2. Verify URL and anon key are correct
3. Check browser console for specific errors

### GitHub Pages Not Updating
1. Go to **Actions** tab in your repo
2. Check if the workflow ran successfully  
3. Look for error messages in the workflow logs

### Authentication Issues
1. Verify Supabase Auth is enabled in your project
2. Check email confirmation settings in Supabase Auth settings
3. Try incognito/private browsing mode

## 🔄 Making Updates

To update the app after deployment:

1. Make your changes
2. Commit and push:
```bash
git add .
git commit -m "Your update description"
git push
```
3. GitHub Action will automatically redeploy

## 📊 Database Tables

The app creates these tables automatically:

- **employees**: Worker profiles with categories and roles
- **work_assignments**: Daily shift assignments by week
- **week_settings**: Profession visibility and row configurations

All tables use Row Level Security (RLS) so users only see their own data.

## 🎨 Color Palette Reference

The app uses these colors:
- **E0FBFC**: Light cyan (backgrounds)
- **C2DFE3**: Light blue (secondary)
- **9DB4C0**: Cadet gray (borders)
- **5C6B73**: Payne's gray (active states)
- **253237**: Gunmetal (text, headers)

## 🆘 Getting Help

If you encounter issues:

1. Check the browser console (F12) for error messages
2. Verify your Supabase project is active
3. Ensure all environment variables are correct
4. Try the troubleshooting steps above

## 🎉 Success!

Once deployed, you'll have a fully functional work schedule calendar with:
- Multi-user support with data isolation
- Real-time cloud synchronization  
- Professional UI with 4-week shift rotation
- Mobile-responsive design
- Secure authentication

Share the URL with your team and start scheduling! 🚀 