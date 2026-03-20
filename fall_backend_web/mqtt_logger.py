import paho.mqtt.client as mqtt
from paho.mqtt.enums import CallbackAPIVersion
import json, sqlite3, time
from datetime import datetime

MQTT_BROKER = "localhost"
MQTT_TOPIC  = "esp32/mpu6050/data"
DB_FILE     = "sensor_data.db"

# ── Dùng 1 connection duy nhất, giữ mở suốt — tránh mở/đóng 25 lần/giây
_conn: sqlite3.Connection = None

def get_conn() -> sqlite3.Connection:
    global _conn
    if _conn is None:
        _conn = sqlite3.connect(DB_FILE, check_same_thread=False)
        _conn.execute("PRAGMA journal_mode=WAL")     # Đọc/ghi đồng thời, Flutter không bị lock
        _conn.execute("PRAGMA synchronous=NORMAL")   # Giảm fsync, vẫn an toàn
        _conn.execute("PRAGMA cache_size=1000")
        _conn.execute("PRAGMA wal_autocheckpoint=100") # Tự gộp WAL sau 100 page
    return _conn

def init_db():
    conn = get_conn()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS sensor (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            accX      REAL, accY REAL, accZ REAL,
            amag      REAL,
            temp      REAL,
            angleX    REAL, angleY REAL,
            label     INTEGER
        )
    """)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_id ON sensor(id)")
    conn.commit()

def insert_row(data: dict):
    conn = get_conn()
    conn.execute("""
        INSERT INTO sensor (timestamp, accX, accY, accZ, amag, temp, angleX, angleY, label)
        VALUES (:timestamp, :accX, :accY, :accZ, :amag, :temp, :angleX, :angleY, :label)
    """, data)
    conn.commit()

def on_message(client, userdata, message):
    try:
        payload = json.loads(message.payload.decode("utf-8"))

        # Dùng amag từ ESP32 đã lọc qua EKF — không tính lại ở đây
        accX   = payload.get("accX",   0.0)
        accY   = payload.get("accY",   0.0)
        accZ   = payload.get("accZ",   0.0)
        amag   = payload.get("amag",   0.0)  # Lấy trực tiếp từ ESP32
        temp   = payload.get("temp",  25.0)
        angleX = payload.get("angleX", 0.0)
        angleY = payload.get("angleY", 0.0)

        label     = 1 if amag > 2.0 else 0
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]

        insert_row(dict(
            timestamp=timestamp,
            accX=accX, accY=accY, accZ=accZ,
            amag=round(amag, 3),
            temp=temp,
            angleX=angleX, angleY=angleY,
            label=label
        ))
        print(f"[{timestamp}] Amag: {amag:.3f}g | Label: {label}")

    except Exception as e:
        print(f"Lỗi xử lý: {e}")

def on_disconnect(client, userdata, rc):
    print(f"Mất kết nối (rc={rc}), đang reconnect...")
    while True:
        try:
            client.reconnect()
            print("Reconnect thành công!")
            break
        except Exception as e:
            print(f"Reconnect thất bại: {e}")
            time.sleep(3)

init_db()

client = mqtt.Client(CallbackAPIVersion.VERSION1)
client.on_message    = on_message
client.on_disconnect = on_disconnect
client.connect(MQTT_BROKER, 1883, keepalive=60)
client.subscribe(MQTT_TOPIC)

try:
    print("--- Đang nhận dữ liệu (SQLite WAL mode)... ---")
    client.loop_forever()
except KeyboardInterrupt:
    print("Đang dừng...")
    if _conn:
        _conn.close()