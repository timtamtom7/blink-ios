# Blink iOS — R12: Sharing & Shared Albums

## Goal
Transform Blink from a personal journal into a platform for sharing life's moments with close friends and family.

## Features

### 1. Shared Albums
- **Create shared album**: Invite up to 10 people to contribute to a shared video album
- **Bidirectional sharing**: Anyone can add clips to shared albums
- **Album themes**: Birthdays, holidays, trips, "Our Family" collections
- **Approval mode**: Optional — album creator can review before clips appear

### 2. Social Sharing
- **Share to feed**: Post highlights to the Blink community feed
- **Private link sharing**: Generate secure links to specific clips or albums
- **Reactions & comments**: Lightweight engagement on shared moments
- **Download control**: Clip owner can allow/disallow downloading

### 3. Collaboration Features
- **Event albums**: "Add your clips from Sarah's birthday!"
- **Memory pairing**: When two users are at the same location/time, suggest adding
- **Collaborative curation**: Multiple people can trim/edit shared clips

## Privacy & Safety
- Block list support
- Report mechanism for community feed
- Granular permissions per album
- Expiring access links

## Technical Requirements
- Backend for shared state synchronization
- Real-time updates for collaboration
- Push notifications for shared album activity
- Media upload pipeline

## Success Metrics
- 25% of users create or join a shared album within 30 days
- 2+ shared albums per active user
- Sharing increases retention by 20%

## Dependencies
- R10 (Cloud sync infrastructure)
- Backend team for shared album API

## Estimated Scope
- High complexity (requires backend)
- ~4 weeks
