# 🚀 TechHub - Flutter E-commerce Mobile App

Ứng dụng thương mại điện tử hiện đại chuyên mục thiết bị công nghệ với tích hợp trợ lý AI tư vấn cá nhân hóa.

## 📁 Cấu Trúc Project

```
lib/
├── main.dart                 # Entry point + routing + theme
├── bloc/                     # State management (BLoC pattern)
│   ├── auth_bloc.dart       # Authentication BLoC
│   ├── product_bloc.dart    # Product management BLoC
│   ├── cart_bloc.dart       # Shopping cart BLoC
│   ├── chat_bloc.dart       # AI chat BLoC
│   └── index.dart           # Exports
├── models/                   # Data models
│   ├── user_model.dart
│   ├── product_model.dart
│   ├── cart_model.dart
│   ├── order_model.dart
│   ├── chat_model.dart
│   ├── review_model.dart
│   ├── category_model.dart
│   └── index.dart
├── services/                 # API & business logic
│   ├── api_service.dart     # HTTP client
│   ├── auth_service.dart    # Authentication
│   ├── product_service.dart # Product API calls
│   ├── order_service.dart   # Order API calls
│   ├── chat_service.dart    # WebSocket chat
│   └── index.dart
├── screens/                  # UI Screens
│   ├── auth_screen.dart     # Login/Register
│   ├── home_screen.dart     # Dashboard
│   ├── chat_screen.dart     # AI Assistant
│   ├── cart_screen.dart     # Shopping cart
│   └── index.dart
├── widgets/                  # Reusable components
│   ├── app_button.dart      # Button variants
│   ├── app_text_field.dart  # Text input
│   ├── product_card.dart    # Product preview
│   ├── app_bar.dart         # Custom AppBars
│   ├── rating_bar.dart      # Star rating
│   ├── loading_shimmer.dart # Loading animation
│   └── index.dart
└── utils/                    # Helpers & constants
    ├── constants.dart       # Colors, spacing, radius
    ├── formatters.dart      # Number, date formatting
    ├── validators.dart      # Form validation
    ├── snackbars.dart       # Toast notifications
    └── index.dart
```

## 🎨 Design Features

### Color Scheme
- **Primary**: #0066FF (Tech Blue)
- **Secondary**: #00D4FF (Cyan)
- **Success**: #10B981
- **Error**: #EF4444

### Typography
- **Bold**: 600-700 weight
- **Headers**: 18-32px
- **Body**: 12-16px

### Spacing & Radius
- Consistent 4px-32px spacing system
- Rounded 4px-16px border radius
- Box shadows for depth

## 📱 Screens Implemented

### ✅ Completed
- **Login Screen** - Email/password authentication
- **Home Screen** - Dashboard with trending products & categories
- **Chat Screen** - AI assistant interface
- **Cart Screen** - Shopping cart with quantity controls

### 🚧 To Be Implemented
- Product List with filtering & sorting
- Product Detail with specs & reviews
- Search with voice input
- Checkout & Payment
- Order Tracking
- Profile Management
- Product Comparison

## 🔧 State Management (BLoC)

### AuthBloc
```dart
Events: AuthLoginRequested, AuthRegisterRequested, AuthLogoutRequested
States: AuthInitial, AuthLoading, AuthSuccess, AuthFailure, AuthUnauthenticated
```

### ProductBloc
```dart
Events: FetchTrendingProductsRequested, FetchProductsByCategoryRequested
States: ProductInitial, ProductLoading, ProductsLoadedSuccess, ProductFailure
```

### CartBloc
```dart
Events: CartAddItemRequested, CartRemoveItemRequested, CartUpdateQuantityRequested
States: CartInitial, CartUpdated
```

### ChatBloc
```dart
Events: ChatInitializeRequested, ChatMessageSent, ChatMessageReceived
States: ChatInitial, ChatLoading, ChatConnected, ChatFailure
```

## 📦 Dependencies

### State Management
- `flutter_bloc: ^8.1.0`
- `bloc: ^8.1.0`
- `equatable: ^2.0.5`

### UI Components
- `flutter_svg: ^2.0.0`
- `carousel_slider: ^4.2.1`
- `cached_network_image: ^3.3.0`
- `badges: ^3.1.0`
- `shimmer: ^3.0.0`

### API & DataCareer
- `http: ^1.1.0`
- `dio: ^5.0.0`
- `web_socket_channel: ^2.4.0`
- `shared_preferences: ^2.2.0`

