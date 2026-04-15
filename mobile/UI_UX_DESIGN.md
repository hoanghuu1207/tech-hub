# TechHub - Thiết Kế UI/UX Flutter

## 📋 Tổng Quan Dự Án

**TechHub** là ứng dụng thương mại điện tử hiệu hiện đại chuyên mục sản phẩm công nghệ với tích hợp trợ lý AI tư vấn cá nhân hóa.

### Công Nghệ Sử Dụng:
- **Framework**: Flutter (Dart)
- **State Management**: BLoC Pattern
- **Architecture**: Clean Architecture
- **UI Components**: Material Design 3
- **Backend Communication**: REST API + WebSocket

---

## 🎨 Design System

### Color Palette
```
Primary: #0066FF (Tech Blue)
Secondary: #00D4FF (Cyan - AI Accent)
Success: #10B981 (Green)
Error: #EF4444 (Red)
Warning: #F59E0B (Amber)
Neutral: Grayscale (50 - 700)
```

### Spacing System
- xs: 4px
- sm: 8px
- md: 12px
- lg: 16px
- xl: 20px
- xxl: 24px
- xxxl: 32px

### Border Radius
- sm: 4px
- md: 8px
- lg: 12px
- xl: 16px
- full: 50px

### Typography
- **Headers**: Bold, 18-32px
- **Body**: Regular, 12-16px
- **Buttons**: Semi-bold, 12-16px

---

## 📱 Screens Architecture

### 1. **Auth Screens** (Xác thực)
#### LoginScreen
- Email/Password inputs
- Remember me checkbox
- Forgot password link
- Login button
- Register redirect

#### RegisterScreen (TODO)
- Full name, Email, Password inputs
- Email verification
- Terms & conditions
- Register button

#### ResetPasswordScreen (TODO)
- Email input
- OTP verification
- New password input

### 2. **Home Screen** (Trang chủ)
**Layout:**
```
AppBar (User greeting + Notifications)
├── Search Bar (Text + Voice input)
├── Banner Carousel (Flash sales, Promotional)
├── Quick Categories (Grid 4 columns)
├── Trending Products (Grid 2 columns)
└── FAB: AI Chat Assistant
```

**Features:**
- Real-time carousel pagination
- Category navigation
- Product quick view
- Add to cart direct
- Notification badge

### 3. **Search Screen** (Tìm kiếm)
**Features:**
- Text search with autocomplete
- Voice search (Whisper API)
- Image search upload
- Filter options (Price, Rating, Category)
- Sort options (Popularity, Price, Rating)
- Search history
- Recent searches

### 4. **Product List Screen** (Danh sách sản phẩm)
**Layout:**
```
AppBar (Category name)
├── Filter/Sort controls
├── Product Grid (2 columns)
│   └── ProductCard (Image, Name, Price, Rating, Add to cart)
└── Pagination / Load more
```

**Features:**
- Lazy loading
- Infinite scroll
- Real-time filter
- Dynamic sorting
- Stock indicators

### 5. **Product Detail Screen** (Chi tiết sản phẩm)
**Sections:**
```
Image Carousel + Stock indicator
├── Product Info (Name, Price, Rating, Reviews count)
├── Spec Tabbed View
│   ├── Technical Specs
│   ├── About Product
│   └── Warranty Info
├── Reviews Section
│   ├── Average rating stars
│   └── Recent reviews (Avatar, Name, Rating, Comment)
├── Related Products
├── Action Buttons
│   ├── Add to Cart
│   ├── Buy Now
│   └── Compare
└── Chat Button (Ask AI)
```

**Interactive Features:**
- Image zoom
- Spec comparison view
- Rating filter in reviews
- Share product
- AI recommendation for similar products

### 6. **Product Comparison Screen** (So sánh sản phẩm) - TODO
**Features:**
- Side-by-side spec comparison
- Price vs features analysis
- AI recommendation
- Add/Remove products from comparison

### 7. **Cart Screen** (Giỏ hàng)
**Layout:**
```
AppBar
├── Cart Items List
│   └── CartItem component
│       ├── Product Image
│       ├── Name + Price
│       └── Quantity controls + Remove
├── Promo Code / Discount
├── Order Summary
│   ├── Subtotal
│   ├── Shipping Fee
│   ├── Tax
│   └── Total
└── Checkout Button
```

**Features:**
- Quantity adjustment (+/-)
- Swipe to remove
- Save for later
- Apply coupon code
- Order summary breakdown

### 8. **Checkout Screen** (Thanh toán) - TODO
**Steps:**
1. **Shipping Address** - Address selection/input
2. **Shipping Method** - Express/Standard/Economy
3. **Payment Method** - PayOS integration
4. **Order Review** - Final confirmation
5. **Order Success** - Order number + tracking

