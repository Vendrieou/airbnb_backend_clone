# Review & Rating System Implementation

## Overview
Complete implementation of Airbnb-style review and rating system with multi-dimensional ratings, moderation capabilities, and automatic average calculation.

## Features Implemented

### 1. Multi-Dimensional Ratings
- **Overall Rating** (1-5 stars)
- **Cleanliness Rating** (1-5 stars)
- **Accuracy Rating** (1-5 stars)
- **Communication Rating** (1-5 stars)
- **Location Rating** (1-5 stars)
- **Check-in Rating** (1-5 stars)
- **Value Rating** (1-5 stars)

### 2. Two-Way Reviews
- Guest reviews for properties
- Host responses to guest reviews
- Prevents duplicate reviews per booking

### 3. Moderation System
- Flag reviews for inappropriate content
- Admin approval workflow
- Automatic hiding of flagged reviews
- Review deletion (admin only, flagged reviews)

### 4. Automatic Calculations
- Property average rating updated on review create/update/delete
- Review count tracking via counter cache
- Overall rating calculated from dimension averages

### 5. Validation Rules
- Reviews only allowed after checkout (end_date < today)
- Minimum comment length: 10 characters
- Maximum comment length: 5000 characters
- All ratings must be integers between 1-5
- One review per booking per user type (guest/host)

## Files Created

### Database Migration
```
db/migrate/20240402100000_create_reviews.rb
```
Creates `reviews` table with all rating dimensions, moderation fields, and indexes.
Adds `average_rating` and `review_count` columns to `properties`.
Adds `guest_reviewed` and `host_reviewed` flags to `bookings`.

### Models
```
app/models/review.rb
```
- Complete validation logic
- Scopes: `visible`, `guest_reviews`, `host_responses`, `flagged`, `recent`
- Methods: `calculated_overall`, `flag!`, `approve!`, `respond_by_host`
- Callbacks for automatic property rating updates

### Services
```
app/services/review_creator.rb
```
Service object pattern for creating reviews with:
- Booking completion validation
- Duplicate prevention
- Rating validation
- Transaction safety

### Controllers
```
app/controllers/reviews_controller.rb
```
RESTful endpoints:
- `GET /properties/:property_id/reviews` - List property reviews
- `POST /bookings/:booking_id/reviews` - Create new review
- `PUT /reviews/:id` - Update review
- `DELETE /reviews/:id` - Delete review (admin/flagged only)
- `POST /reviews/:id/flag` - Flag for moderation
- `POST /reviews/:id/approve` - Approve flagged review (admin)
- `POST /reviews/:id/respond` - Host response

### Tests
```
test/models/review_test.rb
test/services/review_creator_test.rb
```
Comprehensive test coverage including:
- Valid review creation
- Rating range validation
- Comment length validation
- Checkout date validation
- Duplicate prevention
- Average rating calculations
- Moderation workflows
- Host responses

## Usage Examples

### Creating a Review (Guest)
```ruby
ratings = {
  cleanliness: 5,
  accuracy: 5,
  communication: 5,
  location: 4,
  check_in: 5,
  value: 5
}

result = catch(:halt) do
  ReviewCreator.new(
    booking,
    current_user.id,
    ratings,
    "Amazing stay! Highly recommend.",
    is_guest_review: true
  ).call
end

if result[:success]
  puts "Review created: #{result[:review].id}"
else
  puts "Error: #{result[:error]}"
end
```

### Getting Property Reviews
```ruby
@property = Property.find(1)
@reviews = @property.reviews.visible.includes(:guest).order(created_at: :desc)
puts "Average Rating: #{@property.average_rating}"
puts "Total Reviews: #{@property.review_count}"
```

### Host Response
```ruby
review = Review.find(1)
review.respond_by_host("Thank you for staying with us!")
```

### Moderation
```ruby
# Flag a review
review.flag!("Inappropriate language")

# Approve a flagged review (admin)
review.approve!
```

## API Request Examples

### POST /bookings/:booking_id/reviews
```json
{
  "review": {
    "comment": "Great property, exactly as described!",
    "ratings": {
      "cleanliness": 5,
      "accuracy": 5,
      "communication": 5,
      "location": 4,
      "check_in": 5,
      "value": 5
    }
  }
}
```

### GET /properties/:property_id/reviews
Response:
```json
{
  "property": {...},
  "reviews": [...],
  "average_rating": 4.67,
  "review_count": 23
}
```

### POST /reviews/:id/flag
```json
{
  "reason": "Spam or fake review"
}
```

## Database Schema

### reviews table
| Column | Type | Description |
|--------|------|-------------|
| property_id | integer | Reference to property |
| booking_id | integer | Reference to booking |
| guest_id | integer | Guest user ID |
| host_id | integer | Host user ID |
| overall_rating | integer | 1-5 stars |
| cleanliness_rating | integer | 1-5 stars |
| accuracy_rating | integer | 1-5 stars |
| communication_rating | integer | 1-5 stars |
| location_rating | integer | 1-5 stars |
| check_in_rating | integer | 1-5 stars |
| value_rating | integer | 1-5 stars |
| comment | text | Review text |
| is_guest_review | boolean | True if by guest |
| is_response | boolean | True if host response |
| parent_review_id | integer | Parent review for responses |
| is_visible | boolean | Published status |
| is_flagged | boolean | Moderation flag |
| flagged_at | datetime | When flagged |
| flag_reason | string | Reason for flagging |

### properties table (added columns)
| Column | Type | Default |
|--------|------|---------|
| average_rating | decimal(3,2) | 0.0 |
| review_count | integer | 0 |

### bookings table (added columns)
| Column | Type | Default |
|--------|------|---------|
| guest_reviewed | boolean | false |
| host_reviewed | boolean | false |

## Next Steps

1. **Email Notifications**: Send emails when reviews are received
2. **Review Reminders**: Automated reminders for guests to review after checkout
3. **Review Analytics**: Dashboard for hosts to track ratings over time
4. **Photo Uploads**: Allow guests to attach photos to reviews
5. **Helpful Votes**: Let users mark reviews as helpful
6. **Search Filtering**: Filter properties by minimum rating
7. **Superhost Badge**: Award badges to hosts with consistently high ratings

## Benefits

✅ Builds trust between guests and hosts  
✅ Improves search ranking with rated properties  
✅ Provides feedback for hosts to improve  
✅ Reduces fraud through verified stay reviews  
✅ Increases booking conversion with social proof  
✅ Enables quality-based filtering  
