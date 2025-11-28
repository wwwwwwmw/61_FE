# Hướng Dẫn Sử Dụng Ứng Dụng

## 🚀 Khởi Chạy Ứng Dụng

### Flutter App

```bash
cd c:\Users\ASUS\Documents\61\ung_dung_tien_ich
flutter run -d chrome
```

Hoặc trên Android/iOS emulator:
```bash
flutter devices              # Xem danh sách devices
flutter run -d <device-id>   # Chạy trên device cụ thể
```

### Backend API (Tùy chọn - để kết nối thật)

```bash
cd c:\Users\ASUS\Documents\61\ung_dung_tien_ich\backend

# Cài đặt dependencies (lần đầu)
npm install

# Tạo file .env
copy .env.example .env
# Sau đó sửa thông tin database trong .env

# Khởi tạo database (lần đầu)
npm run init-db

# Chạy server
npm run dev
```

## 📱 Sử Dụng Ứng Dụng

### 1. Đăng Nhập / Đăng Ký
- Mở app, bạn sẽ thấy màn hình đăng nhập đẹp mắt với gradient tím-hồng
- Nhập email và mật khẩu bất kỳ (hiện tại là mock data)
- Click "Đăng ký" để tạo tài khoản mới
- Hoặc "Đăng nhập" nếu đã có tài khoản

### 2. Trang Chủ - Bottom Navigation

Sau khi đăng nhập, bạn có 4 tab chính:

#### 📋 **Tab 1: Công việc (Todos)**
- Xem danh sách công việc với:
  - Checkbox để đánh dấu hoàn thành
  - Badge màu cho độ ưu tiên (Đỏ=Cao, Cam=Trung bình, Xám=Thấp)
  - Ngày hạn hoàn thành
  - Mô tả chi tiết
- Click vào checkbox để đánh dấu hoàn thành (text sẽ gạch ngang)
- Nút "+" để thêm công việc mới

#### 💰 **Tab 2: Chi tiêu (Expenses)**
- **Summary Card** với gradient tím:
  - Số dư hiện tại (Thu nhập - Chi tiêu)
  - Tổng thu nhập (màu xanh, mũi tên xuống)
  - Tổng chi tiêu (màu đỏ, mũi tên lên)
- **Danh sách giao dịch**:
  - Icon danh mục với màu sắc riêng
  - Số tiền (+ cho thu nhập, - cho chi tiêu)
  - Ngày giờ giao dịch
  - Mô tả
- Nút "+" để thêm giao dịch mới

#### ⏱️ **Tab 3: Sự kiện (Events)**
- Xem danh sách sự kiện sắp tới
- **Countdown timer** cho mỗi sự kiện:
  - Số ngày còn lại
  - Số giờ còn lại  
  - Số phút còn lại
- Icon và màu sắc riêng cho từng loại sự kiện:
  - 🎂 Sinh nhật (hồng)
  - 📚 Deadline (xanh dương)
  - ❤️ Kỷ niệm (đỏ)
- Hiển thị ngày chính xác của sự kiện
- Nút "+" để thêm sự kiện mới

#### ⚙️ **Tab 4: Cài đặt (Settings)**
- **Profile card** với gradient tím:
  - Avatar
  - Tên người dùng
  - Email
- **Chức năng**:
  - 🌙 **Dark Mode toggle**: Bật/tắt chế độ tối
  - 🔄 Đồng bộ dữ liệu
  - ☁️ Sao lưu
  - ℹ️ Thông tin ứng dụng
  - 🚪 **Đăng xuất**: Thoát tài khoản

### 3. Chế độ Dark/Light Theme
- Vào tab "Cài đặt"
- Bật/tắt switch "Chế độ tối"
- Toàn bộ app sẽ chuyển theme ngay lập tức
- Theme được lưu tự động, mở lại app sẽ giữ nguyên theme đã chọn

## 🎨 Tính Năng Nổi Bật

### UI/UX Đẹp Mắt
✅ Material Design 3
✅ Google Fonts (Inter)
✅ Gradient backgrounds
✅ Shadow & elevation
✅ Rounded corners
✅ Icons màu sắc
✅ Smooth animations

### Responsive Design
✅ Hoạt động tốt trên mọi kích thước màn hình
✅ Scrollable lists
✅ Adaptive layouts

### User Experience
✅ Bottom navigation rõ ràng
✅ FAB buttons dễ thấy
✅ Color coding cho dữ liệu
✅ Loading states
✅ Error messages

## 🔧 Tùy Chỉnh

### Thay đổi API URL
Mở `lib/core/constants/app_constants.dart`:
```dart
static const String baseUrl = 'http://YOUR_SERVER:3000/api';
```

### Thời gian đồng bộ
```dart
static const Duration syncInterval = Duration(minutes: 5);
```

## 🐛 Xử Lý Lỗi

### App không chạy
```bash
flutter clean
flutter pub get
flutter run -d chrome
```

### Database lỗi
- Xóa app và cài lại
- Hoặc xóa SharedPreferences data

### Theme không đổi
- Kiểm tra Settings -> Dark Mode toggle
- Restart app nếu cần

## 📊 Dữ Liệu Mẫu

App hiện có dữ liệu mẫu để demo:

**Todos:**
- Hoàn thành báo cáo đồ án (Cao)
- Mua sắm cuối tuần (Trung bình)
- Tập thể dục (Thấp, đã hoàn thành)

**Expenses:**
- -150,000₫: Ăn trưa
- -50,000₫: Grab  
- +5,000,000₫: Lương tháng 11

**Events:**
- Sinh nhật mẹ (15 ngày nữa)
- Deadline đồ án (7 ngày nữa)
- Kỷ niệm 1 năm (30 ngày nữa)

## 🚀 Tích Hợp Backend Thật

1. Chạy PostgreSQL database
2. Chạy Node.js server (xem hướng dẫn trên)
3. Cập nhật `baseUrl` trong app
4. Restart app
5. Đăng ký tài khoản mới
6. Dữ liệu sẽ được lưu vào database thật!

---

**Chúc bạn sử dụng app vui vẻ! 🎉**
