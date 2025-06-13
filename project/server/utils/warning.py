import requests

def send_bark_notification(msg: str):
    device_key = "xxxxxxx"
    url = f"https://api.day.app/{device_key}/预警/{str}"
    
    try:
        response = requests.get(url, verify=False)  # 禁用SSL验证
        print("通知发送成功" if response.status_code == 200 else "发送失败")
    except Exception as e:
        print(f"请求出错: {e}")
