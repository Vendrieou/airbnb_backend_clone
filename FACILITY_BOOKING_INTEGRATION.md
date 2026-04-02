# Facility Booking Integration - Airbnb-style Booking Engine for Hotel Facilities

## Overview

This feature extends the existing Airbnb-style property booking system to support **facility bookings** within hotel properties, such as:
- Spa treatments (massage, wellness)
- Sports facilities (tennis court, gym sessions)
- Dining experiences
- Other bookable amenities

The implementation is inspired by the provided database schema (`tbl_booking`, `tbl_product`, `tbl_transaction`, etc.) and integrates seamlessly with the existing portal dashboards for Hosts and Guests.

---

## Database Schema

### New Tables Created

#### 1. `facilities`
Stores bookable facilities within properties (equivalent to `tbl_product` in your schema).

```ruby
- id: primary key
- property_id: references properties table
- name: facility name (e.g., "Balinese Massage 60min")
- description: detailed description
- facility_type: category (spa, sports, wellness, dining, etc.)
- price: base price
- discount_price: promotional price
- duration_minutes: session duration
- images: JSON array of image URLs
- image: primary image URL
- active: availability flag
- max_capacity: maximum people per slot
- start_time: daily opening time
- end_time: daily closing time
- slot_interval_minutes: booking slot duration
```

#### 2. `facility_bookings`
Combines concepts from `tbl_booking` and `tbl_transaction_detail`.

```ruby
- id: primary key
- facility_id: references facilities
- property_id: references properties (denormalized for performance)
- user_id: guest who made the booking
- host_id: property owner
- booking_date: date of facility usage
- start_time: slot start time
- end_time: slot end time
- quantity: number of slots/people
- price: unit price at booking time
- discount: fixed discount amount
- discount_percent: percentage discount
- total_price: final price after discounts
- status: pending/confirmed/completed/cancelled
- used: whether the booking was consumed
- special_requests: customer notes
- idempotency_key: prevents duplicate bookings
```

**Key Feature:** Uses PostgreSQL GiST index with exclusion constraint to prevent overlapping bookings for the same facility and time slot.

#### 3. `facility_reviews`
Extends the review system for facilities.

```ruby
- id: primary key
- facility_id: references facilities
- facility_booking_id: references the specific booking
- user_id: reviewer
- rating: 1-5 stars
- comment: review text
- visible: moderation flag
- host_responded: response flag
- host_response: host's reply
- host_response_at: timestamp
```

#### 4. `member_points`
Implements loyalty points system from `tbl_member_point`.

```ruby
- id: primary key
- user_id: member
- facility_booking_id: source booking
- points: points earned
- expired: redemption status
- expires_at: expiration date
```

---

## Models

### Facility (`app/models/facility.rb`)
```ruby
class Facility < ApplicationRecord
  belongs_to :property
  has_many :facility_bookings
  has_many :facility_reviews
  
  # Key methods:
  - available_slots(date): Returns available time slots
  - average_rating: Calculates mean rating
  - bookable?(date, start_time, quantity): Checks availability
  - recent_reviews(limit): Gets latest reviews
end
```

### FacilityBooking (`app/models/facility_booking.rb`)
```ruby
class FacilityBooking < ApplicationRecord
  belongs_to :facility
  belongs_to :property
  belongs_to :guest, class_name: 'User'
  belongs_to :host, class_name: 'User'
  has_one :facility_review
  has_many :member_points
  
  # Key methods:
  - self.create_safe_booking!(): Idempotent booking creation
  - confirm!(): Confirm pending booking
  - cancel!(): Cancel booking
  - complete!(): Mark as completed and award points
  - can_be_reviewed?(): Check review eligibility
  - award_points(): Award loyalty points
end
```

### FacilityReview (`app/models/facility_review.rb`)
```ruby
class FacilityReview < ApplicationRecord
  belongs_to :facility
  belongs_to :facility_booking
  belongs_to :user
  
  # Key methods:
  - self.create_review!(): Create review with validation
  - host_respond!(): Host responds to review
end
```

