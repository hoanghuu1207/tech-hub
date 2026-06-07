- [] giá rẻ nhất
- [] fix phần hỏi đơn hàng, hiện tại đang yêu cầu mã đơn hàng.
- [x] ở tab cart, các item sẽ có 1 checkbox ở bên trái, bấm vào để chọn sp, nút xóa tất cả thay bằng xóa, nút xóa và đặt hàng & thanh toán chỉ enable khi có ít nhất 1 item được chọn ở checkbox, có một checkbox all nằm ở phía trên cùng của danh sách items. (Lưu ý khi xóa hoặc đặt thì nếu item đó có nhiều quantity sẽ phải xóa hoặt đặt hết số lượng item đó). Hiển thị item cart thêm thông tin màu sắc đã mua.
- [x] webview thanh toán payos, khi thanh toán thành công redirect về trang chi tiết đơn hàng
- [x] Phát triển tính năng khi sản phẩm đã thanh toán, và hết hàng (nghĩa là quantity = 0), thì ở giỏ hàng của những tài khoản đã thêm sẽ disable item đó đi. Và thêm post notification tới các tài khoản đã thêm sản phẩm đó, báo cho họ biết là sản phẩm vừa rồi đã hết hàng. Hãy kiểm tra xem logic api đã xử lý phần thêm sản phẩm hết hàng vào cart chưa (theo quan sát của tôi là chưa), và mua sản phẩm hết hàng thì sẽ trả về response là sản phẩm đã hết hàng.
- [] App thêm phần tự điền infor user khi thanh toán(nếu có thông tin).
- [] Làm carousel hot deal.
- [] Nghiên cứu phần shipping.
- [x] Làm icon thông báo.
- [] Check phần hủy đơn hàng. Tự động hủy sau khi hết hạn thanh toán.
- [] Nói chuyện với chatbot.
- [] Sửa lại phần label chờ thanh toán, đã thanh toán, đang xử lý, hoàn thành, đã hủy. Xử lý luôn cả ở màn order detail.
- [] Check push notification with ios.

### ADMIN ###
- [] Thống kê sản phẩm bán chạy, top sản phẩm xem nhiều, đơn hàng thanh toán, thất bại...
- [] Set thông báo đến user hot deal...

### PAYOS ###
- [] Thay tài khoản Payos