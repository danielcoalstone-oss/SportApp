# SportApp (iOS)

Mini football tournament app with authentication, bookings, team joining, Elo leaderboard, and profile stats.

## Features
- Sign in and register flow
- Main dashboard with quick booking cards
- Scheduled tournaments list and tournament detail page
- Create team and join team actions
- Elo leaderboard page
- Profile page with stats and sign out
- Elo simulation actions for demo/testing

## Run
1. Open `SportApp.xcodeproj` in Xcode.
2. Choose the `SportApp` scheme.
3. Run on an iPhone simulator.

## Tech
- SwiftUI
- `ObservableObject` + `@Published` state
- In-memory mock data service
- Elo rating utility (`EloService`)

## Next Production Steps
- Replace mock auth with Firebase Auth / Supabase Auth / custom backend.
- Persist users, tournaments, and team membership in a database.
- Add real match reporting and automatic Elo updates after fixtures.
- Add push notifications for tournament reminders and team invites.
