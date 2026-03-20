import streamlit as st
import pandas as pd
import sqlite3, os, time

st.set_page_config(page_title="Hệ thống Cảnh báo Té ngã", layout="wide")

DB_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sensor_data.db")

st.title("📊 Giám sát MPU6050 Thời gian thực")

def load_data(limit=500) -> pd.DataFrame:
    """Đọc N dòng cuối từ SQLite — toàn bộ data vẫn được lưu đầy đủ."""
    conn = sqlite3.connect(DB_FILE)
    df = pd.read_sql_query(
        f"SELECT * FROM sensor ORDER BY id DESC LIMIT {limit}",
        conn
    )
    conn.close()
    return df.iloc[::-1].reset_index(drop=True)  # Đảo lại đúng thứ tự thời gian

def load_fall_events() -> pd.DataFrame:
    """Lấy toàn bộ sự kiện té ngã trong lịch sử."""
    conn = sqlite3.connect(DB_FILE)
    df = pd.read_sql_query(
        "SELECT * FROM sensor WHERE label = 1 ORDER BY id DESC LIMIT 100",
        conn
    )
    conn.close()
    return df

if not os.path.exists(DB_FILE):
    st.warning("Chưa có database. Hãy chạy mqtt_client.py trước.")
else:
    try:
        df = load_data(limit=500)

        if df.empty:
            st.info("Chưa có dữ liệu trong database.")
        else:
            latest = df.iloc[-1]

            # --- Metrics ---
            m1, m2, m3, m4 = st.columns(4)
            m1.metric("Nhiệt độ",    f"{latest['temp']} °C")
            m2.metric("Gia tốc Amag", f"{latest['amag']:.3f} g")
            m3.metric("Góc X",       f"{latest['angleX']}°")

            is_fall = latest['label'] == 1
            status  = "⚠️ PHÁT HIỆN TÉ NGÃ" if is_fall else "✅ Bình thường"
            color   = "red" if is_fall else "green"
            m4.markdown(
                f"**Trạng thái:** <span style='color:{color}; font-size:1.1em'>{status}</span>",
                unsafe_allow_html=True
            )

            # --- Biểu đồ realtime ---
            st.subheader("Biểu đồ Gia tốc & Góc nghiêng (500 điểm gần nhất)")
            st.line_chart(df[['amag', 'angleX', 'angleY']])

            # --- Lịch sử té ngã (từ TOÀN BỘ database) ---
            st.subheader("🚨 Lịch sử té ngã (100 sự kiện gần nhất)")
            falls = load_fall_events()
            if falls.empty:
                st.success("Chưa có sự kiện té ngã nào được ghi nhận.")
            else:
                st.dataframe(falls, use_container_width=True)

            # --- Thống kê ---
            conn = sqlite3.connect(DB_FILE)
            total, total_falls = conn.execute(
                "SELECT COUNT(*), SUM(label) FROM sensor"
            ).fetchone()
            conn.close()
            st.caption(f"📦 Tổng bản ghi trong DB: **{total:,}** | Tổng té ngã: **{int(total_falls or 0):,}**")

            # --- Bảng 10 dòng mới nhất ---
            st.subheader("Dữ liệu mới nhất")
            st.dataframe(df.tail(10), use_container_width=True)

    except Exception as e:
        st.error(f"Lỗi đọc database: {e}")

time.sleep(1)
st.rerun()