from collections import deque
from dataclasses import dataclass

from typing import List, Deque
import asyncio
import aiohttp
@dataclass
class ChatMessage:
    text: str
    is_user: bool

# 初始化消息缓存（固定容量）
_message_buffer: Deque[ChatMessage] = deque(maxlen=10)

# 添加消息
def add_message(text: str, is_user: bool):
    _message_buffer.append(ChatMessage(text, is_user))

def get_messages() -> List[ChatMessage]:
    return list(_message_buffer)

def build_conversation_context() -> str:
    system_prompt = """
你是一个专业的场景识别AI助手。请根据用户输入的语音识别内容，从以下3个预定义场景中选择最匹配的场景，并返回结构化信息。

预定义场景列表：
1. 校园暴力 - 涉及学校环境中的欺凌、威胁、身体伤害、恐吓、强迫等暴力行为或相关求助信号
2. 医嘱信息 - 医生在医院环境中给出的治疗建议、用药指导、注意事项、复诊安排等医疗相关指示
3. 日常交流 - 普通对话、闲聊、一般性咨询、学习工作等非紧急情况

场景识别关键词参考：
- 校园暴力：打、踢、威胁、欺负、不敢说、害怕、同学、老师、学校、霸凌、恐吓、强迫、伤害
- 医嘱信息：医生说、要吃药、按时服用、注意、禁止、复查、检查、治疗、剂量、副作用、医院
- 日常交流：其他所有不涉及上述两种紧急情况的内容

请严格按照以下JSON格式返回结果：
{
    "场景": "[校园暴力/医嘱信息/日常交流]",
    "信息": "[核心内容摘要，不超过40字]",
    "紧急程度": "[低/中/高]",
    "建议行动": "[针对性的具体建议]"
}

特殊处理规则：
- 校园暴力：紧急程度标记为"高"，建议行动包含"立即寻求帮助"、"告知可信任的成年人"等
- 医嘱信息：按医嘱重要性标记紧急程度，提取关键用药信息、注意事项，建议行动包含"严格遵医嘱"等
- 日常交流：紧急程度标记为"低"，给出常规性建议或回应

注意：
- 必须严格按照JSON格式返回，不要有多余文字
- 优先保障人身安全，校园暴力场景务必触发预警
- 医嘱信息要准确提取重要医疗指导内容
- 信息字段要简洁准确，突出核心要点

用户输入的语音识别内容：
"""
    messages = get_messages()
    # 保留最近三条消息
    recent_messages = messages[-3:]

    # 构造对话历史
    context_lines = []
    for msg in recent_messages:
        role = "用户" if msg.is_user else "助手"
        text = msg.text
        context_lines.append(f"{role}: {text}")

    context = "\n".join(context_lines)

    return f"{system_prompt}\n\n对话历史：\n{context}\n\n请分析最新的用户输入并返回JSON格式的场景识别结果："


# 假设这是一个绑定 UI 的可变状态
msg = "正在等待..."

async def generate_blocking_response(user_input: str):
    global msg

    if not user_input.strip():
        return

    # 添加用户输入到消息记录
    add_message(user_input, is_user=True)

    # 构建完整 prompt（带系统提示）
    full_prompt = build_conversation_context() + user_input

    # 调用 AI 回复接口
    response = await generate_response_async(full_prompt)

    if response:
        # 添加助手回复
        add_message(response, is_user=False)

        # 更新 UI 消息
        msg = response

        # 检查是否需要应急响应
        # await parse_response_and_handle_emergency(response)
    else:
        msg = "抱歉，无法生成回复，请稍后重试。"


current_mode = "api"  # 或 "api"

async def generate_response_async(prompt: str) -> str | None:
    if current_mode == "local":
        return None
        # return await generate_local_response_async(prompt)
    elif current_mode == "api":
        return await generate_api_response_async(prompt)
    else:
        print(f"未知模式: {current_mode}")
        return None

is_generating = False  # 模拟 Swift 的 @Published var

async def generate_api_response_async(prompt: str) -> str | None:
    global is_generating

    # 更新“主线程状态”
    is_generating = True

    response = await call_gemini_api(prompt)

    is_generating = False

    return response

GEMINI_API_KEY = "XXXXXXXX"
GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
#PROXY_GEMINI_API_URL = "http://proxy/gemini"

async def call_gemini_api(prompt: str) -> str | None:
    print("start")
    url = f"{GEMINI_API_URL}?key={GEMINI_API_KEY}"
    
    headers = {
        "Content-Type": "application/json"
    }

    request_body = {
        "contents": [
            {
                "parts": [
                    {"text": prompt}
                ]
            }
        ]
    }

    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(url, json=request_body, headers=headers) as response:
                print(f"API Response Status: {response.status}")

                if response.status != 200:
                    print("Non-200 response")
                    return None

                json_response = await response.json()

                candidates = json_response.get("candidates", [])
                if not candidates:
                    print("No candidates in response")
                    return None

                content = candidates[0].get("content", {})
                parts = content.get("parts", [])
                if not parts:
                    print("No parts in content")
                    return None

                return parts[0].get("text")

    except Exception as e:
        print(f"API call error: {e}")
        return None