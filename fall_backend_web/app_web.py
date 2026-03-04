import streamlit as st
import pandas as pd
import time
import os
import numpy as np

st.set_page_config(page_title="Hệ thống Cảnh báo Té ngã", layout="wide")

# 1. XÁC ĐỊNH ĐƯỜNG DẪN FILE (Dùng đường dẫn tuyệt đối cho chắc chắn)
current_dir = os.path.dirname(os.path.abspath(__file__))
FILE_PATH = os.path.join(current_dir, "mpu6050_simulated_data.csv")

st.title("📊 Giám sát MPU6050 Thời gian thực")

# Khởi tạo các vùng hiển thị
placeholder = st.empty()

while True:
    if os.path.exists(FILE_PATH):
        try:
            # Đọc file với mode 'r' để tránh xung đột quyền ghi
            with open(FILE_PATH, 'r') as f:
                df = pd.read_csv(f)
            
            if not df.empty:
                # Tính toán Amag
                df['amag'] = np.sqrt(df['accX']**2 + df['accY']**2 + df['accZ']**2)
                latest = df.iloc[-1]
                
                with placeholder.container():
                    # Chia cột hiển thị Metrics
                    m1, m2, m3, m4 = st.columns(4)
                    m1.metric("Nhiệt độ", f"{latest['temp']} °C")
                    m2.metric("Gia tốc Amag", f"{latest['amag']:.3f} g")
                    m3.metric("Góc X", f"{latest['angleX']}°")
                    
                    # Cảnh báo Té ngã dựa trên cột 'label'
                    status = "⚠️ PHÁT HIỆN TÉ NGÃ" if latest['label'] == 1 else "✅ Bình thường"
                    color = "red" if latest['label'] == 1 else "green"
                    m4.markdown(f"**Trạng thái:** <span style='color:{color}'>{status}</span>", unsafe_allow_html=True)
                    
                    # Biểu đồ
                    st.subheader("Biểu đồ Gia tốc & Góc nghiêng")
                    st.line_chart(df[['amag', 'angleX', 'angleY']].tail(50))
                    
                    # Bảng dữ liệu
                    st.subheader("Dữ liệu mới nhất")
                    st.write(df.tail(10))
            else:
                st.warning("File CSV đang trống...")
                
        except Exception as e:
            st.error(f"Lỗi đọc file: {e}")
    else:
        st.error(f"❌ KHÔNG TÌM THẤY FILE! Hãy đảm bảo file '{os.path.basename(FILE_PATH)}' nằm cùng thư mục với file python này.")
    
    time.sleep(1) # Cập nhật mỗi giây