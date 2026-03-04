import streamlit as st
import pandas as pd
import time

st.set_page_config(page_title="Hệ thống quản trị Té ngã", layout="wide")

st.title("📊 Dashboard Phân tích Dữ liệu cảm biến")

# Nơi hiển thị biểu đồ
chart_placeholder = st.empty()

# Nơi hiển thị bảng dữ liệu
table_placeholder = st.empty()

while True:
    try:
        # Đọc dữ liệu từ file CSV mà logger đang ghi
        df = pd.read_csv("sensor_data.csv")
        
        # Chỉ lấy 50 dòng cuối cùng để biểu đồ không bị quá dày
        df_recent = df.tail(50)

        with chart_placeholder.container():
            st.subheader("Biểu đồ Gia tốc tổng hợp (Amag) theo thời gian")
            st.line_chart(df_recent.set_index("timestamp")["amag"])

        with table_placeholder.container():
            st.subheader("Dữ liệu chi tiết gần đây")
            st.dataframe(df_recent, use_container_width=True)

    except Exception as e:
        st.warning("Đang đợi dữ liệu mới từ file CSV...")
    
    # Tốc độ làm mới giao diện Web (nên để 1-2 giây)
    time.sleep(1)