### MemberPoint (`app/models/member_point.rb`)
```ruby
class MemberPoint < ApplicationRecord
  belongs_to :user
  belongs_to :facility_booking
  
  # Key methods:
  - self.total_active_points(user_id): Get available points
  - self.expire_old_points!(): Expire outdated points
  - self.redeem_points(user_id, amount): Redeem points for discounts
end
```

---

## Enhanced Portal Dashboards

### Host Dashboard Enhancements

**New Statistics:**
- `total_facilities`: Number of facilities managed
- `upcoming_facility_bookings`: Confirmed future bookings
- `pending_facility_bookings`: Awaiting confirmation
- `facility_revenue`: Revenue from facility bookings
- `total_revenue`: Combined property + facility revenue

**New Data:**
- `recent_facility_bookings`: Latest 10 facility bookings
- Includes guest information and facility details

**Example Response:**
```json
{
  "host": {...},
  "properties": [...],
  "recent_bookings": [...],
  "recent_facility_bookings": [
    {
      "id": 1,
      "facility": {"name": "Balinese Massage", "type": "spa"},
      "guest": {"firstName": "John", "lastName": "Doe"},
      "booking_date": "2024-04-15",
      "start_time": "14:00",
      "status": "confirmed",
      "total_price": 150.00
    }
  ],
  "statistics": {
    "total_properties": 3,
    "active_bookings": 5,
    "total_facilities": 8,
    "upcoming_facility_bookings": 12,
    "pending_facility_bookings": 3,
    "facility_revenue": 2450.00,
    "total_revenue": 15750.00
  }
}
```

### Guest Dashboard Enhancements

**New Statistics:**
- `total_facility_bookings`: Total facility sessions booked
- `facility_spent`: Amount spent on facilities
- `total_guest_spent`: Combined spending
- `upcoming_facility_sessions`: Future facility bookings
- `pending_facility_reviews`: Reviews to write
- `available_points`: Loyalty points balance

**New Data:**
- `upcoming_facility_bookings`: Next 5 upcoming sessions
- `past_facility_bookings`: Last 5 completed sessions
- `available_points`: Redeemable points

**Example Response:**
```json
{
  "guest": {...},
  "upcoming_bookings": [...],
  "upcoming_facility_bookings": [
    {
      "id": 5,
      "facility": {"name": "Tennis Court Rental"},
      "property": {"name": "Grand Hotel"},
      "booking_date": "2024-04-20",
      "start_time": "10:00",
      "status": "confirmed"
    }
  ],
  "available_points": 350,
  "statistics": {
    "total_bookings": 8,
    "total_facility_bookings": 12,
    "total_spent": 1200.00,
    "facility_spent": 450.00,
    "total_guest_spent": 1650.00,
    "available_points": 350
  }
}
```

---

## API Endpoints

### Facility Management (Host)
```
GET    /properties/:property_id/facilities          # List facilities
POST   /properties/:property_id/facilities          # Create facility
GET    /facilities/:id                              # Show facility
PATCH  /facilities/:id                              # Update facility
DELETE /facilities/:id                              # Deactivate facility
GET    /facilities/:id/available_slots?date=YYYY-MM-DD  # Get available slots
```

### Facility Booking (Guest)
```
POST   /facilities/:facility_id/bookings            # Create booking
GET    /bookings/facility                           # List my facility bookings
GET    /bookings/facility/:id                       # Show booking details
PATCH  /bookings/facility/:id/confirm               # Confirm (host)
PATCH  /bookings/facility/:id/cancel                # Cancel booking
PATCH  /bookings/facility/:id/complete              # Complete (after date)
```

### Facility Reviews
```
POST   /bookings/facility/:booking_id/reviews       # Create review
PATCH  /reviews/facility/:id/respond                # Host response
GET    /facilities/:id/reviews                      # List reviews
```

### Member Points
```
GET    /members/points                              # Get points balance
POST   /members/points/redeem                       # Redeem points
GET    /members/points/history                      # Points history
```

---

## Key Features

### 1. Time-Slot Based Booking
- Facilities operate on specific time slots (e.g., 60-minute intervals)
- Operating hours configurable per facility
- Automatic conflict prevention using database constraints

### 2. Dynamic Pricing & Discounts
- Base price + optional discount price
- Member tier discounts (Silver 10%, Gold 15%, Platinum 20%)
- Promotional pricing support