### Utilities
- `intl: ^0.19.0`
- `uuid: ^4.0.0`
- `flutter_dotenv: ^5.0.2`
- `image_picker: ^1.0.0`
- `speech_to_text: ^6.3.0`

## 🚀 Getting Started

### Prerequisites
- Flutter SDK >= 3.0.0
- Android Studio / Xcode
- Git

### Installation Steps

1. **Clone repository**
```bash
git clone https://github.com/yourusername/techhub-mobile.git
cd techhub-mobile
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Create .env file**
```bash
cp .env.example .env
# Edit .env with your API credentials
```

4. **Generate code (if using codegen)**
```bash
flutter pub run build_runner build
```

5. **Run app**
```bash
flutter run
```

## 🏗️ Architecture

### Clean Architecture Layers
```
Presentation (Screens + BLoC)
    ↓
Domain (Models + Interfaces)
    ↓
Data (Services + API)
```

### Data Flow Example (Add to Cart)
```
UI (CartScreen) 
  ↓ 
BLoC (CartBloc.add(CartAddItemRequested))
  ↓
Service (CartBloc handles event)
  ↓
Model (CartItem created)
  ↓
State (CartUpdated emitted)
  ↓
UI (Rebuilds with new cart)
```

## 🔐 Authentication

### Auth Flow
1. User enters email/password
2. AuthService.login() calls API
3. Token stored in SharedPreferences
4. AuthBloc updates state
5. App navigates to Home

### Token Management
- JWT tokens stored locally
- Auto-refresh on expiry
- Logout clears all data

## 💬 AI Chat Integration

### WebSocket Connection
```dart
// Automatic connection on chat init
ChatBloc.add(ChatInitializeRequested())

// Real-time message handling
WebSocket listens for:
- Message(text response)
- Action(search, compare, add_to_cart)
- Error(error messages)
```

### Supported AI Actions
- Product search
- Product comparison
- Add to cart
- Price consultation
- Auto-navigation to product

## 🧪 Testing

### Unit Tests
```bash
flutter test
```

### Widget Tests
```bash
flutter test --coverage
```

### Integration Tests
```bash
flutter drive --target=test_driver/app.dart
```

## 📊 API Base Endpoints

```
Base URL: http://localhost:8000/api/v1
WebSocket: ws://localhost:8000/chat/ws

Auth:
  POST   /auth/login
  POST   /auth/register
  POST   /auth/refresh

Products:
  GET    /products/trending
  GET    /products?category={cat}&page={page}
  GET    /products/{id}
  POST   /products/compare

Orders:
  POST   /orders
  GET    /orders
  GET    /orders/{id}

Chat:
  WS     /chat/ws?token={token}
```

## 🎯 Feature Roadmap

### Phase 1 (Current)
- ✅ Core navigation
- ✅ Authentication UI
- ✅ Product browsing
- ✅ Shopping cart
- ⚠️ AI Chat interface (backend pending)

### Phase 2
- Product search
- Wishlist
- Order management
- Payment integration (PayOS)

### Phase 3
- Push notifications
- Offline mode
- Social sharing
- Advanced analytics

## 🐛 Known Issues

- Web socket chat pending backend implementation
- Some screens are placeholders (TODO)
- Payment gateway not yet integrated

## 📝 Environment Variables

Create `.env` file:
```
API_URL=http://localhost:8000/api/v1
OPENAI_API_KEY=your_key_here
PAYOS_CLIENT_ID=your_client_id
PAYOS_API_KEY=your_api_key
ENV=development
```

## 📚 Documentation

- [UI/UX Design](UI_UX_DESIGN.md) - Detailed design system
- [API Documentation](docs/API.md) - Backend endpoints
- Flutter: https://flutter.dev/docs

## 👥 Contributing

1. Create feature branch (`git checkout -b feature/amazing-feature`)
2. Commit changes (`git commit -m 'Add amazing feature'`)
3. Push to branch (`git push origin feature/amazing-feature`)
4. Open Pull Request

## 📄 License

This project is licensed under MIT License - see LICENSE file.

## 👨‍💻 Author

**Huỳnh Hữu Hoàng**
- Student ID: 102220063
- University: Bach Khoa University
- Advisor: TS. Lê Thị Mỹ Hạnh

## 📞 Support

For issues & questions:
- Create GitHub Issue
- Contact: huynhhoangnc@example.com

---

**Version**: 1.0.0  
**Last Updated**: 2026-04-05  
**Status**: In Development 🚧
