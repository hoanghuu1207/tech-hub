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

### BUG CHATBOT
- [] Khi hỏi sản phẩm, nó sẽ list ra danh sách sản phẩm, sau đó tôi hỏi sản phẩm khác, vì lưu context nên nó lại lấy các sản phẩm đã list ra để search. (Ví dụ: tai nghe dưới 200k, nó sẽ list ra các tai nghe có giá từ 90 -> 200k, sau đó tôi tiếp tục hỏi tai nghe dưới 50k, thì nó lại trả lời không có, mặc dù có tai nghe dưới 50k trong db).
- [x] Xem chi tiết sản phẩm, sau khi xác nhận xem chi tiết thì nó ngay lập tức chuyển sang màn product detail và đóng bottomsheet chatbot, tôi muốn nó chuyển màn nhưng không đóng bottomsheet, ở mọi màn trong app đều có icon chatbot ở home để có thể mở lại.
- [x] Khi mở bottomsheet thì nó lại scroll ở trên, tôi muốn scroll xuống dưới cùng của đoạn chat.
- [] Sau khi xác nhận thah toán, nó ngay lập tức gọi hàm tạo order và sang màn chứa webview payos, và không điền 1 thông tin gì về thông tin user mua hàng. Tôi muốn nếu thanh toán từ giỏ hàng(proceed_to_checkout), thì sẽ yêu cầu user nhập thông tin trước, khi ấn thanh toán ở bottomsheet chatbot thì sẽ giống logic nút đặt hàng & thanh toán ở tab giỏ hàng. Nếu mua hàng trực tiếp buy_product thì sẽ yêu cầu user nhập thông tin trước, nhưng ở đây sẽ chuyển sang màn buy_now_checkout_screen, logic tiếp theo tương tự. 