### 3. Idempotent Booking Creation
- Prevents duplicate bookings via `idempotency_key`
- Safe retry mechanism for failed requests

### 4. Loyalty Points System
- Earn points on completed bookings (1 point per $100)
- Points expire after 1 year
- Redeem points for discounts on future bookings
- FIFO redemption (oldest points first)

### 5. Review System
- Only completed bookings can be reviewed
- One review per booking
- Host response capability
- Visible/invisible moderation

### 6. Booking Lifecycle
```
pending → confirmed → completed → reviewed
    ↓         ↓
cancelled   cancelled
```

---

## Migration Guide

### Step 1: Run Migrations
```bash
rails db:migrate
```

This creates:
- `facilities` table
- `facility_bookings` table
- `facility_reviews` table
- `member_points` table
- Adds `guest_reviewed` and `host_reviewed` to existing `bookings` table

### Step 2: Seed Initial Data (Optional)
```ruby
# Create sample facilities for existing properties
Property.find_each do |property|
  Facility.create!(
    property: property,
    name: "Spa Package - 60 mins",
    facility_type: "spa",
    price: 150.00,
    duration_minutes: 60,
    slot_interval_minutes: 60,
    start_time: "09:00".to_time,
    end_time: "20:00".to_time,
    max_capacity: 1,
    active: true
  )
end
```

### Step 3: Update Routes
Add to `config/routes.rb`:
```ruby
resources :properties do
  resources :facilities, only: [:index, :show, :create, :update, :destroy] do
    get :available_slots, on: :member
    resources :bookings, only: [:create, :index, :show], controller: 'facility_bookings' do
      member do
        patch :confirm
        patch :cancel
        patch :complete
      end
    end
  end
end

resources :facility_bookings, only: [] do
  resource :review, only: [:create, :show], controller: 'facility_reviews'
end

resources :members, only: [] do
  collection do
    get :points
    post :redeem_points
  end
end
```

---

## Business Logic Examples

### Example 1: Guest Books a Spa Session
```ruby
# Controller action
def create
  facility = Facility.find(params[:facility_id])
  property = facility.property
  user = current_user
  host = property.host
  
  booking_date = Date.parse(params[:booking_date])
  start_time = params[:start_time] # "14:00"
  quantity = params[:quantity].to_i
  special_requests = params[:special_requests]
  
  @booking = FacilityBooking.create_safe_booking!(
    facility,
    property,
    user,
    host,
    booking_date,
    start_time,
    quantity,
    special_requests
  )
  
  if @booking.persisted?
    render json: { success: true, booking: @booking }, status: :created
  else
    render json: { success: false, errors: @booking.errors.full_messages }, status: :unprocessable_entity
  end
end
```

### Example 2: Host Confirms Booking
```ruby
def confirm
  @booking = FacilityBooking.find(params[:id])
  
  # Ensure only host can confirm
  unless @booking.host_id == current_user.id
    return render json: { error: "Unauthorized" }, status: :forbidden
  end
  
  @booking.confirm!
  render json: { success: true, booking: @booking }
end
```

### Example 3: Award Points After Completion
```ruby
# Background job runs daily
class CompleteFacilityBookingsJob < ApplicationJob
  def perform
    FacilityBooking.where(
      'booking_date < ? AND status = ?', 
      Date.today, 
      'confirmed'
    ).find_each do |booking|
      booking.complete!
    end
  end
end
```

### Example 4: Redeem Points for Discount
```ruby
def redeem
  points_to_redeem = params[:points].to_i
  user = current_user
  
  begin
    MemberPoint.redeem_points(user.id, points_to_redeem)
    discount_value = points_to_redeem * 0.01 # $0.01 per point
    
    render json: { 
      success: true, 
      message: "Successfully redeemed #{points_to_redeem} points",
      discount_value: discount_value
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: { 
      success: false, 
      error: e.message 
    }, status: :unprocessable_entity
  end
end
```

---

## Performance Optimizations

### 1. Database Indexes
All critical query paths are indexed:
- `facility_bookings(facility_id, booking_date, start_time)` - Availability checks
- `facility_bookings(user_id, booking_date)` - User booking history
- `facility_bookings(status)` - Status filtering
- `facility_bookings(idempotency_key)` - Unique constraint

