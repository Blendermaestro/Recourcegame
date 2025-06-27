# Työaikakalenteri - Work Schedule Calendar

A Flutter web application for managing work schedules with a 4-week shift rotation system. Built with Flutter and Supabase backend.

## 🌟 Features

- **4-Week Shift Rotation**: Automatic A/B/C/D shift cycling across 52 weeks
- **User Authentication**: Secure login/signup with email and password
- **Employee Management**: Add, edit, and delete employees with categories (A/B, C/D, Huolto, Sijainen)
- **Drag & Drop Scheduling**: Intuitive assignment of employees to shifts
- **Week Navigation**: Navigate through all 52 weeks of 2025
- **Year Overview**: Visual calendar showing all weeks and shift assignments
- **Responsive Design**: Works on desktop and mobile browsers
- **Online Sync**: All data saved to cloud database with user separation

## 🚀 Live Demo

Visit the deployed app: [https://blendermaestro.github.io/CalendarApp/](https://blendermaestro.github.io/CalendarApp/)

## 📋 Prerequisites

- Flutter SDK (3.24.3 or later)
- Supabase account
- Git

## 🛠 Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/Blendermaestro/CalendarApp.git
cd CalendarApp/calendar_app
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Database Setup

1. Go to [Supabase](https://supabase.com) and create a new project
2. In your Supabase dashboard, go to SQL Editor
3. Run the SQL script from `database_schema.sql` to create all tables and policies
4. Update the Supabase configuration in `lib/services/supabase_config.dart` with your project details:

```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### 4. Enable Web Support

```bash
flutter config --enable-web
```

### 5. Run the App

```bash
flutter run -d chrome
```

## 🗄 Database Schema

The app uses the following main tables:

- **employees**: Store employee information (name, category, role, etc.)
- **work_assignments**: Store shift assignments by week/day/lane
- **week_settings**: Store profession visibility and row settings per week

All tables include Row Level Security (RLS) to ensure users only access their own data.

## 🌐 Deployment

### GitHub Pages Deployment

The app is automatically deployed to GitHub Pages when changes are pushed to the main branch.

1. Enable GitHub Pages in your repository settings
2. Set source to "GitHub Actions"
3. Push changes to the main branch
4. The GitHub Action will build and deploy the app

### Manual Deployment

```bash
flutter build web --release --web-renderer html --base-href /CalendarApp/
```

## 🎨 Design

The app uses a cool-toned color palette:
- **E0FBFC** - Light cyan (primary background)
- **C2DFE3** - Light blue (secondary elements)
- **9DB4C0** - Cadet gray (borders, medium elements)
- **5C6B73** - Payne's gray (active states)
- **253237** - Gunmetal (text, headers)

## 📱 Usage

1. **Sign Up/Login**: Create an account or sign in with existing credentials
2. **Add Employees**: Go to Employee Settings to add team members
3. **Schedule Shifts**: Use drag & drop to assign employees to time slots
4. **Navigate Weeks**: Use arrow buttons to move between weeks
5. **Year View**: Click "VUOSI" to see the full year calendar
6. **Adjust Settings**: Click the gear icon to configure visible professions

## 🔧 Configuration

### Shift Rotation Pattern

The 4-week cycle follows this pattern:
- **Week 1**: A=day, B=night
- **Week 2**: C=day, D=night
- **Week 3**: B=day, A=night
- **Week 4**: D=day, C=night

### Employee Categories

- **A/B**: Regular employees on A/B shift rotation
- **C/D**: Regular employees on C/D shift rotation
- **Huolto**: Maintenance staff
- **Sijainen**: Substitute workers

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📜 License

This project is licensed under the MIT License.

## 🆘 Support

If you encounter any issues:
1. Check the console for error messages
2. Ensure your Supabase configuration is correct
3. Verify your internet connection
4. Try refreshing the page

## 🔄 Updates

The app automatically syncs data with the cloud database. Changes are saved in real-time and synchronized across all devices.