### 9. **Order History Screen** (Lịch sử đơn hàng) - TODO
**Features:**
- Order list with status
- Order details view
- Track shipment
- Cancel order option
- Reorder button

### 10. **Chat Screen** (Trợ lý AI)
**Layout:**
```
AppBar (AI Assistant title)
├── Chat Messages Container
│   ├── User Message (Right aligned, Blue)
│   └── AI Message (Left aligned, Gray + Icon)
├── Quick Suggestions (Pills)
└── Input Area
    ├── Text Input
    ├── Mic Button (Voice input)
    └── Send Button
```

**AI Capabilities:**
- Product search by description
- Product comparison assistant
- Price negotiation hints
- Stock availability check
- Add to cart via chat
- Auto-navigate to product

**Message Types:**
- Text responses
- Product recommendation cards
- Comparison tables
- Interactive actions (Add to cart, View product, etc.)

### 11. **Profile Screen** (Tài khoản) - TODO
**Sections:**
```
User Card (Avatar, Name, Member Status)
├── Personal Info
│   ├── Edit profile
│   ├── Change password
│   └── Email/Phone management
├── My Orders
├── Wishlist / Saved items
├── Addresses
├── Payment Methods
├── Preferences
│   ├── Search history
│   └── Recommendations settings
├── Support
└── Logout
```

---

## 🧩 Reusable Components

### Buttons
- `AppButton` - Primary button with loading state
- `AppTextButton` - Text button (secondary)
- `AppOutlinedButton` - Outlined button

### Input
- `AppTextField` - Configurable text input with validators
- `AppSearchBar` - Search with voice input option

### Cards
- `ProductCard` - Product preview card
  - Image with discount badge
  - Quick add to cart
  - Out of stock overlay

### Navigation
- `AppAppBar` - Custom AppBar
- `AppHomeAppBar` - Home screen AppBar with user info

### Indicators
- `RatingBar` - Stars rating display/input
- `LoadingShimmer` - Loading animation
- `ProductCardShimmer` - Product card skeleton

### Layout
- Carousel with indicators
- Grid layout (responsive)
- List builders with lazy loading
- Tab controllers for product specs

---

## 📊 BLoC States & Events

### AuthBloc
```
Events: Login, Register, Logout, CheckAuth
States: Initial, Loading, Success, Failure, Unauthenticated
```

### ProductBloc
```
Events: FetchTrending, FetchByCategory, Search, FetchDetail
States: Initial, Loading, Success, Failure
```

### CartBloc
```
Events: AddItem, RemoveItem, UpdateQuantity, Clear
States: CartInitial, CartUpdated
```

### ChatBloc
```
Events: Initialize, SendMessage, VoiceMessage, LoadHistory, Clear
States: Initial, Loading, Connected, MessageAdded, Failure
```

---

## 🌐 Navigation Structure

```
/
├── /splash
├── /login
├── /register
├── /reset-password
├── /home
│   ├── /search
│   ├── /products
│   ├── /products-by-category/{categoryName}
│   ├── /product-detail/{productId}
│   ├── /compare
│   ├── /cart
│   ├── /checkout
│   ├── /orders
│   ├── /chat
│   └── /profile
```

---

## 🚀 Deployment Checklist

- [ ] Fix all linting errors
- [ ] Add proper error handling
- [ ] Implement remaining screens
- [ ] Complete AI integration
- [ ] Payment gateway setup
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] App signing & versioning
- [ ] Store submission preparation

---

## 📝 API Endpoints Integration

```
Auth:
POST /auth/login
POST /auth/register
POST /auth/verify-email
POST /auth/forgot-password
POST /auth/reset-password

Products:
GET /products/trending
GET /products?category=...&sort=...&page=...
GET /products/search?q=...
GET /products/{id}
POST /products/compare
GET /products/{id}/reviews

Orders:
POST /orders
GET /orders
GET /orders/{id}
PUT /orders/{id}/cancel

Chat:
WS /chat/ws?token=...
```

---

## 💡 Future Enhancements

1. **Wishlist System** - Save favorite products
2. **User Reviews** - Upload product reviews with images
3. **Social Sharing** - Share products to social media
4. **Push Notifications** - Order updates, promotions
5. **Offline Mode** - Cache products for offline browsing
6. **Advanced Analytics** - View browsing history & AI recommendations
7. **Video Tutorials** - Product setup guides
8. **Augmented Reality** - Visualize products in real environment

---

**Version**: 1.0.0  
**Last Updated**: 2026-04-05  
**Author**: TechHub Development Team
