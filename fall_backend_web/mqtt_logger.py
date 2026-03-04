import paho.mqtt.client as mqtt
import csv
import json
from datetime import datetime

# Cấu hình
MQTT_BROKER = "localhost" 
MQTT_TOPIC = "esp32/mpu6050/data"
CSV_FILE = "sensor_data.csv"

# Khởi tạo file CSV và viết tiêu đề (Header)
with open(CSV_FILE, mode='w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(["timestamp", "accX", "accY", "accZ", "amag"])

def on_message(client, userdata, message):
    try:
        # Giải mã dữ liệu JSON từ ESP32
        payload = json.loads(message.payload.decode("utf-8"))
        
        accX = payload.get("accX", 0)
        accY = payload.get("accY", 0)
        accZ = payload.get("accZ", 0)
        # Tính toán Amag
        amag = (accX**2 + accY**2 + accZ**2)**0.5
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]

        # Ghi vào file CSV
        with open(CSV_FILE, mode='a', newline='') as f:
            writer = csv.writer(f)
            writer.writerow([timestamp, accX, accY, accZ, round(amag, 2)])
        
        print(f"Đã lưu: {timestamp} - Amag: {round(amag, 2)}")
    except Exception as e:
        print(f"Lỗi xử lý dữ liệu: {e}")

# Kết nối MQTT
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1)
client.on_message = on_message
client.connect(MQTT_BROKER, 1883)
client.subscribe(MQTT_TOPIC)

print("Đang chờ dữ liệu từ ESP32 và ghi vào CSV...")
client.loop_forever()