### 2. Eager Loading
Dashboard queries use `.includes()` to prevent N+1:
```ruby
@facility_bookings = FacilityBooking
  .joins(:property)
  .where(properties: { host_id: @host.id })
  .includes(:facility, :guest)
```

### 3. Materialized Views (Future Enhancement)
For heavy analytics, consider materialized views:
```sql
CREATE MATERIALIZED VIEW mv_facility_revenue AS
SELECT 
  property_id,
  DATE(booking_date) as date,
  SUM(total_price) as daily_revenue,
  COUNT(*) as booking_count
FROM facility_bookings
WHERE status = 'completed'
GROUP BY property_id, DATE(booking_date);
```

---

## Security Considerations

### 1. Authorization
- Hosts can only manage their own properties' facilities
- Guests can only view/cancel their own bookings
- Implement Pundit or CanCanCan for robust authorization

### 2. Rate Limiting
Protect booking endpoints from abuse:
```ruby
# config/initializers/rack_attack.rb
Rack::Attack.throttle('bookings per minute', limit: 10, period: 1.minute) do |req|
  req.ip if req.path.start_with?('/facilities') && req.post?
end
```

### 3. Input Validation
All user inputs validated:
- Dates cannot be in the past
- Times must be within operating hours
- Quantity cannot exceed capacity
- Prices must be non-negative

---

## Testing Strategy

### Model Tests
```ruby
RSpec.describe FacilityBooking, type: :model do
  describe '#create_safe_booking!' do
    it 'prevents overlapping bookings' do
      facility = create(:facility, slot_interval_minutes: 60)
      
      create(:facility_booking, 
        facility: facility,
        booking_date: Date.today,
        start_time: '14:00'.to_time
      )
      
      expect {
        FacilityBooking.create_safe_booking!(
          facility,
          facility.property,
          create(:user),
          facility.property.host,
          Date.today,
          '14:00'.to_time,
          1
        )
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
```

### Request Tests
```ruby
RSpec.describe 'Facility Bookings API', type: :request do
  describe 'POST /facilities/:id/bookings' do
    it 'creates a booking with valid params' do
      facility = create(:facility)
      
      post facility_bookings_path(facility), params: {
        booking_date: Date.tomorrow.to_s,
        start_time: '10:00',
        quantity: 1
      }, headers: authentication_headers
      
      expect(response).to have_http_status(:created)
      expect(json['booking']['status']).to eq('pending')
    end
  end
end
```

---

## Future Enhancements

### Phase 2 Features
1. **Recurring Bookings**: Allow guests to book weekly/monthly slots
2. **Waitlist**: Notify guests when slots become available
3. **Dynamic Pricing**: Adjust prices based on demand
4. **Package Deals**: Bundle multiple facilities at discount
5. **Calendar Integration**: Sync with Google Calendar, iCal
6. **Mobile Notifications**: Push notifications for upcoming bookings
7. **Multi-language Support**: Internationalize facility descriptions

### Phase 3 Features
1. **AI Recommendations**: Suggest facilities based on guest preferences
2. **Resource Management**: Track staff assignments for facilities
3. **Inventory Integration**: Link spa products to treatments
4. **Advanced Analytics**: Revenue forecasting, occupancy heatmaps
5. **Channel Management**: Sync availability across booking platforms

---

## Conclusion

This facility booking integration transforms your Airbnb-style property booking engine into a comprehensive hotel management system capable of handling:
- ✅ Property accommodations (existing)
- ✅ Spa & wellness services
- ✅ Sports & recreational facilities
- ✅ Dining experiences
- ✅ Loyalty rewards program

The implementation maintains consistency with your existing database schema patterns while adding modern features like time-slot booking, dynamic pricing, and member points. The enhanced dashboards provide both hosts and guests with complete visibility into their facility-related activities.

**Next Steps:**
1. Run migrations: `rails db:migrate`
2. Implement controller actions for new endpoints
3. Add frontend UI for facility browsing and booking
4. Set up background jobs for automated completion
5. Configure member tier discounts based on your business rules
