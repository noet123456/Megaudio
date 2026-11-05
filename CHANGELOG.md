# Changelog

Mỗi mục tương ứng một bản build và được dùng làm release notes trên GitHub.

## v1.10.3+20
- Chuyển bài khi đang phát nhanh và ổn định hơn, kể cả khi chọn bài khác trong danh sách.
- Thanh thông báo hiển thị rõ tên bài, ca sĩ và các nút điều khiển trên mọi ảnh bìa.
- Thanh tiến trình phát mượt hơn và không làm chậm thao tác trên thư viện.
- Cài đè bản cũ như bình thường, giữ nguyên thư viện, EQ và lịch sử nghe.

## v1.10.2+19
- Khung thông báo nhạc: nút điều khiển hiển thị rõ trên mọi ảnh bìa, kể cả bìa sáng màu.
- Tên bài và tên ca sĩ dễ đọc hơn nhờ nền thông báo tương phản theo ảnh bìa.
- Khung thông báo giữ nguyên khi tạm dừng phát.

## v1.10.1+18
- Thêm công tắc chuyển DSD sang PCM trong DSP: tắt để phát DSD gốc trên thiết bị/DAC hỗ trợ, bật để nghe được trên mọi máy.
- EQ có sẵn các profile theo thể loại: Rock, Pop, Jazz, Classical, Hip-Hop, Electronic, Acoustic, Vocal, Bass+ và Treble+.
- Có thể lưu dải tần hiện tại thành profile EQ riêng, ghi đè hoặc xoá profile tự tạo.
- Profile đã chọn và dải tần được ghi nhớ giữa các lần mở app.

## v1.10.0+17
- Phát được file DSD (.dsf) trên mọi thiết bị (máy không hỗ trợ DSD vẫn nghe được).
- Hiển thị tiến trình chuyển đổi khi mở file DSD lần đầu; các lần sau phát ngay nhờ bộ nhớ đệm.
- Cải thiện thông báo khi không phát được file.

## v1.9.3+16
- **Khung thông báo media:** metadata đầy đủ (tên bài, nghệ sĩ + định dạng), màu nút điều khiển theo màu tên bài, nút tua trong notification khớp ±10s với app.
- **Nhận diện DAC:** màn DSP có thêm mục "Thiết bị ra âm thanh" — liệt kê thiết bị ra đang kết nối (USB DAC / 3.5mm / Bluetooth / loa trong), đánh dấu DAC màu hổ phách kèm sample rate tối đa; có nút làm mới.
- Android tự định tuyến âm thanh sang DAC khi cắm USB-C. File DSD vẫn cần giải mã phần mềm vì Android không truyền DSD thô qua USB.
- Tên bài quá dài trên khung thông báo do hệ thống tự cắt (thẻ media Android 13+ do OS vẽ, app không điều khiển được chế độ chạy chữ).

## v1.9.2+15
- **Sửa lỗi giao diện:** thanh thu gọn (mini player) bị giãn tràn toàn màn hình khi mở các mục phân loại (Tất cả bài hát, Nghệ sĩ, Album, Thể loại, Playlist, Nghe gần đây, Lâu chưa nghe).
- Nguyên nhân: `Column` bên trong thanh dùng `mainAxisSize` mặc định là `max` nên giãn hết chiều cao còn trống của `Scaffold.bottomNavigationBar`; đã đổi sang `min`.
- Thanh thu gọn giờ cao cố định (~58dp + vùng an toàn) và hiển thị giống nhau trên mọi màn hình.

## v1.9.1+14
- **Widget màn hình chính:** căn giữa tên bài, nghệ sĩ và cụm nút điều khiển trong ô vuông.
- **Sửa lỗi nút widget không phản hồi:** media button trước đó gửi tới sai package; nay dùng đúng `MediaButtonReceiver` của app với `KEYCODE_MEDIA_*` (giống nút trên khung thông báo).
- Mở app bằng activity PendingIntent (được phép khởi chạy từ launcher) thay vì `startActivity()` trong BroadcastReceiver.

## v1.9.0+13
- **Widget màn hình chính Android (2x2):** cover làm nền, gradient thích ứng theo độ sáng cover (sáng → nền trắng chữ đen, tối → nền đen chữ trắng), tên bài, thanh thời gian phát, nút bài trước / play-pause / bài tiếp.
- Bài không có cover hiển thị logo đĩa Megaudio.
- Nút điều khiển hoạt động qua media session (không cần mở app).

## v1.8.1+12
- Đổi tên hiển thị trong app: drawer thành **MEGAUDIO**.
- Đổi package Dart thành `megaudio`, class `MegaudioApp` / `MegaudioAudioHandler`.
- Đổi Android namespace + applicationId thành `com.noet123456.megaudio`.

## v1.8.0+11
- Đổi tên app thành **Megaudio** (Windows title, Android label, web manifest, MaterialApp title).
- Binary Windows đổi thành `megaudio.exe`; cập nhật script build.

## v1.7.1+10
- Bỏ tiêu đề trong AppBar (chỉ còn logo và các thao tác).

## v1.7.0+9
- **Bỏ hoàn toàn chế độ nghe online** (YouTube/Audius), gỡ dependency mạng và quyền INTERNET.
- Lịch sử nghe cũ có bài online được tự lọc bỏ khi nạp.

## v1.6.0+8
- Chế độ tìm kiếm AUTO (đã gỡ ở v1.7.0): gộp 2 nguồn, chấm điểm độ khớp, lọc cover/karaoke/remix.

## v1.5.0+7
- Nguồn online Audius (nhanh, hợp pháp) + YouTube dự phòng.
- Shuffle theo **thể loại** thay vì album.
- Thanh thu gọn xuất hiện ở mọi màn hình.
- Android: media session, khung thông báo media, lock screen, nút tai nghe/Bluetooth.

## v1.4.1+6
- Timeout request online, kiểm tra kết nối, debounce tìm kiếm.

## v1.4.0+5
- Chế độ Online lần đầu (stream), drawer menu, offline home dạng lưới phân loại.

## v1.3.0+4
- Thiết kế lại toàn bộ UI theo phong cách Walkman (nền đen, monochrome, accent hổ phách).

## v1.2.0+3
- Sửa lỗi Android không load được thư mục (quyền storage).
- Quét đệ quy thư mục con, cho phép thư mục trống, nút quét lại.
- Sửa vòng lặp vô hạn parser WAV và race condition khi load bài.

## v1.1.0+2
- Bản đầu tiên: thư viện theo thư mục, FLAC/WAV/DSF/MP3, cover art, seek ±10s, 3 chế độ phát, phổ âm.
