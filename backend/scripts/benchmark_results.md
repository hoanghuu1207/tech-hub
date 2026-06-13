# KẾT QUẢ BENCHMARK THỰC TẾ - TechHub
**Thời gian chạy:** 2026-06-13 03:11:39

## 1. Hiệu năng API (Thời gian phản hồi thực tế)

| API | Thời gian phản hồi | Ghi chú |
|-----|-------------------|---------|
| Auth (đăng nhập) | 358ms | ⚡ Trung bình |
| Catalog (danh mục) | 63ms | ✅ Nhanh |
| Catalog (danh sách SP) | 89ms | ✅ Nhanh |
| Cart (xem giỏ) | 47ms | ✅ Nhanh |
| Orders (danh sách) | 46ms | ✅ Nhanh |

## 2. Đánh giá tìm kiếm ngữ nghĩa AI

**Tổng độ chính xác: 100% (10/10)**
**Thời gian phản hồi trung bình: 2270ms**

| # | Truy vấn | Loại | Kết quả Top-1 | Thời gian | Đúng? |
|---|---------|------|---------------|-----------|-------|
| 1 | laptop gaming dưới 20 triệu | Truy vấn NLP cơ bản | Laptop Dell 15 DC15250 H02DF - Nhập... | 2780ms | ✅ |
| 2 | điện thoại chụp ảnh đẹp pin trâu | Truy vấn NLP mô tả tính năng | Điện thoại OPPO | 2112ms | ✅ |
| 3 | tai nghe chống ồn | Truy vấn NLP ngắn | Tai nghe chụp tai chống ồn Apple Ai... | 2024ms | ✅ |
| 4 | ip 15 pro max | Tiếng lóng / viết tắt | iPhone 15 Pro Max 2TB | 1919ms | ✅ |
| 5 | máy tính bảng cho trẻ em | Truy vấn NLP ngữ cảnh | Samsung Galaxy Tab A11 Wifi 4GB 64G... | 2142ms | ✅ |
| 6 | đồng hồ thông minh theo dõi sức khỏe | Truy vấn NLP dài | Đồng hồ thông minh Garmin Forerunne... | 2154ms | ✅ |
| 7 | laptop mỏng nhẹ cho sinh viên | Truy vấn theo nhu cầu | Laptop Dell 15 DC15250 H5YXJ - Nhập... | 3264ms | ✅ |
| 8 | samsung galaxy s24 | Truy vấn tên sản phẩm | Samsung Galaxy S24 Plus 12GB 256GB | 2352ms | ✅ |
| 9 | airpods | Truy vấn tên sản phẩm ngắn | Tai nghe Bluetooth Apple AirPods Pr... | 2086ms | ✅ |
| 10 | điện thoại giá 3 triệu | Truy vấn kèm giá | Xiaomi 17T 5G | 1871ms | ✅ |

## 3. Đánh giá Chatbot Function Calling

**Thời gian phản hồi trung bình: 2216ms**

| # | Tin nhắn | Intent trả về | Thời gian |
|---|---------|--------------|-----------|
| 1 | Tìm cho tôi iPhone | product_search | 4963ms |
| 2 | Xem chi tiết sản phẩm đầu tiên | product_detail | 2470ms |
| 3 | Đang có khuyến mãi gì không? | general_knowledge | 1723ms |
| 4 | Xem giỏ hàng | general_knowledge | 878ms |
| 5 | Cho tôi xem đơn hàng | general_knowledge | 1047ms |