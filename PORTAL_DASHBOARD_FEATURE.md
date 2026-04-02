# Portal Dashboard Feature for Host and Guest

## Overview
This feature adds dedicated dashboard endpoints for both Hosts and Guests to view their respective information, statistics, and activities in one centralized location.

## API Endpoints

### Host Dashboard
**Endpoint:** `GET /portals/host_dashboard`

**Description:** Returns comprehensive dashboard data for property hosts including their properties, bookings, earnings, and conversations.

**Response Data:**
```json
{
  "host": { /* host user object */ },
  "properties": [ /* array of host's properties */ ],
  "recent_bookings": [ /* last 10 bookings for host's properties */ ],
  "statistics": {
    "total_properties": 5,
    "active_bookings": 3,
    "completed_bookings": 12,
    "pending_reviews": 2,
    "total_earnings": 5000.00
  },
  "recent_conversations": [ /* last 5 conversations */ ]
}
```

### Guest Dashboard
**Endpoint:** `GET /portals/guest_dashboard`

**Description:** Returns comprehensive dashboard data for guests including their bookings, wishlists, spending, and conversations.

**Response Data:**
```json
{
  "guest": { /* guest user object */ },
  "upcoming_bookings": [ /* next 5 upcoming trips */ ],
  "past_bookings": [ /* last 5 completed stays */ ],
  "pending_reviews": [ /* bookings awaiting guest review */ ],
  "wishlists": [ /* guest's saved property lists */ ],
  "statistics": {
    "total_bookings": 8,
    "total_spent": 3500.00,
    "upcoming_trips": 2,
    "pending_reviews": 1
  },
  "recent_conversations": [ /* last 5 conversations */ ]
}
```

## Files Created/Modified

### New Files:
1. **`app/controllers/portals_controller.rb`** - Controller with two actions:
   - `host_dashboard` - Aggregates all host-related data
   - `guest_dashboard` - Aggregates all guest-related data

2. **`db/migrate/20260402070000_add_host_id_to_properties.rb`** - Migration to add host reference to properties table

### Modified Files:
1. **`config/routes.rb`** - Added portal namespace routes
2. **`app/models/payment.rb`** - Fixed formatted_amount method (removed Money gem dependency)

## Features Included

### Host Dashboard Features:
- **Properties Overview**: List of all properties owned by the host
- **Recent Bookings**: Last 10 bookings across all properties
- **Statistics**:
  - Total properties count
  - Active bookings (not yet ended)
  - Completed bookings
  - Pending reviews awaiting host action
  - Total earnings from successful payments
- **Recent Conversations**: Last 5 active conversations with guests

### Guest Dashboard Features:
- **Upcoming Bookings**: Next 5 future trips (sorted by start date)
- **Past Bookings**: Last 5 completed stays
- **Pending Reviews**: Bookings that need guest review
- **Wishlists**: All saved property wishlists
- **Statistics**:
  - Total bookings count
  - Total amount spent
  - Number of upcoming trips
  - Number of pending reviews
- **Recent Conversations**: Last 5 conversations with hosts

## Database Requirements

The feature requires the following database tables (already present in this codebase):
- `users` (referenced as host/guest)
- `properties` (with host_id foreign key)
- `bookings` (with user_id for guest and property_id)
- `payments` (linked to bookings)
- `conversations` (linked to bookings and properties)
- `messages` (linked to conversations)
- `wishlists` and `wishlist_items` (for guest favorites)

## Authentication

Both endpoints require authentication via the `authenticate_user!` before_action. The current implementation uses a placeholder authentication that should be replaced with your actual authentication strategy (Devise, JWT, etc.).

## Usage Example

```ruby
# Host dashboard
GET /portals/host_dashboard
Headers: { Authorization: "Bearer <token>" }

# Guest dashboard  
GET /portals/guest_dashboard
Headers: { Authorization: "Bearer <token>" }
```

## Performance Considerations

- Uses `.includes()` for eager loading associations to avoid N+1 queries
- Limits result sets (e.g., `.limit(10)`, `.limit(5)`) for recent items
- Uses database-level aggregations (`.count`, `.sum`) for statistics
- Indexed foreign keys ensure efficient joins

## Future Enhancements

Potential improvements for future iterations:
- Date range filters for bookings and earnings
- Pagination for large result sets
- Real-time updates via WebSocket/ActionCable
- Export functionality (CSV, PDF)
- Customizable dashboard widgets
- Notification counts and alerts
- Calendar view for bookings
